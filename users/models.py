import uuid

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models


class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("يجب إدخال البريد الإلكتروني")

        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    username = None
    email = models.EmailField(verbose_name="البريد الإلكتروني", unique=True)
    phone_number = models.CharField(
        max_length=15,
        unique=True,
        verbose_name="رقم الهاتف",
    )
    secondary_phone_number = models.CharField(
        max_length=15,
        unique=True,
        blank=True,
        null=True,
        verbose_name="رقم هاتف إضافي",
    )
    full_name = models.CharField(max_length=100, verbose_name="الاسم الكامل")
    image = models.ImageField(
        upload_to="profiles/",
        null=True,
        blank=True,
        verbose_name="صورة الملف الشخصي",
    )
    profile_image_url = models.CharField(
        max_length=500,
        blank=True,
        null=True,
        verbose_name="رابط الصورة",
    )

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["full_name", "phone_number"]

    objects = CustomUserManager()

    def __str__(self):
        return self.email


class EmailLoginCode(models.Model):
    request_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="email_login_codes",
    )
    code_hash = models.CharField(max_length=64)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("user", "created_at")),
            models.Index(fields=("expires_at",)),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.request_id}"


class EmailSignupCode(models.Model):
    request_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    email = models.EmailField()
    full_name = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=15)
    password_hash = models.CharField(max_length=128)
    code_hash = models.CharField(max_length=64)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=("email", "created_at")),
            models.Index(fields=("phone_number", "created_at")),
            models.Index(fields=("expires_at",)),
        ]

    def __str__(self):
        return f"{self.email} - {self.request_id}"
