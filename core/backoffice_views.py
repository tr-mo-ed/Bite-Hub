from __future__ import annotations

from decimal import Decimal, InvalidOperation
import json
import logging

from django.conf import settings
from django.contrib import messages
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required, user_passes_test
from django.db.models import Q, Sum
from django.http import HttpRequest, HttpResponse, JsonResponse
from django.shortcuts import redirect, render
from django.urls import reverse
from django.views.decorators.http import require_POST

from .backoffice_selectors import (
    get_all_cafes_for_admin,
    get_cafe_panel_snapshot,
    get_faculty_options,
    get_manager_options,
    get_recent_error_snapshots,
    get_super_admin_cafe_breakdown,
    get_super_admin_kpis,
    get_super_admin_sales_series,
    resolve_backoffice_cafe,
)
from .backoffice_services import provision_cafe, save_cafe_product, toggle_cafe_active_status, toggle_product_stock
from .models import Cafe, Category
from .serializers import OrderSerializer, ProductSerializer
from .services import NotFoundServiceError, ValidationServiceError, update_order_status
from .utils import normalize_libyan_phone
from users.models import User
from wallet.models import Transaction, Wallet

# ??? ??????? logger ??? ????? ??? ???? ???? ???? ????? ????.
logger = logging.getLogger(__name__)


def _passwordless_backoffice_enabled() -> bool:
    return bool(getattr(settings, "DEBUG", False))


def _get_or_create_dev_super_admin() -> User:
    user = User.objects.filter(is_superuser=True).order_by("id").first()
    if user:
        return user

    user = User.objects.create_superuser(
        email="super-admin@bitehub.local",
        password=None,
        full_name="Bite Hub Super Admin",
        phone_number="0990000001",
    )
    user.set_unusable_password()
    user.save(update_fields=["password"])
    return user


def _get_or_create_dev_cafe_user() -> User:
    cafe = (
        Cafe.objects.filter(is_active=True, owner__isnull=False)
        .select_related("owner")
        .order_by("name")
        .first()
    )
    if cafe and cafe.owner:
        user = cafe.owner
        if not user.is_staff:
            user.is_staff = True
            user.save(update_fields=["is_staff"])
        return user

    user, created = User.objects.get_or_create(
        email="demo-cafe@bitehub.local",
        defaults={
            "full_name": "Demo Cafe Manager",
            "phone_number": "0990000002",
            "is_staff": True,
        },
    )
    updates = []
    if created:
        user.set_unusable_password()
        updates.append("password")
    if not user.is_staff:
        user.is_staff = True
        updates.append("is_staff")
    if updates:
        user.save(update_fields=updates)

    cafe = Cafe.objects.filter(is_active=True).order_by("name").first()
    if cafe is None:
        cafe, _ = Cafe.objects.get_or_create(
            code="demo-cafe",
            defaults={
                "name": "Demo Cafe",
                "owner": user,
                "is_active": True,
            },
        )
        cafe_updates = []
        if cafe.owner_id != user.id:
            cafe.owner = user
            cafe_updates.append("owner")
        if not cafe.is_active:
            cafe.is_active = True
            cafe_updates.append("is_active")
        if cafe_updates:
            cafe.save(update_fields=cafe_updates)
    elif cafe.owner_id is None:
        cafe.owner = user
        cafe.save(update_fields=["owner"])

    return user


def _dev_passwordless_login(request: HttpRequest, role: str) -> HttpResponse | None:
    if not _passwordless_backoffice_enabled():
        return None

    if role == "super_admin":
        user = _get_or_create_dev_super_admin()
    elif role == "cafe":
        user = _get_or_create_dev_cafe_user()
    else:
        return None

    login(request, user, backend="django.contrib.auth.backends.ModelBackend")
    return redirect("core:route_after_login")


def _login_context(**extra) -> dict:
    context = {
        "passwordless_demo_enabled": _passwordless_backoffice_enabled(),
        "portal": "admin",
    }
    context.update(extra)
    return context


# ???? ???? _is_staff_or_superuser ?????? ????? ?????? ?? ????? ????.
def _is_staff_or_superuser(user) -> bool:
    return bool(user.is_authenticated and (user.is_staff or user.is_superuser or getattr(user, "my_cafe", None)))


def _is_cafe_operator(user) -> bool:
    return bool(user.is_authenticated and not user.is_superuser and (user.is_staff or getattr(user, "my_cafe", None)))


def _login_action_url(*, portal: str, cafe: Cafe | None = None) -> str:
    if portal == "cafe":
        if cafe is not None:
            return reverse("core:cafe_login_for_code", kwargs={"cafe_code": cafe.code})
        return reverse("core:cafe_login")
    return reverse("core:admin_login")


def _login_role_context(*, portal: str, cafe: Cafe | None = None) -> dict:
    if portal == "cafe":
        return {
            "portal": "cafe",
            "target_cafe": cafe,
            "login_action_url": _login_action_url(portal="cafe", cafe=cafe),
            "page_title": cafe.name if cafe else "دخول مركز عمليات المقهى",
            "page_subtitle": "بوابة تشغيل للمبيعات والطلبات والمحافظ وبطاقات NFC.",
            "username_label": "البريد الإلكتروني أو رقم مدير المقهى",
            "submit_label": "دخول مركز العمليات",
            "alternate_login_url": reverse("core:admin_login"),
            "alternate_login_label": "دخول السوبر أدمن",
        }
    return {
        "portal": "admin",
        "target_cafe": None,
        "login_action_url": reverse("core:admin_login"),
        "page_title": "دخول مركز الإدارة العليا",
        "page_subtitle": "بوابة مركزية لإدارة المقاهي والأداء وروابط التشغيل.",
        "username_label": "البريد الإلكتروني أو رقم الهاتف",
        "submit_label": "دخول مركز الإدارة",
        "alternate_login_url": reverse("core:cafe_login"),
        "alternate_login_label": "دخول مركز عمليات مقهى",
    }


def _authenticated_login_destination(user: User, *, portal: str, cafe: Cafe | None = None) -> str | None:
    if not user.is_authenticated:
        return None
    if portal == "admin":
        if user.is_superuser:
            return "core:super_admin_dashboard"
        return None

    if user.is_superuser:
        return None

    user_cafe = getattr(user, "my_cafe", None)
    if user_cafe is not None and (cafe is None or user_cafe.id == cafe.id):
        return "core:cafe_panel"
    return None


# ???? ???? custom_login ?????? ????? ?????? ?? ????? ????.
def custom_login(request: HttpRequest, portal: str = "admin", cafe_code: str | None = None) -> HttpResponse:
    portal = "cafe" if portal == "cafe" else "admin"
    target_cafe = None
    if cafe_code:
        target_cafe = Cafe.objects.filter(code=cafe_code, is_active=True).select_related("owner").first()
        if target_cafe is None:
            messages.error(request, "رابط المقهى غير صحيح أو غير مفعل.")
            return redirect("core:cafe_login")

    # ??? ??????? prefill_username ??? ????? ??? ???? ???? ???? ????? ????.
    prefill_username = request.GET.get("phone") or request.GET.get("username") or ""
    base_context = _login_role_context(portal=portal, cafe=target_cafe)

    if request.user.is_authenticated:
        destination = _authenticated_login_destination(request.user, portal=portal, cafe=target_cafe)
        if destination is not None:
            return redirect(destination)
        logout(request)

    if request.method == "POST":
        dev_role = request.POST.get("dev_role", "")
        if (portal == "admin" and dev_role == "super_admin") or (portal == "cafe" and dev_role == "cafe"):
            dev_login_response = _dev_passwordless_login(request, dev_role)
            if dev_login_response is not None:
                return dev_login_response

        # ??? ??????? username ??? ????? ??? ???? ???? ???? ????? ????.
        username = (request.POST.get("username") or "").replace("-", "").replace(" ", "")
        # ??? ??????? password ??? ????? ??? ???? ???? ???? ????? ????.
        password = request.POST.get("password")

        # ??? ??????? phone ??? ????? ??? ???? ???? ???? ????? ????.
        phone = normalize_libyan_phone(username)
        # ??? ??????? user_obj ??? ????? ??? ???? ???? ???? ????? ????.
        user_obj = User.objects.filter(Q(phone_number=phone) | Q(secondary_phone_number=phone)).first()
        if not user_obj:
            # ??? ??????? user_obj ??? ????? ??? ???? ???? ???? ????? ????.
            user_obj = User.objects.filter(email__iexact=username).first()

        # ??? ??????? email_for_auth ??? ????? ??? ???? ???? ???? ????? ????.
        email_for_auth = user_obj.email if user_obj else username
        # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
        user = authenticate(request, username=email_for_auth, password=password)
        if user:
            if portal == "admin" and not user.is_superuser:
                return render(
                    request,
                    "login.html",
                    _login_context(
                        **base_context,
                        error="هذا الرابط مخصص للسوبر أدمن فقط.",
                        prefill_username=username or prefill_username,
                    ),
                )

            user_cafe = getattr(user, "my_cafe", None)
            if portal == "cafe":
                if user.is_superuser or user_cafe is None:
                    return render(
                        request,
                        "login.html",
                        _login_context(
                            **base_context,
                            error="هذا الرابط مخصص لحسابات المقاهي فقط.",
                            prefill_username=username or prefill_username,
                        ),
                    )
                if target_cafe is not None and user_cafe.id != target_cafe.id:
                    return render(
                        request,
                        "login.html",
                        _login_context(
                            **base_context,
                            error="هذا الحساب غير مرتبط بهذا المقهى.",
                            prefill_username=username or prefill_username,
                        ),
                    )

            login(request, user)
            return redirect("core:route_after_login")

        return render(
            request,
            "login.html",
            _login_context(
                **base_context,
                error="بيانات الدخول غير صحيحة.",
                prefill_username=username or prefill_username,
            ),
        )

    return render(request, "login.html", _login_context(**base_context, prefill_username=prefill_username))


# ???? ???? custom_logout ?????? ????? ?????? ?? ????? ????.
def custom_logout(request: HttpRequest) -> HttpResponse:
    logout(request)
    # ??? ??????? next_url ??? ????? ??? ???? ???? ???? ????? ????.
    next_url = request.GET.get("next")
    if next_url and next_url.startswith("/"):
        return redirect(next_url)
    return redirect("core:login")


# ???? ???? switch_cafe ?????? ????? ?????? ?? ????? ????.
def switch_cafe(request: HttpRequest, cafe_id: int) -> HttpResponse:
    logout(request)
    # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
    cafe = Cafe.objects.filter(id=cafe_id, owner__isnull=False).select_related("owner").first()
    if cafe and cafe.owner:
        return redirect("core:cafe_login_for_code", cafe_code=cafe.code)
    return redirect("core:cafe_login")


# ???? ???? _resolve_web_home_for_user ?????? ????? ?????? ?? ????? ????.
def _resolve_web_home_for_user(user) -> str | None:
    if not user.is_authenticated:
        return "core:login"
    if user.is_superuser:
        return "core:super_admin_dashboard"
    if user.is_staff or getattr(user, "my_cafe", None):
        return "core:cafe_panel"
    return None


# ???? ???? route_after_login ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:login")
def route_after_login(request: HttpRequest) -> HttpResponse:
    # ??? ??????? destination ??? ????? ??? ???? ???? ???? ????? ????.
    destination = _resolve_web_home_for_user(request.user)
    if destination is None:
        messages.error(request, "هذا الحساب لا يملك لوحة V2 مفعلة حالياً.")
        logout(request)
        return redirect("core:login")
    return redirect(destination)


# ???? ???? manifest ?????? ????? ?????? ?? ????? ????.
def manifest(request: HttpRequest) -> JsonResponse:
    return JsonResponse({}, safe=False)


# ???? ???? _parse_optional_faculty_id ?????? ????? ?????? ?? ????? ????.
def _parse_optional_faculty_id(raw_value: str | None) -> int | None:
    # ??? ??????? value ??? ????? ??? ???? ???? ???? ????? ????.
    value = (raw_value or "").strip()
    if not value:
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ValidationServiceError("Selected faculty is invalid.") from exc


def _parse_positive_amount(raw_value: str | None) -> Decimal:
    try:
        amount = Decimal(str(raw_value or "").strip())
    except (InvalidOperation, ValueError) as exc:
        raise ValidationServiceError("قيمة المبلغ غير صحيحة.") from exc
    if amount <= 0:
        raise ValidationServiceError("المبلغ يجب أن يكون أكبر من صفر.")
    return amount


def _find_wallet_by_identifier(raw_identifier: str | None) -> Wallet | None:
    identifier = (raw_identifier or "").strip()
    if not identifier:
        return None

    phone = normalize_libyan_phone(identifier)
    user = User.objects.filter(
        Q(email__iexact=identifier)
        | Q(phone_number=phone)
        | Q(secondary_phone_number=phone)
    ).first()
    if user:
        wallet, _ = Wallet.objects.get_or_create(user=user)
        return wallet

    return Wallet.objects.select_related("user").filter(link_code__iexact=identifier).first()


def _wallet_payload(wallet: Wallet) -> dict:
    wallet.refresh_from_db()
    return {
        "user": wallet.user.full_name or wallet.user.email,
        "email": wallet.user.email,
        "phone": wallet.user.phone_number,
        "balance": str(wallet.balance),
        "link_code": wallet.link_code,
    }


# ???? ???? super_admin_dashboard ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
def super_admin_dashboard(request: HttpRequest) -> HttpResponse:
    # ??? ??????? sales_series ??? ????? ??? ???? ???? ???? ????? ????.
    sales_series = get_super_admin_sales_series()
    # ??? ??????? form_data ??? ????? ??? ???? ???? ???? ????? ????.
    form_data = request.session.pop(
        "super_admin_cafe_form_data",
        {
            "name": "",
            "code": "",
            "faculty_id": "",
            "owner_id": "",
        },
    )
    # ??? ??????? context ??? ????? ??? ???? ???? ???? ????? ????.
    context = {
        "kpis": get_super_admin_kpis(),
        "sales_series": sales_series,
        "cafe_breakdown": get_super_admin_cafe_breakdown(),
        "cafes": get_all_cafes_for_admin(),
        "faculties": get_faculty_options(),
        "managers": get_manager_options(),
        "error_snapshots": get_recent_error_snapshots(),
        "cafe_form_data": form_data,
    }
    return render(request, "admin_v2/super_admin_dashboard.html", context)


# ???? ???? create_cafe_from_dashboard ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@require_POST
def create_cafe_from_dashboard(request: HttpRequest) -> HttpResponse:
    # ??? ??????? form_data ??? ????? ??? ???? ???? ???? ????? ????.
    form_data = {
        "name": request.POST.get("name", "").strip(),
        "code": request.POST.get("code", "").strip(),
        "faculty_id": (request.POST.get("faculty_id") or "").strip(),
        "owner_id": (request.POST.get("owner_id") or "").strip(),
    }
    try:
        # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
        cafe = provision_cafe(
            # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
            name=form_data["name"],
            # ??? ??????? code ??? ????? ??? ???? ???? ???? ????? ????.
            code=form_data["code"],
            # ??? ??????? faculty_id ??? ????? ??? ???? ???? ???? ????? ????.
            faculty_id=_parse_optional_faculty_id(form_data["faculty_id"]),
            owner_id=_parse_optional_faculty_id(form_data["owner_id"]),
        )
        messages.success(request, f"Created cafe '{cafe.name}' successfully.")
        request.session.pop("super_admin_cafe_form_data", None)
    except ValidationServiceError as exc:
        messages.error(request, str(exc))
        request.session["super_admin_cafe_form_data"] = form_data
    except Exception:
        logger.exception("Unexpected failure while creating cafe from super admin dashboard.")
        messages.error(request, "Unexpected error while creating the cafe. Check server logs.")
        request.session["super_admin_cafe_form_data"] = form_data
    return redirect("core:super_admin_dashboard")


# ???? ???? toggle_cafe_status_from_dashboard ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@require_POST
def toggle_cafe_status_from_dashboard(request: HttpRequest, cafe_id: int) -> HttpResponse:
    try:
        # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
        cafe = toggle_cafe_active_status(cafe_id=cafe_id)
        # ??? ??????? state_label ??? ????? ??? ???? ???? ???? ????? ????.
        state_label = "activated" if cafe.is_active else "paused"
        messages.success(request, f"Cafe '{cafe.name}' was {state_label}.")
    except ValidationServiceError as exc:
        messages.error(request, str(exc))
    return redirect("core:super_admin_dashboard")


# ???? ???? create_cafe_api ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@require_POST
def create_cafe_api(request: HttpRequest) -> JsonResponse:
    # ??? ??????? faculty_value ??? ????? ??? ???? ???? ???? ????? ????.
    faculty_value = request.POST.get("faculty_id") or request.POST.get("faculty") or None
    owner_value = request.POST.get("owner_id") or request.POST.get("owner") or None
    try:
        # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
        cafe = provision_cafe(
            # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
            name=request.POST.get("name", ""),
            # ??? ??????? code ??? ????? ??? ???? ???? ???? ????? ????.
            code=request.POST.get("code", ""),
            # ??? ??????? faculty_id ??? ????? ??? ???? ???? ???? ????? ????.
            faculty_id=_parse_optional_faculty_id(faculty_value),
            owner_id=_parse_optional_faculty_id(owner_value),
        )
    except ValidationServiceError as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)
    except Exception:
        logger.exception("Unexpected failure while creating cafe via admin API.")
        return JsonResponse(
            {"success": False, "message": "Unexpected error while creating the cafe."},
            # ??? ??????? status ??? ????? ??? ???? ???? ???? ????? ????.
            status=500,
        )

    return JsonResponse(
        {
            "success": True,
            "cafe": {
                "id": cafe.id,
                "name": cafe.name,
                "code": cafe.code,
                "faculty_id": cafe.faculty_id,
                "owner_id": cafe.owner_id,
                "is_active": cafe.is_active,
            },
        },
        # ??? ??????? status ??? ????? ??? ???? ???? ???? ????? ????.
        status=201,
    )


# ???? ???? toggle_cafe_status_api ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@require_POST
def toggle_cafe_status_api(request: HttpRequest, cafe_id: int) -> JsonResponse:
    try:
        # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
        cafe = toggle_cafe_active_status(cafe_id=cafe_id)
    except ValidationServiceError as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)

    return JsonResponse(
        {
            "success": True,
            "cafe": {
                "id": cafe.id,
                "name": cafe.name,
                "code": cafe.code,
                "is_active": cafe.is_active,
            },
        }
    )


@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
@require_POST
def cafe_wallet_operation_api(request: HttpRequest) -> JsonResponse:
    cafe = resolve_backoffice_cafe(request.user)
    if cafe is None:
        return JsonResponse({"success": False, "message": "No active cafe is linked to this account."}, status=403)

    wallet = _find_wallet_by_identifier(request.POST.get("identifier"))
    if wallet is None:
        return JsonResponse({"success": False, "message": "لم يتم العثور على محفظة بهذا البريد أو الهاتف أو الكود."}, status=404)

    try:
        amount = _parse_positive_amount(request.POST.get("amount"))
    except ValidationServiceError as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)

    operation = (request.POST.get("operation") or "DEPOSIT").strip().upper()
    if operation not in {"DEPOSIT", "WITHDRAWAL"}:
        return JsonResponse({"success": False, "message": "نوع العملية غير صحيح."}, status=400)

    note = (request.POST.get("note") or "").strip()
    description = f"{cafe.name} - {'شحن رصيد' if operation == 'DEPOSIT' else 'خصم رصيد'}"
    if note:
        description = f"{description} - {note}"

    try:
        Transaction.objects.create(
            wallet=wallet,
            amount=amount,
            transaction_type=operation,
            source="SYSTEM",
            description=description,
        )
    except ValueError as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)

    return JsonResponse({"success": True, "wallet": _wallet_payload(wallet)})


@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
@require_POST
def cafe_bind_wallet_card_api(request: HttpRequest) -> JsonResponse:
    cafe = resolve_backoffice_cafe(request.user)
    if cafe is None:
        return JsonResponse({"success": False, "message": "No active cafe is linked to this account."}, status=403)

    wallet = _find_wallet_by_identifier(request.POST.get("identifier"))
    if wallet is None:
        return JsonResponse({"success": False, "message": "لم يتم العثور على الطالب أو المحفظة."}, status=404)

    card_code = (request.POST.get("card_code") or request.POST.get("nfc_code") or "").strip().upper()
    if not card_code:
        return JsonResponse({"success": False, "message": "أدخل كود البطاقة أو مرر بطاقة NFC في الحقل."}, status=400)
    if Wallet.objects.filter(link_code__iexact=card_code).exclude(pk=wallet.pk).exists():
        return JsonResponse({"success": False, "message": "هذه البطاقة مربوطة بمحفظة أخرى."}, status=400)

    wallet.link_code = card_code
    wallet.save(update_fields=["link_code", "updated_at"])
    return JsonResponse({"success": True, "wallet": _wallet_payload(wallet)})


# ???? ???? cafe_panel ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
def cafe_panel(request: HttpRequest) -> HttpResponse:
    # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
    cafe = resolve_backoffice_cafe(request.user, cafe_id=request.GET.get("cafe_id"))
    if cafe is None:
        messages.error(request, "No active cafe is linked to this account.")
        return redirect("core:cafe_login")

    # ??? ??????? snapshot ??? ????? ??? ???? ???? ???? ????? ????.
    snapshot = get_cafe_panel_snapshot(cafe.id)
    # ??? ??????? context ??? ????? ??? ???? ???? ???? ????? ????.
    context = {
        "cafe": cafe,
        "orders_by_status": snapshot["orders_by_status"],
        "products": snapshot["products"],
        "categories": Category.objects.for_cafe(cafe.id).filter(is_active=True),
        "kpis": snapshot["kpis"],
        "wallet_kpis": {
            "total_balance": Wallet.objects.aggregate(total=Sum("balance"))["total"] or 0,
            "linked_cards": Wallet.objects.exclude(link_code__isnull=True).exclude(link_code="").count(),
            "wallets": Wallet.objects.count(),
        },
        "recent_wallet_transactions": Transaction.objects.select_related("wallet", "wallet__user").order_by("-created_at")[:8],
        "status_choices": [
            ("PENDING", "New"),
            ("PREPARING", "Preparing"),
            ("READY", "Ready"),
            ("COMPLETED", "Completed"),
            ("CANCELLED", "Cancelled"),
        ],
        "ws_path": f"/ws/cafe/{cafe.id}/orders/",
    }
    return render(request, "admin_v2/cafe_panel.html", context)


@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
def cafe_panel_snapshot_api(request: HttpRequest) -> JsonResponse:
    cafe = resolve_backoffice_cafe(request.user, cafe_id=request.GET.get("cafe_id"))
    if cafe is None:
        return JsonResponse({"success": False, "message": "No cafe scope available."}, status=403)

    snapshot = get_cafe_panel_snapshot(cafe.id)
    live_orders = []
    for status in ("PENDING", "PREPARING", "READY"):
        live_orders.extend(snapshot["orders_by_status"].get(status, []))

    return JsonResponse(
        {
            "success": True,
            "cafe_id": cafe.id,
            "orders": OrderSerializer(live_orders, many=True).data,
            "kpis": snapshot["kpis"],
        }
    )


# ???? ???? update_order_status_api ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
@require_POST
def update_order_status_api(request: HttpRequest, order_id: int) -> JsonResponse:
    # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
    cafe = resolve_backoffice_cafe(request.user, cafe_id=request.POST.get("cafe_id"))
    if cafe is None:
        return JsonResponse({"success": False, "message": "No cafe scope available."}, status=403)

    try:
        # ??? ??????? order ??? ????? ??? ???? ???? ???? ????? ????.
        order = update_order_status(
            # ??? ??????? order_id ??? ????? ??? ???? ???? ???? ????? ????.
            order_id=order_id,
            # ??? ??????? cafe_id ??? ????? ??? ???? ???? ???? ????? ????.
            cafe_id=cafe.id,
            # ??? ??????? new_status ??? ????? ??? ???? ???? ???? ????? ????.
            new_status=request.POST.get("status", ""),
            # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
            user=request.user,
        )
    except (ValidationServiceError, NotFoundServiceError) as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)

    # ??? ??????? payload ??? ????? ??? ???? ???? ???? ????? ????.
    payload = OrderSerializer(order).data
    return JsonResponse({"success": True, "order": payload})


# ???? ???? toggle_product_stock_api ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
@require_POST
def toggle_product_stock_api(request: HttpRequest, product_id: int) -> JsonResponse:
    # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
    cafe = resolve_backoffice_cafe(request.user, cafe_id=request.POST.get("cafe_id"))
    if cafe is None:
        return JsonResponse({"success": False, "message": "No cafe scope available."}, status=403)

    try:
        # ??? ??????? raw_value ??? ????? ??? ???? ???? ???? ????? ????.
        raw_value = request.POST.get("is_available", "true")
        # ??? ??????? product ??? ????? ??? ???? ???? ???? ????? ????.
        product = toggle_product_stock(
            # ??? ??????? cafe_id ??? ????? ??? ???? ???? ???? ????? ????.
            cafe_id=cafe.id,
            # ??? ??????? product_id ??? ????? ??? ???? ???? ???? ????? ????.
            product_id=product_id,
            # ??? ??????? is_available ??? ????? ??? ???? ???? ???? ????? ????.
            is_available=str(raw_value).lower() == "true",
            # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
            user=request.user,
        )
    except ValidationServiceError as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)

    return JsonResponse(
        {
            "success": True,
            "product": {
                "id": product.id,
                "name": product.name,
                "is_available": product.is_available,
            },
        }
    )


@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
@require_POST
def save_product_api(request: HttpRequest, product_id: int | None = None) -> JsonResponse:
    cafe = resolve_backoffice_cafe(request.user, cafe_id=request.POST.get("cafe_id"))
    if cafe is None:
        return JsonResponse({"success": False, "message": "No cafe scope available."}, status=403)

    try:
        product = save_cafe_product(
            cafe_id=cafe.id,
            user=request.user,
            data=request.POST,
            files=request.FILES,
            product_id=product_id,
        )
    except ValidationServiceError as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)

    return JsonResponse(
        {
            "success": True,
            "product": ProductSerializer(product, context={"request": request}).data,
        }
    )
