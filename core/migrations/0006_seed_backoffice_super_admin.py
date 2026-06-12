from django.contrib.auth.hashers import make_password
from django.db import migrations


SUPER_ADMIN_EMAIL = "hsjshdvehhs@gmail.com"
SUPER_ADMIN_PASSWORD = "ByteHub2026"


def ensure_backoffice_super_admin(apps, schema_editor):
    User = apps.get_model("users", "User")

    phone = "0999999900"
    suffix = 1
    while User.objects.filter(phone_number=phone).exclude(email__iexact=SUPER_ADMIN_EMAIL).exists():
        phone = f"09999999{suffix:02d}"
        suffix += 1

    user = User.objects.filter(email__iexact=SUPER_ADMIN_EMAIL).first()
    if user is None:
        User.objects.create(
            email=SUPER_ADMIN_EMAIL,
            password=make_password(SUPER_ADMIN_PASSWORD),
            full_name="Bite Hub Super Admin",
            phone_number=phone,
            is_staff=True,
            is_superuser=True,
            is_active=True,
        )
        return

    user.password = make_password(SUPER_ADMIN_PASSWORD)
    user.full_name = user.full_name or "Bite Hub Super Admin"
    user.phone_number = user.phone_number or phone
    user.is_staff = True
    user.is_superuser = True
    user.is_active = True
    user.save(update_fields=["password", "full_name", "phone_number", "is_staff", "is_superuser", "is_active"])


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0001_initial"),
        ("core", "0005_product_stock_quantity"),
    ]

    operations = [
        migrations.RunPython(ensure_backoffice_super_admin, migrations.RunPython.noop),
    ]
