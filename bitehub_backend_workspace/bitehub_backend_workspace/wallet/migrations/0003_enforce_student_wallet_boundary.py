from django.db import migrations
from django.db.models import Q


def enforce_student_wallet_boundary(apps, schema_editor):
    User = apps.get_model("users", "User")
    Wallet = apps.get_model("wallet", "Wallet")

    User.objects.filter(my_cafe__isnull=False, is_staff=False).update(is_staff=True)

    wallet_ids = list(
        Wallet.objects.filter(
            Q(user__is_superuser=True)
            | Q(user__is_staff=True)
            | Q(user__email__iendswith="@bitehub.local")
            | Q(user__my_cafe__isnull=False)
        )
        .distinct()
        .values_list("id", flat=True)
    )
    if wallet_ids:
        Wallet.objects.filter(id__in=wallet_ids).delete()


def noop_reverse(apps, schema_editor):
    return None


class Migration(migrations.Migration):

    dependencies = [
        ("wallet", "0002_purge_non_student_wallets"),
    ]

    operations = [
        migrations.RunPython(enforce_student_wallet_boundary, noop_reverse),
    ]
