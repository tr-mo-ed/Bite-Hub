from __future__ import annotations

from decimal import Decimal, InvalidOperation
import json
import logging

from django.conf import settings
from django.contrib import messages
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required, user_passes_test
from django.db.models import OuterRef, Q, Subquery, Sum
from django.http import HttpRequest, HttpResponse, JsonResponse
from django.shortcuts import redirect, render
from django.urls import reverse
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_POST
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

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
from .backoffice_services import (
    provision_cafe,
    provision_cafe_with_credentials,
    reset_cafe_operator_password,
    save_cafe_product,
    set_cafe_accepting_orders,
    set_cafe_active_status,
    toggle_cafe_active_status,
    toggle_product_stock,
    update_cafe_image,
)
from .credential_vault import decrypt_cafe_password
from .models import Cafe, Category
from .serializers import OrderSerializer, ProductSerializer
from .services import NotFoundServiceError, ValidationServiceError, update_order_status
from .utils import normalize_libyan_phone
from users.models import User
from wallet.models import Transaction, Wallet, WalletDebitRequest
from wallet.services import create_cafe_debit_request

# ??? ??????? logger ??? ????? ??? ???? ???? ???? ????? ????.
logger = logging.getLogger(__name__)


def _parse_bool_flag(value) -> bool | None:
    if isinstance(value, bool):
        return value
    normalized = str(value or "").strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    return None


def _cafe_status_payload(cafe: Cafe) -> dict:
    return {
        "id": cafe.id,
        "name": cafe.name,
        "code": cafe.code,
        "is_active": cafe.is_active,
        "is_accepting_orders": cafe.is_accepting_orders,
    }


def _login_context(**extra) -> dict:
    context = {
        "portal": "admin",
    }
    context.update(extra)
    return context


# ???? ???? _is_staff_or_superuser ?????? ????? ?????? ?? ????? ????.
def _is_staff_or_superuser(user) -> bool:
    return bool(user.is_authenticated and (user.is_staff or user.is_superuser or getattr(user, "my_cafe", None)))


def _is_cafe_operator(user) -> bool:
    cafe = getattr(user, "my_cafe", None)
    return bool(
        user.is_authenticated
        and not user.is_superuser
        and cafe is not None
        and cafe.is_active
        and (user.is_staff or cafe.owner_id == user.id)
    )


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
            "cafe_options": get_cafe_login_options(),
            "login_action_url": _login_action_url(portal="cafe", cafe=cafe),
            "page_title": "دخول مركز عمليات المقهى",
            "page_subtitle": "اختر الكلية ثم أدخل كلمة المرور الخاصة بمشغل المقهى.",
            "submit_label": "دخول مركز العمليات",
            "alternate_login_url": reverse("core:admin_login"),
            "alternate_login_label": "دخول السوبر أدمن",
        }
    return {
        "portal": "admin",
        "target_cafe": None,
        "cafe_options": [],
        "login_action_url": reverse("core:admin_login"),
        "page_title": "دخول مركز الإدارة العليا",
        "page_subtitle": "دخول محمي بكلمة مرور السوبر أدمن فقط.",
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
    if (
        user_cafe is not None
        and user_cafe.is_active
        and (cafe is None or user_cafe.id == cafe.id)
    ):
        return "core:cafe_panel"
    return None


def get_cafe_login_options():
    return (
        Cafe.objects.filter(is_active=True, owner__isnull=False)
        .select_related("faculty", "owner")
        .order_by("faculty__name", "name")
    )


def _resolve_admin_login_user() -> User | None:
    configured_email = getattr(settings, "BACKOFFICE_SUPER_ADMIN_EMAIL", "")
    if configured_email:
        user = User.objects.filter(email__iexact=configured_email, is_active=True, is_superuser=True).first()
        if user:
            return user
    return User.objects.filter(is_active=True, is_superuser=True).order_by("id").first()


def _resolve_cafe_for_login(raw_cafe_id: str | None, target_cafe: Cafe | None = None) -> Cafe | None:
    if target_cafe is not None:
        return target_cafe
    try:
        cafe_id = int(raw_cafe_id or 0)
    except (TypeError, ValueError):
        return None
    return Cafe.objects.filter(id=cafe_id, is_active=True, owner__isnull=False).select_related("owner").first()


# ???? ???? custom_login ?????? ????? ?????? ?? ????? ????.
def custom_login(request: HttpRequest, portal: str = "admin", cafe_code: str | None = None) -> HttpResponse:
    portal = "cafe" if portal == "cafe" else "admin"
    target_cafe = None
    if cafe_code:
        target_cafe = Cafe.objects.filter(code=cafe_code, is_active=True).select_related("owner").first()
        if target_cafe is None:
            messages.error(request, "رابط المقهى غير صحيح أو غير مفعل.")
            return redirect("core:cafe_login")

    base_context = _login_role_context(portal=portal, cafe=target_cafe)

    if request.user.is_authenticated:
        destination = _authenticated_login_destination(request.user, portal=portal, cafe=target_cafe)
        if destination is not None:
            return redirect(destination)
        logout(request)

    if request.method == "POST":
        # ??? ??????? password ??? ????? ??? ???? ???? ???? ????? ????.
        password = request.POST.get("password") or ""
        if portal == "cafe":
            # Cafe passwords are trimmed when created/reset, so accept the same
            # value when it is pasted with accidental surrounding whitespace.
            password = password.strip()
        selected_cafe_id = (request.POST.get("cafe_id") or "").strip()

        if portal == "admin":
            admin_user = _resolve_admin_login_user()
            if admin_user is None:
                return render(
                    request,
                    "login.html",
                    _login_context(**base_context, error="لم يتم العثور على حساب سوبر أدمن فعال."),
                )
            user = authenticate(request, username=admin_user.email, password=password)
        else:
            selected_cafe = _resolve_cafe_for_login(selected_cafe_id, target_cafe=target_cafe)
            if selected_cafe is None or selected_cafe.owner is None:
                return render(
                    request,
                    "login.html",
                    _login_context(
                        **base_context,
                        error="اختر الكلية/المقهى أولاً.",
                        selected_cafe_id=selected_cafe_id,
                    ),
                )
            user = authenticate(request, username=selected_cafe.owner.email, password=password)

        if user:
            if portal == "admin" and not user.is_superuser:
                return render(
                    request,
                    "login.html",
                    _login_context(
                        **base_context,
                        error="هذا الرابط مخصص للسوبر أدمن فقط.",
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
                            selected_cafe_id=selected_cafe_id,
                        ),
                    )
                if selected_cafe is not None and user_cafe.id != selected_cafe.id:
                    return render(
                        request,
                        "login.html",
                        _login_context(
                            **base_context,
                            error="هذا الحساب غير مرتبط بهذا المقهى.",
                            selected_cafe_id=selected_cafe_id,
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
                selected_cafe_id=selected_cafe_id,
            ),
        )

    return render(request, "login.html", _login_context(**base_context, selected_cafe_id=str(target_cafe.id) if target_cafe else ""))


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
    cafe = Cafe.objects.filter(
        id=cafe_id,
        is_active=True,
        owner__isnull=False,
    ).select_related("owner").first()
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
    user_cafe = getattr(request.user, "my_cafe", None)
    if user_cafe is not None and not user_cafe.is_active:
        reason = user_cafe.suspension_reason or "\u0631\u0627\u062c\u0639 \u0625\u062f\u0627\u0631\u0629 Bite Hub."
        logout(request)
        messages.error(
            request,
            f"\u0645\u0646\u0638\u0648\u0645\u0629 {user_cafe.name} \u0645\u0648\u0642\u0648\u0641\u0629 \u0645\u0624\u0642\u062a\u0627\u064b. \u0627\u0644\u0633\u0628\u0628: {reason}",
        )
        return redirect("core:cafe_login")

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

    return (
        Wallet.objects.select_related("user")
        .filter(Q(link_code__iexact=identifier))
        .first()
    )


def _wallet_payload(wallet: Wallet) -> dict:
    wallet.refresh_from_db()
    return {
        "user": wallet.user.full_name or wallet.user.email,
        "email": wallet.user.email,
        "phone": wallet.user.phone_number,
        "balance": str(wallet.balance),
        "link_code": wallet.link_code,
        "college": wallet.college,
    }


def _cafe_wallet_activity(cafe: Cafe) -> tuple[list[Transaction], list[Wallet]]:
    latest_transaction_id = (
        Transaction.objects.filter(cafe=cafe, wallet_id=OuterRef("wallet_id"))
        .order_by("-created_at")
        .values("id")[:1]
    )
    recent_activity = list(
        Transaction.objects.filter(cafe=cafe)
        .filter(id=Subquery(latest_transaction_id))
        .select_related("wallet", "wallet__user")
        .order_by("-created_at")
    )
    wallet_ids = {
        transaction_item.wallet_id for transaction_item in recent_activity
    }
    wallet_ids.update(
        WalletDebitRequest.objects.filter(cafe=cafe).values_list(
            "wallet_id",
            flat=True,
        )
    )
    wallets = list(
        Wallet.objects.filter(id__in=wallet_ids)
        .select_related("user")
        .order_by("user__full_name", "user__email", "id")
    )
    return recent_activity, wallets


def _debit_request_payload(request_item: WalletDebitRequest) -> dict:
    return {
        "id": str(request_item.id),
        "student_name": (
            request_item.wallet.user.full_name
            or request_item.wallet.user.email
        ),
        "student_email": request_item.wallet.user.email,
        "amount": str(request_item.amount),
        "note": request_item.note,
        "status": request_item.status,
        "status_display": request_item.get_status_display(),
        "created_at": request_item.created_at.strftime("%Y-%m-%d %H:%M"),
        "responded_at": (
            request_item.responded_at.strftime("%Y-%m-%d %H:%M")
            if request_item.responded_at
            else ""
        ),
    }


# ???? ???? super_admin_dashboard ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@never_cache
def super_admin_dashboard(request: HttpRequest) -> HttpResponse:
    # ??? ??????? sales_series ??? ????? ??? ???? ???? ???? ????? ????.
    sales_series = get_super_admin_sales_series()
    # ??? ??????? form_data ??? ????? ??? ???? ???? ???? ????? ????.
    form_data = request.session.pop(
        "super_admin_cafe_form_data",
        {
            "name": "",
            "code": "",
            "faculty_name": "",
            "faculty_id": "",
            "owner_id": "",
        },
    )
    cafes = list(get_all_cafes_for_admin())
    for cafe in cafes:
        cafe.operator_password_display = decrypt_cafe_password(
            cafe.operator_password_ciphertext
        )

    # ??? ??????? context ??? ????? ??? ???? ???? ???? ????? ????.
    context = {
        "kpis": get_super_admin_kpis(),
        "sales_series": sales_series,
        "cafe_breakdown": get_super_admin_cafe_breakdown(),
        "cafes": cafes,
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
        "faculty_name": (request.POST.get("faculty_name") or "").strip(),
        "faculty_id": (request.POST.get("faculty_id") or "").strip(),
        "owner_id": (request.POST.get("owner_id") or "").strip(),
    }
    manager_password = (request.POST.get("manager_password") or "").strip()
    try:
        if manager_password:
            cafe = provision_cafe_with_credentials(
                faculty_name=form_data["faculty_name"],
                password=manager_password,
                name=form_data["name"],
                code=form_data["code"],
                image=request.FILES.get("image"),
            )
        else:
            # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
            cafe = provision_cafe(
                # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
                name=form_data["name"],
                # ??? ??????? code ??? ????? ??? ???? ???? ???? ????? ????.
                code=form_data["code"],
                # ??? ??????? faculty_id ??? ????? ??? ???? ???? ???? ????? ????.
                faculty_id=_parse_optional_faculty_id(form_data["faculty_id"]),
                owner_id=_parse_optional_faculty_id(form_data["owner_id"]),
                image=request.FILES.get("image"),
            )
        if manager_password:
            messages.success(request, f"تم إنشاء {cafe.name}. كلمة مرور الدخول: {manager_password}")
        else:
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


@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@require_POST
def update_cafe_image_from_dashboard(request: HttpRequest, cafe_id: int) -> HttpResponse:
    try:
        cafe = update_cafe_image(
            cafe_id=cafe_id,
            image=request.FILES.get("image"),
        )
        messages.success(
            request,
            f"\u062a\u0645 \u062a\u062d\u062f\u064a\u062b \u0635\u0648\u0631\u0629 {cafe.name} \u0628\u0646\u062c\u0627\u062d.",
        )
    except ValidationServiceError as exc:
        messages.error(request, str(exc))
    return redirect("core:super_admin_dashboard")


# ???? ???? toggle_cafe_status_from_dashboard ?????? ????? ?????? ?? ????? ????.
@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@require_POST
def toggle_cafe_status_from_dashboard(request: HttpRequest, cafe_id: int) -> HttpResponse:
    try:
        action = (request.POST.get("action") or "").strip().lower()
        if action not in {"suspend", "activate"}:
            cafe = toggle_cafe_active_status(
                cafe_id=cafe_id,
                suspension_reason=request.POST.get("suspension_reason", ""),
            )
        else:
            cafe = set_cafe_active_status(
                cafe_id=cafe_id,
                is_active=action == "activate",
                suspension_reason=request.POST.get("suspension_reason", ""),
            )
        if cafe.is_active:
            messages.success(request, f"\u062a\u0645 \u062a\u0641\u0639\u064a\u0644 \u0645\u0646\u0638\u0648\u0645\u0629 {cafe.name} \u0628\u0646\u062c\u0627\u062d.")
        else:
            messages.success(
                request,
                f"\u062a\u0645 \u0625\u064a\u0642\u0627\u0641 \u0645\u0646\u0638\u0648\u0645\u0629 {cafe.name} \u0645\u0624\u0642\u062a\u0627\u064b: {cafe.suspension_reason}",
            )
    except ValidationServiceError as exc:
        messages.error(request, str(exc))
    return redirect("core:super_admin_dashboard")


@login_required(login_url="core:admin_login")
@user_passes_test(lambda user: user.is_superuser, login_url="core:route_after_login")
@require_POST
def reset_cafe_password_from_dashboard(request: HttpRequest, cafe_id: int) -> HttpResponse:
    new_password = (request.POST.get("manager_password") or "").strip()
    try:
        cafe = reset_cafe_operator_password(
            cafe_id=cafe_id,
            password=new_password,
        )
        messages.success(request, f"\u062a\u0645 \u0636\u0628\u0637 \u0643\u0644\u0645\u0629 \u0645\u0631\u0648\u0631 {cafe.name}: {new_password}")
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
    description = f"{cafe.name} - {'شحن رصيد' if operation == 'DEPOSIT' else 'طلب خصم رصيد'}"
    if note:
        description = f"{description} - {note}"

    if operation == "WITHDRAWAL":
        duplicate_request = (
            WalletDebitRequest.objects.filter(
                wallet=wallet,
                cafe=cafe,
                amount=amount,
                status=WalletDebitRequest.Status.PENDING,
            )
            .order_by("-created_at")
            .first()
        )
        if duplicate_request is not None:
            return JsonResponse(
                {
                    "success": False,
                    "message": "يوجد طلب خصم معلّق بنفس المبلغ لهذا الطالب.",
                    "debit_request": _debit_request_payload(
                        duplicate_request
                    ),
                },
                status=409,
            )
        request_item = create_cafe_debit_request(
            cafe=cafe,
            wallet=wallet,
            amount=amount,
            requested_by=request.user,
            note=note,
        )
        return JsonResponse(
            {
                "success": True,
                "pending_approval": True,
                "message": (
                    "تم إرسال طلب الخصم إلى الطالب. "
                    "لن يتغير الرصيد قبل موافقته."
                ),
                "wallet": _wallet_payload(wallet),
                "debit_request": _debit_request_payload(request_item),
            },
            status=202,
        )

    try:
        Transaction.objects.create(
            wallet=wallet,
            cafe=cafe,
            amount=amount,
            transaction_type=operation,
            source="SYSTEM",
            description=description,
        )
    except ValueError as exc:
        return JsonResponse({"success": False, "message": str(exc)}, status=400)

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
    recent_wallet_activity, wallet_directory = _cafe_wallet_activity(cafe)
    wallet_ids = [wallet.id for wallet in wallet_directory]
    # ??? ??????? context ??? ????? ??? ???? ???? ???? ????? ????.
    context = {
        "cafe": cafe,
        "orders_by_status": snapshot["orders_by_status"],
        "products": snapshot["products"],
        "categories": Category.objects.for_cafe(cafe.id).filter(is_active=True),
        "kpis": snapshot["kpis"],
        "wallet_kpis": {
            "total_balance": Wallet.objects.filter(id__in=wallet_ids).aggregate(total=Sum("balance"))["total"] or 0,
            "wallets": len(wallet_ids),
        },
        "recent_wallet_activity": recent_wallet_activity,
        "debit_requests": (
            WalletDebitRequest.objects.filter(cafe=cafe)
            .select_related("wallet", "wallet__user")
            .order_by("-created_at")[:40]
        ),
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
def cafe_wallet_debit_requests_api(request: HttpRequest) -> JsonResponse:
    cafe = resolve_backoffice_cafe(request.user)
    if cafe is None:
        return JsonResponse(
            {"success": False, "message": "No cafe scope available."},
            status=403,
        )
    requests = (
        WalletDebitRequest.objects.filter(cafe=cafe)
        .select_related("wallet", "wallet__user")
        .order_by("-created_at")[:40]
    )
    return JsonResponse(
        {
            "success": True,
            "requests": [
                _debit_request_payload(request_item)
                for request_item in requests
            ],
        }
    )


@login_required(login_url="core:cafe_login")
@user_passes_test(_is_cafe_operator, login_url="core:route_after_login")
def cafe_wallet_history_api(request: HttpRequest, wallet_id: int) -> JsonResponse:
    cafe = resolve_backoffice_cafe(request.user)
    if cafe is None:
        return JsonResponse({"success": False, "message": "No cafe scope available."}, status=403)

    wallet = Wallet.objects.select_related("user").filter(pk=wallet_id).first()
    if wallet is None:
        return JsonResponse({"success": False, "message": "المحفظة غير موجودة."}, status=404)

    transactions = list(
        Transaction.objects.filter(cafe=cafe, wallet=wallet)
        .order_by("-created_at")
    )
    if not transactions:
        return JsonResponse(
            {"success": False, "message": "لا يوجد سجل لهذا الطالب داخل هذا المقهى."},
            status=404,
        )

    return JsonResponse(
        {
            "success": True,
            "student": {
                "name": wallet.user.full_name or wallet.user.email,
                "email": wallet.user.email,
                "phone": wallet.user.phone_number,
                "wallet_code": wallet.link_code,
                "balance": str(wallet.balance),
            },
            "transactions": [
                {
                    "id": str(transaction_item.id),
                    "type": transaction_item.transaction_type,
                    "amount": str(transaction_item.amount),
                    "source": transaction_item.source,
                    "description": transaction_item.description or "عملية محفظة",
                    "created_at": transaction_item.created_at.strftime("%Y-%m-%d %H:%M"),
                }
                for transaction_item in transactions
            ],
        }
    )


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


@api_view(["GET", "PATCH", "POST"])
@permission_classes([IsAuthenticated])
def cafe_accepting_orders_api(request):
    cafe = resolve_backoffice_cafe(request.user)
    if cafe is None:
        return Response(
            {"success": False, "message": "No active cafe is linked to this account."},
            status=403,
        )

    if request.method == "GET":
        return Response({"success": True, "cafe": _cafe_status_payload(cafe)})

    desired_status = _parse_bool_flag(request.data.get("is_accepting_orders"))
    if desired_status is None:
        return Response(
            {
                "success": False,
                "message": "is_accepting_orders must be true or false.",
            },
            status=400,
        )

    try:
        cafe = set_cafe_accepting_orders(
            cafe_id=cafe.id,
            is_accepting_orders=desired_status,
            user=request.user,
        )
    except ValidationServiceError as exc:
        return Response({"success": False, "message": str(exc)}, status=400)

    return Response(
        {
            "success": True,
            "message": "تم فتح استقبال الطلبات." if cafe.is_accepting_orders else "تم إغلاق استقبال الطلبات.",
            "cafe": _cafe_status_payload(cafe),
        }
    )


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
