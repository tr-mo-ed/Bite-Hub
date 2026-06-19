import base64
import hashlib

from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings


def _fernet() -> Fernet:
    source = (
        settings.CAFE_CREDENTIALS_ENCRYPTION_KEY.strip()
        or settings.SECRET_KEY
    )
    digest = hashlib.sha256(
        f"bitehub:cafe-credentials:v1:{source}".encode("utf-8")
    ).digest()
    return Fernet(base64.urlsafe_b64encode(digest))


def encrypt_cafe_password(password: str) -> str:
    normalized = (password or "").strip()
    if not normalized:
        return ""
    return _fernet().encrypt(normalized.encode("utf-8")).decode("ascii")


def decrypt_cafe_password(ciphertext: str) -> str | None:
    if not ciphertext:
        return None
    try:
        return _fernet().decrypt(ciphertext.encode("ascii")).decode("utf-8")
    except (InvalidToken, ValueError, UnicodeError):
        return None
