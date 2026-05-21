from django.db import migrations


def purge_non_student_wallets(apps, schema_editor):
    Wallet = apps.get_model("wallet", "Wallet")
    Cafe = apps.get_model("core", "Cafe")

    cafe_owner_ids = list(
        Cafe.objects.exclude(owner_id__isnull=True).values_list("owner_id", flat=True)
    )

    ineligible_wallets = Wallet.objects.filter(
        user__is_superuser=True,
    ) | Wallet.objects.filter(
        user__is_staff=True,
    )

    if cafe_owner_ids:
        ineligible_wallets = ineligible_wallets | Wallet.objects.filter(
            user_id__in=cafe_owner_ids
        )

    wallet_ids = list(ineligible_wallets.values_list("id", flat=True).distinct())
    if wallet_ids:
        Wallet.objects.filter(id__in=wallet_ids).delete()


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0006_seed_backoffice_super_admin"),
        ("wallet", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(purge_non_student_wallets, noop_reverse),
    ]
