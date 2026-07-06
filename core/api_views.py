from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
import hashlib
import hmac
import re
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import update_last_login
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.core.cache import cache
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt

from .backoffice_services import CAFE_OWNER_GROUP_NAME
from .email_delivery import EmailDeliveryError, send_login_code, send_signup_code
from .models import Cafe
from .selectors import (
    get_active_cafes,
    get_products_for_cafe,
    get_user_orders as get_user_orders_selector,
)
from .services import (
    NotFoundServiceError,
    ValidationServiceError,
    cancel_user_order as cancel_user_order_service,
    create_order as create_order_service,
)
from .serializers import (
    CafeSerializer,
    NotificationSerializer,
    OrderSerializer,
    ProductSerializer,
    UserSerializer,
)
from users.models import EmailLoginCode, EmailSignupCode, User
from wallet.models import Wallet
from .utils import normalize_libyan_phone

# --- Caching Setup ---
PRODUCTS_CACHE_KEY = "products:list:v3"
# ??? ??????? PRODUCTS_TTL ??? ????? ??? ???? ???? ???? ????? ????.
PRODUCTS_TTL = 1800  # 30 دقيقة


def _parse_positive_int_query(value, *, field_name: str):
    normalized = str(value or "").strip()
    if not normalized:
        return None
    if not re.fullmatch(r"\d{1,12}", normalized):
        raise ValidationServiceError(f"Invalid {field_name}.")
    parsed = int(normalized)
    if parsed <= 0:
        raise ValidationServiceError(f"Invalid {field_name}.")
    return parsed


# ???? ???? _products_cache_key_for_cafe ?????? ????? ?????? ?? ????? ????.
def _products_cache_key_for_cafe(cafe_id) -> str:
    return f"{PRODUCTS_CACHE_KEY}:cafe:{cafe_id}"


# ???? ???? get_products_cached ?????? ????? ?????? ?? ????? ????.
def get_products_cached(cafe_id):
    # ??? ??????? cache_key ??? ????? ??? ???? ???? ???? ????? ????.
    cache_key = _products_cache_key_for_cafe(cafe_id)
    # ??? ??????? cached ??? ????? ??? ???? ???? ???? ????? ????.
    cached = cache.get(cache_key)
    if cached:
        return cached
    # ??? ??????? products ??? ????? ??? ???? ???? ???? ????? ????.
    products = list(get_products_for_cafe(cafe_id))
    cache.set(cache_key, products, PRODUCTS_TTL)
    return products


# ???? ???? invalidate_products_cache ?????? ????? ?????? ?? ????? ????.
def invalidate_products_cache():
    cache.clear()


# ???? ???? _build_auth_payload ?????? ????? ?????? ?? ????? ????.
def _build_cafe_access_payload(user):
    # ??? ??????? managed_cafe ??? ????? ??? ???? ???? ???? ????? ????.
    managed_cafe = getattr(user, 'my_cafe', None)
    # ??? ??????? belongs_to_cafe_group ??? ????? ??? ???? ???? ???? ????? ????.
    belongs_to_cafe_group = user.groups.filter(name=CAFE_OWNER_GROUP_NAME).exists()
    # ??? ??????? is_cafe_owner ??? ????? ??? ???? ???? ???? ????? ????.
    is_cafe_owner = managed_cafe is not None or belongs_to_cafe_group
    # ??? ??????? has_mini_system_dashboard ??? ????? ??? ???? ???? ???? ????? ????.
    has_mini_system_dashboard = managed_cafe is not None

    return {
        'is_cafe_owner': is_cafe_owner,
        'has_mini_system_dashboard': has_mini_system_dashboard,
        'managed_cafe': {
            'id': managed_cafe.id,
            'name': managed_cafe.name,
            'code': managed_cafe.code,
            'is_active': managed_cafe.is_active,
            'is_accepting_orders': managed_cafe.is_accepting_orders,
        } if managed_cafe is not None else None,
        'roles': {
            'is_cafe_owner': is_cafe_owner,
            'has_mini_system_dashboard': has_mini_system_dashboard,
            'is_staff': user.is_staff,
            'is_superuser': user.is_superuser,
        },
    }


# ???? ???? _build_auth_payload ?????? ????? ?????? ?? ????? ????.
def _build_auth_payload(user):
    # ??? ??????? refresh ??? ????? ??? ???? ???? ???? ????? ????.
    refresh = RefreshToken.for_user(user)
    # ??? ??????? access ??? ????? ??? ???? ???? ???? ????? ????.
    access = refresh.access_token
    # ??? ??????? cafe_access ??? ????? ??? ???? ???? ???? ????? ????.
    cafe_access = _build_cafe_access_payload(user)
    return {
        'token': str(access),
        'access': str(access),
        'refresh': str(refresh),
        'user': {
            'id': user.id,
            'phone_number': user.phone_number,
            'full_name': user.full_name,
            'email': user.email,
            'wallet_balance': user.wallet.balance if hasattr(user, 'wallet') else 0,
            **cafe_access,
        },
    }


def _hash_email_login_code(request_id, code: str) -> str:
    message = f"{request_id}:{code}".encode("utf-8")
    return hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()


def _mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    visible = local[:1] if len(local) <= 2 else local[:2]
    return f"{visible}{'*' * max(2, len(local) - len(visible))}@{domain}"


def _build_email_code_payload(
    *,
    challenge,
    email: str,
    resend_after: int,
    message: str = "Verification code sent.",
):
    expires_in = max(
        1,
        int((challenge.expires_at - timezone.now()).total_seconds()),
    )
    return {
        "request_id": str(challenge.request_id),
        "masked_email": _mask_email(email),
        "expires_in": expires_in,
        "resend_after": resend_after,
        "message": message,
    }


@csrf_exempt
@api_view(["POST"])
@permission_classes([AllowAny])
def request_email_login_code(request):
    email = (request.data.get("email") or "").strip().lower()
    try:
        validate_email(email)
    except ValidationError:
        return Response({"error": "Enter a valid email address."}, status=400)

    user = User.objects.filter(email__iexact=email).first()
    if user is None:
        return Response({"error": "Account was not found."}, status=404)
    if not user.is_active:
        return Response({"error": "This account is disabled."}, status=403)

    now = timezone.now()
    resend_after = settings.EMAIL_LOGIN_RESEND_SECONDS
    latest = EmailLoginCode.objects.filter(user=user).order_by("-created_at").first()
    if latest is not None:
        elapsed = (now - latest.created_at).total_seconds()
        if elapsed < resend_after:
            resend_remaining = max(1, int(resend_after - elapsed))
            if latest.consumed_at is None and latest.expires_at > now:
                return Response(
                    _build_email_code_payload(
                        challenge=latest,
                        email=user.email,
                        resend_after=resend_remaining,
                        message="Verification code already sent.",
                    )
                )
            return Response(
                {
                    "error": "Please wait before requesting another code.",
                    "retry_after": resend_remaining,
                },
                status=429,
            )

    requests_last_hour = EmailLoginCode.objects.filter(
        user=user,
        created_at__gte=now - timedelta(hours=1),
    ).count()
    if requests_last_hour >= settings.EMAIL_LOGIN_MAX_REQUESTS_PER_HOUR:
        return Response(
            {"error": "Too many login codes requested. Try again later."},
            status=429,
        )

    EmailLoginCode.objects.filter(
        user=user,
        consumed_at__isnull=True,
    ).update(consumed_at=now)

    code = f"{secrets.randbelow(1_000_000):06d}"
    challenge = EmailLoginCode.objects.create(
        user=user,
        code_hash="",
        expires_at=now + timedelta(minutes=settings.EMAIL_LOGIN_CODE_TTL_MINUTES),
    )
    challenge.code_hash = _hash_email_login_code(challenge.request_id, code)
    challenge.save(update_fields=["code_hash"])

    try:
        delivery = send_login_code(
            recipient_email=user.email,
            recipient_name=user.full_name,
            code=code,
        )
    except EmailDeliveryError:
        challenge.delete()
        return Response(
            {"error": "Verification email could not be sent. Try again later."},
            status=503,
        )

    payload = _build_email_code_payload(
        challenge=challenge,
        email=user.email,
        resend_after=resend_after,
    )
    if delivery.debug_mode:
        payload["debug_code"] = code
    return Response(payload)


@csrf_exempt
@api_view(["POST"])
@permission_classes([AllowAny])
def verify_email_login_code(request):
    email = (request.data.get("email") or "").strip().lower()
    request_id = (request.data.get("request_id") or "").strip()
    code = (request.data.get("code") or "").strip()
    if not email or not request_id or not re.fullmatch(r"\d{6}", code):
        return Response(
            {"error": "Email and a valid 6-digit code are required."},
            status=400,
        )

    user = User.objects.filter(email__iexact=email, is_active=True).first()
    if user is None:
        return Response({"error": "Invalid or expired verification code."}, status=400)

    with transaction.atomic():
        challenge = (
            EmailLoginCode.objects.select_for_update()
            .filter(request_id=request_id, user=user)
            .first()
        )
        if challenge is None or challenge.consumed_at is not None:
            return Response({"error": "Invalid or expired verification code."}, status=400)

        now = timezone.now()
        if challenge.expires_at <= now:
            challenge.consumed_at = now
            challenge.save(update_fields=["consumed_at"])
            return Response({"error": "Verification code has expired."}, status=400)

        if challenge.attempts >= settings.EMAIL_LOGIN_MAX_ATTEMPTS:
            challenge.consumed_at = now
            challenge.save(update_fields=["consumed_at"])
            return Response(
                {"error": "Too many invalid attempts. Request a new code."},
                status=429,
            )

        expected_hash = _hash_email_login_code(challenge.request_id, code)
        if not hmac.compare_digest(challenge.code_hash, expected_hash):
            challenge.attempts += 1
            update_fields = ["attempts"]
            if challenge.attempts >= settings.EMAIL_LOGIN_MAX_ATTEMPTS:
                challenge.consumed_at = now
                update_fields.append("consumed_at")
            challenge.save(update_fields=update_fields)
            return Response(
                {
                    "error": "Invalid verification code.",
                    "attempts_remaining": max(
                        0,
                        settings.EMAIL_LOGIN_MAX_ATTEMPTS - challenge.attempts,
                    ),
                },
                status=400,
            )

        challenge.consumed_at = now
        challenge.save(update_fields=["consumed_at"])
        EmailLoginCode.objects.filter(
            user=user,
            consumed_at__isnull=True,
        ).exclude(pk=challenge.pk).update(consumed_at=now)
        update_last_login(None, user)

    return Response(_build_auth_payload(user))


# ???? ???? api_login ?????? ????? ?????? ?? ????? ????.
@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def api_login(request):
    # ??? ??????? raw_identifier ??? ????? ??? ???? ???? ???? ????? ????.
    raw_identifier = (
        request.data.get('identifier')
        or request.data.get('email')
        or request.data.get('phone_number')
    )
    # ??? ??????? password ??? ????? ??? ???? ???? ???? ????? ????.
    password = request.data.get('password')
    if not raw_identifier or not password:
        return Response({'error': 'Phone/email and password are required.'}, status=400)

    # ??? ??????? phone ??? ????? ??? ???? ???? ???? ????? ????.
    phone = normalize_libyan_phone(raw_identifier)
    # ??? ??????? user_obj ??? ????? ??? ???? ???? ???? ????? ????.
    user_obj = None
    if phone:
        # ??? ??????? user_obj ??? ????? ??? ???? ???? ???? ????? ????.
        user_obj = User.objects.filter(Q(phone_number=phone) | Q(secondary_phone_number=phone)).first()

    if not user_obj and '@' in str(raw_identifier):
        # ??? ??????? user_obj ??? ????? ??? ???? ???? ???? ????? ????.
        user_obj = User.objects.filter(email__iexact=str(raw_identifier).strip()).first()

    if not user_obj:
        return Response({'error': 'Account was not found.'}, status=400)

    if not user_obj.is_active:
        return Response({'error': 'This account is disabled.'}, status=403)

    # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
    user = authenticate(request, username=user_obj.email, password=password)
    if user:
        return Response(_build_auth_payload(user))

    return Response({'error': 'Invalid login credentials.'}, status=400)


# ???? ???? api_signup ?????? ????? ?????? ?? ????? ????.
@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def api_signup(request):
    raw_phone = request.data.get('phone_number')
    password = request.data.get('password') or ''
    full_name = (request.data.get('full_name') or request.data.get('name') or '').strip()
    email = (request.data.get('email') or '').strip().lower()

    phone_number = normalize_libyan_phone(raw_phone)
    if not phone_number or not re.fullmatch(r'09\d{8}', phone_number):
        return Response({'error': 'Invalid Libyan phone number. Use 09XXXXXXXX.'}, status=400)

    if len(password) < 6:
        return Response({'error': 'Password must be at least 6 characters.'}, status=400)

    if not full_name:
        return Response({'error': 'Student name is required.'}, status=400)

    if len(full_name) < 2:
        return Response({'error': 'Student name is too short.'}, status=400)

    if not email:
        return Response({'error': 'Email is required.'}, status=400)

    try:
        validate_email(email)
    except ValidationError:
        return Response({'error': 'Enter a valid email address.'}, status=400)

    if User.objects.filter(phone_number=phone_number).exists():
        return Response({'error': 'Phone number is already registered.'}, status=400)

    if User.objects.filter(email__iexact=email).exists():
        return Response({'error': 'Email is already registered.'}, status=400)

    now = timezone.now()
    resend_after = settings.EMAIL_LOGIN_RESEND_SECONDS
    latest = (
        EmailSignupCode.objects.filter(Q(email__iexact=email) | Q(phone_number=phone_number))
        .order_by("-created_at")
        .first()
    )
    if latest is not None:
        elapsed = (now - latest.created_at).total_seconds()
        if elapsed < resend_after:
            resend_remaining = max(1, int(resend_after - elapsed))
            same_pending_signup = (
                latest.consumed_at is None
                and latest.expires_at > now
                and latest.email.lower() == email
                and latest.phone_number == phone_number
            )
            if same_pending_signup:
                return Response(
                    _build_email_code_payload(
                        challenge=latest,
                        email=latest.email,
                        resend_after=resend_remaining,
                        message="Verification code already sent.",
                    ),
                    status=202,
                )
            return Response(
                {
                    "error": "Please wait before requesting another code.",
                    "retry_after": resend_remaining,
                },
                status=429,
            )

    requests_last_hour = EmailSignupCode.objects.filter(
        Q(email__iexact=email) | Q(phone_number=phone_number),
        created_at__gte=now - timedelta(hours=1),
    ).count()
    if requests_last_hour >= settings.EMAIL_LOGIN_MAX_REQUESTS_PER_HOUR:
        return Response(
            {"error": "Too many verification codes requested. Try again later."},
            status=429,
        )

    EmailSignupCode.objects.filter(
        Q(email__iexact=email) | Q(phone_number=phone_number),
        consumed_at__isnull=True,
    ).update(consumed_at=now)

    code = f"{secrets.randbelow(1_000_000):06d}"
    challenge = EmailSignupCode.objects.create(
        email=email,
        full_name=full_name,
        phone_number=phone_number,
        password_hash=make_password(password),
        code_hash="",
        expires_at=now + timedelta(minutes=settings.EMAIL_LOGIN_CODE_TTL_MINUTES),
    )
    challenge.code_hash = _hash_email_login_code(challenge.request_id, code)
    challenge.save(update_fields=["code_hash"])

    try:
        delivery = send_signup_code(
            recipient_email=email,
            recipient_name=full_name,
            code=code,
        )
    except EmailDeliveryError:
        challenge.delete()
        return Response(
            {"error": "Verification email could not be sent. Try again later."},
            status=503,
        )

    payload = _build_email_code_payload(
        challenge=challenge,
        email=email,
        resend_after=resend_after,
    )
    if delivery.debug_mode:
        payload["debug_code"] = code
    return Response(payload, status=202)


@csrf_exempt
@api_view(["POST"])
@permission_classes([AllowAny])
def verify_email_signup_code(request):
    email = (request.data.get("email") or "").strip().lower()
    request_id = (request.data.get("request_id") or "").strip()
    code = (request.data.get("code") or "").strip()
    if not email or not request_id or not re.fullmatch(r"\d{6}", code):
        return Response(
            {"error": "Email and a valid 6-digit code are required."},
            status=400,
        )

    with transaction.atomic():
        challenge = (
            EmailSignupCode.objects.select_for_update()
            .filter(request_id=request_id, email__iexact=email)
            .first()
        )
        if challenge is None or challenge.consumed_at is not None:
            return Response({"error": "Invalid or expired verification code."}, status=400)

        now = timezone.now()
        if challenge.expires_at <= now:
            challenge.consumed_at = now
            challenge.save(update_fields=["consumed_at"])
            return Response({"error": "Verification code has expired."}, status=400)

        if challenge.attempts >= settings.EMAIL_LOGIN_MAX_ATTEMPTS:
            challenge.consumed_at = now
            challenge.save(update_fields=["consumed_at"])
            return Response(
                {"error": "Too many invalid attempts. Request a new code."},
                status=429,
            )

        expected_hash = _hash_email_login_code(challenge.request_id, code)
        if not hmac.compare_digest(challenge.code_hash, expected_hash):
            challenge.attempts += 1
            update_fields = ["attempts"]
            if challenge.attempts >= settings.EMAIL_LOGIN_MAX_ATTEMPTS:
                challenge.consumed_at = now
                update_fields.append("consumed_at")
            challenge.save(update_fields=update_fields)
            return Response(
                {
                    "error": "Invalid verification code.",
                    "attempts_remaining": max(
                        0,
                        settings.EMAIL_LOGIN_MAX_ATTEMPTS - challenge.attempts,
                    ),
                },
                status=400,
            )

        if User.objects.filter(email__iexact=challenge.email).exists():
            return Response({"error": "Email is already registered."}, status=400)
        if User.objects.filter(phone_number=challenge.phone_number).exists():
            return Response({"error": "Phone number is already registered."}, status=400)

        user = User(
            email=challenge.email,
            full_name=challenge.full_name,
            phone_number=challenge.phone_number,
            password=challenge.password_hash,
        )
        try:
            with transaction.atomic():
                user.save(force_insert=True)
        except IntegrityError:
            return Response(
                {"error": "Phone number or email is already registered."},
                status=400,
            )

        if not hasattr(user, "wallet"):
            Wallet.objects.create(user=user)

        challenge.consumed_at = now
        challenge.save(update_fields=["consumed_at"])
        EmailSignupCode.objects.filter(
            Q(email__iexact=challenge.email) | Q(phone_number=challenge.phone_number),
            consumed_at__isnull=True,
        ).exclude(pk=challenge.pk).update(consumed_at=now)
        update_last_login(None, user)

    return Response(_build_auth_payload(user), status=201)


# ???? ???? get_cafes_list ?????? ????? ?????? ?? ????? ????.
@api_view(['GET'])
@permission_classes([AllowAny])
def get_cafes_list(request):
    include_inactive = (
        str(request.GET.get('include_inactive', '0')).lower() in ['1', 'true', 'yes']
        and request.user.is_authenticated
        and request.user.is_superuser
    )
    # ??? ??????? cafes ??? ????? ??? ???? ???? ???? ????? ????.
    cafes = Cafe.objects.all().order_by("name") if include_inactive else get_active_cafes()
    # ??? ??????? serializer ??? ????? ??? ???? ???? ???? ????? ????.
    serializer = CafeSerializer(cafes, many=True, context={'request': request})
    return Response(serializer.data)


# ???? ???? get_products ?????? ????? ?????? ?? ????? ????.
@api_view(['GET'])
@permission_classes([AllowAny])
def get_products(request):
    # ??? ??????? cafe_id ??? ????? ??? ???? ???? ???? ????? ????.
    try:
        cafe_id = _parse_positive_int_query(
            request.GET.get('cafe_id'),
            field_name="cafe_id",
        )
    except ValidationServiceError as exc:
        return Response({'error': str(exc)}, status=400)

    if cafe_id is None:
        # ??? ??????? default_cafe ??? ????? ??? ???? ???? ???? ????? ????.
        default_cafe = get_active_cafes().first()
        if default_cafe is None:
            return Response([])
        # ??? ??????? cafe_id ??? ????? ??? ???? ???? ???? ????? ????.
        cafe_id = default_cafe.id
    else:
        selected_cafe = Cafe.objects.filter(pk=cafe_id, is_active=True).only("id").first()
        if selected_cafe is None:
            return Response({"error": "Cafe was not found."}, status=404)

    # ??? ??????? products ??? ????? ??? ???? ???? ???? ????? ????.
    products = get_products_cached(cafe_id)

    # ??? ??????? category_id ??? ????? ??? ???? ???? ???? ????? ????.
    if request.GET.get('category') or request.GET.get('category_name'):
        return Response(
            {'error': 'Filtering by category name is disabled. Use category_id.'},
            status=400,
        )
    try:
        category_id = _parse_positive_int_query(
            request.GET.get('category_id'),
            field_name="category_id",
        )
    except ValidationServiceError as exc:
        return Response({'error': str(exc)}, status=400)
    # ??? ??????? available_only ??? ????? ??? ???? ???? ???? ????? ????.
    available_only = request.GET.get('available')

    if category_id:
        # ??? ??????? products ??? ????? ??? ???? ???? ???? ????? ????.
        products = [p for p in products if p.category_id == category_id]

    if available_only and str(available_only).lower() in ['1', 'true', 'yes']:
        # ??? ??????? products ??? ????? ??? ???? ???? ???? ????? ????.
        products = [p for p in products if p.is_in_stock]

    # ??? ??????? serializer ??? ????? ??? ???? ???? ???? ????? ????.
    serializer = ProductSerializer(products, many=True, context={'request': request})
    return Response(serializer.data)



# ???? ???? update_secondary_phone ?????? ????? ?????? ?? ????? ????.
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_secondary_phone(request):
    # ??? ??????? raw_phone ??? ????? ??? ???? ???? ???? ????? ????.
    raw_phone = (request.data.get('secondary_phone') or request.data.get('secondary_phone_number') or '').strip()

    if raw_phone == '':
        request.user.secondary_phone_number = None
        request.user.save(update_fields=['secondary_phone_number'])
        return Response({'secondary_phone': None})

    # ??? ??????? phone ??? ????? ??? ???? ???? ???? ????? ????.
    phone = normalize_libyan_phone(raw_phone)
    if not phone or not re.fullmatch(r'09\d{8}', phone):
        return Response({'error': '??? ?????? ??? ????.'}, status=400)

    # ??? ??????? exists ??? ????? ??? ???? ???? ???? ????? ????.
    exists = User.objects.filter(
        Q(phone_number=phone) | Q(secondary_phone_number=phone)
    ).exclude(id=request.user.id).exists()
    if exists:
        return Response({'error': '??? ?????? ?????? ?? ???.'}, status=400)

    request.user.secondary_phone_number = phone
    request.user.save(update_fields=['secondary_phone_number'])
    return Response({'secondary_phone': phone})


# ???? ???? get_user_profile ?????? ????? ?????? ?? ????? ????.
@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def get_user_profile(request):
    if request.method == 'GET':
        # ??? ??????? serializer ??? ????? ??? ???? ???? ???? ????? ????.
        serializer = UserSerializer(request.user, context={'request': request})
        return Response(serializer.data)

    # ??? ??????? full_name ??? ????? ??? ???? ???? ???? ????? ????.
    full_name = (request.data.get('full_name') or request.data.get('name') or '').strip()
    # ??? ??????? profile_image_url ??? ????? ??? ???? ???? ???? ????? ????.
    profile_image_url = (request.data.get('profile_image_url') or '').strip()
    # ??? ??????? uploaded_image ??? ????? ??? ???? ???? ???? ????? ????.
    uploaded_image = request.FILES.get('image') or request.FILES.get('profile_image')

    if not full_name:
        return Response({'error': 'الاسم مطلوب.'}, status=400)

    # ??? ??????? update_fields ??? ????? ??? ???? ???? ???? ????? ????.
    update_fields = []
    if full_name and request.user.full_name != full_name:
        request.user.full_name = full_name
        update_fields.append('full_name')

    if 'profile_image_url' in request.data:
        request.user.profile_image_url = profile_image_url or None
        update_fields.append('profile_image_url')

    if uploaded_image is not None:
        request.user.image = uploaded_image
        request.user.profile_image_url = request.build_absolute_uri(request.user.image.url)
        update_fields.extend(['image', 'profile_image_url'])

    if update_fields:
        request.user.save(update_fields=list(dict.fromkeys(update_fields)))

    # ??? ??????? serializer ??? ????? ??? ???? ???? ???? ????? ????.
    serializer = UserSerializer(request.user, context={'request': request})
    return Response(serializer.data)


# ???? ???? create_order ?????? ????? ?????? ?? ????? ????.
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_order(request):
    # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
    user = request.user
    # ??? ??????? total_price_raw ??? ????? ??? ???? ???? ???? ????? ????.
    total_price_raw = request.data.get('total_price')
    # ??? ??????? items_data ??? ????? ??? ???? ???? ???? ????? ????.
    items_data = request.data.get('items')
    # ??? ??????? cafe_id ??? ????? ??? ???? ???? ???? ????? ????.
    cafe_id = request.data.get('cafe_id')
    # ??? ??????? payment_method ??? ????? ??? ???? ???? ???? ????? ????.
    payment_method = request.data.get('payment_method', 'WALLET')
    nfc_card_uid = request.data.get('nfc_card_uid')
    order_note = request.data.get('order_note') or request.data.get('notes')

    try:
        # ??? ??????? order ??? ????? ??? ???? ???? ???? ????? ????.
        order = create_order_service(
            # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
            user=user,
            # ??? ??????? cafe_id ??? ????? ??? ???? ???? ???? ????? ????.
            cafe_id=cafe_id,
            # ??? ??????? items_data ??? ????? ??? ???? ???? ???? ????? ????.
            items_data=items_data,
            # ??? ??????? total_price ??? ????? ??? ???? ???? ???? ????? ????.
            total_price=total_price_raw,
            # ??? ??????? payment_method ??? ????? ??? ???? ???? ???? ????? ????.
            payment_method=payment_method,
            nfc_card_uid=nfc_card_uid,
            order_note=order_note,
        )
        invalidate_products_cache()
        # ??? ??????? serializer ??? ????? ??? ???? ???? ???? ????? ????.
        serializer = OrderSerializer(order, context={'request': request})
        return Response(
            {
                'message': 'تم إرسال الطلب بنجاح',
                'order_id': order.id,
                'order': serializer.data,
            },
            # ??? ??????? status ??? ????? ??? ???? ???? ???? ????? ????.
            status=201,
        )
    except ValidationServiceError as exc:
        return Response({'error': str(exc)}, status=400)
    except NotFoundServiceError as exc:
        return Response({'error': str(exc)}, status=404)
    except Exception as exc:
        print(f"Order Error: {exc}")
        return Response({'error': 'حدث خطأ أثناء إنشاء الطلب.'}, status=500)


# ???? ???? get_user_orders ?????? ????? ?????? ?? ????? ????.
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_orders(request):
    # ??? ??????? orders ??? ????? ??? ???? ???? ???? ????? ????.
    orders = get_user_orders_selector(request.user)
    # ??? ??????? serializer ??? ????? ??? ???? ???? ???? ????? ????.
    serializer = OrderSerializer(orders, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def notifications_endpoint(request):
    if request.method == 'POST':
        request.user.notifications.filter(is_read=False).update(is_read=True)
        return Response({'success': True})

    notifications = request.user.notifications.select_related('order', 'order__cafe')[:50]
    serializer = NotificationSerializer(notifications, many=True)
    return Response(
        {
            'unread_count': request.user.notifications.filter(is_read=False).count(),
            'notifications': serializer.data,
        }
    )


# ???? ???? cancel_order ?????? ????? ?????? ?? ????? ????.
@api_view(['PATCH', 'POST'])
@permission_classes([IsAuthenticated])
def cancel_order(request, order_id: int):
    try:
        # ??? ??????? order ??? ????? ??? ???? ???? ???? ????? ????.
        order = cancel_user_order_service(order_id=order_id, user=request.user)
    except ValidationServiceError as exc:
        return Response({'error': str(exc)}, status=400)
    except NotFoundServiceError as exc:
        return Response({'error': str(exc)}, status=404)

    # ??? ??????? serializer ??? ????? ??? ???? ???? ???? ????? ????.
    serializer = OrderSerializer(order, context={'request': request})
    return Response(
        {
            'message': 'تم إلغاء الطلب بنجاح',
            'order': serializer.data,
        },
        # ??? ??????? status ??? ????? ??? ???? ???? ???? ????? ????.
        status=200,
    )


# ???? ???? orders_endpoint ?????? ????? ?????? ?? ????? ????.
@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def orders_endpoint(request):
    """
    نقطة تجمع الطلبات لعرضها أو إنشائها.
    """
    if request.method == 'GET':
        # تمرير الطلب الأصلي لتجنب مشاكل الصلاحيات
        return get_user_orders(request._request)
    return create_order(request._request)

# Deprecated purchase endpoint intentionally omitted.
