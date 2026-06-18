from dataclasses import dataclass
from html import escape

import requests
from django.conf import settings


class EmailDeliveryError(Exception):
    pass


@dataclass(frozen=True)
class EmailDeliveryResult:
    delivered: bool
    debug_mode: bool = False


def send_verification_code(
    *,
    recipient_email: str,
    recipient_name: str,
    code: str,
    purpose: str,
) -> EmailDeliveryResult:
    api_key = settings.BREVO_API_KEY.strip()
    if not api_key:
        if settings.DEBUG and settings.BREVO_DEBUG_EMAIL_CODES:
            return EmailDeliveryResult(delivered=False, debug_mode=True)
        raise EmailDeliveryError("Brevo is not configured.")

    safe_name = escape(recipient_name or "مستخدم Bite Hub")
    safe_code = escape(code)
    is_signup = purpose == "signup"
    action_text = "تأكيد إنشاء حسابك" if is_signup else "إكمال تسجيل الدخول"
    subject = (
        "رمز تأكيد حساب Bite Hub"
        if is_signup
        else "رمز تسجيل الدخول إلى Bite Hub"
    )
    tag = "bitehub-signup-code" if is_signup else "bitehub-login-code"
    payload = {
        "sender": {
            "name": settings.BREVO_SENDER_NAME,
            "email": settings.BREVO_SENDER_EMAIL,
        },
        "to": [
            {
                "email": recipient_email,
                "name": recipient_name or recipient_email,
            }
        ],
        "subject": subject,
        "htmlContent": f"""
          <div dir="rtl" style="font-family:Arial,sans-serif;max-width:520px;margin:auto;color:#1d2421">
            <h2 style="color:#167c68">Bite Hub</h2>
            <p>مرحباً {safe_name}،</p>
            <p>استخدم رمز التحقق التالي من أجل {action_text}:</p>
            <div style="font-size:32px;font-weight:800;letter-spacing:8px;text-align:center;
                        padding:18px;background:#f0f7f4;border-radius:14px;color:#167c68">
              {safe_code}
            </div>
            <p>تنتهي صلاحية الرمز خلال {settings.EMAIL_LOGIN_CODE_TTL_MINUTES} دقائق.</p>
            <p style="color:#69716d;font-size:13px">إذا لم تطلب هذا الرمز، تجاهل الرسالة.</p>
          </div>
        """,
        "tags": [tag],
    }

    try:
        response = requests.post(
            settings.BREVO_API_URL,
            headers={
                "accept": "application/json",
                "api-key": api_key,
                "content-type": "application/json",
            },
            json=payload,
            timeout=settings.BREVO_REQUEST_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise EmailDeliveryError("Brevo request failed.") from exc

    if response.status_code not in {200, 201, 202}:
        response_details = response.text.strip()[:500]
        raise EmailDeliveryError(
            f"Brevo rejected the email with status {response.status_code}: "
            f"{response_details}"
        )

    return EmailDeliveryResult(delivered=True)


def send_login_code(
    *,
    recipient_email: str,
    recipient_name: str,
    code: str,
) -> EmailDeliveryResult:
    return send_verification_code(
        recipient_email=recipient_email,
        recipient_name=recipient_name,
        code=code,
        purpose="login",
    )


def send_signup_code(
    *,
    recipient_email: str,
    recipient_name: str,
    code: str,
) -> EmailDeliveryResult:
    return send_verification_code(
        recipient_email=recipient_email,
        recipient_name=recipient_name,
        code=code,
        purpose="signup",
    )
