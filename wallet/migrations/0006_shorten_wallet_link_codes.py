import secrets

from django.db import migrations


def _is_short_numeric_code(value):
    code = (value or "").strip()
    return code.isdigit() and 4 <= len(code) <= 5


def _generate_code(used_codes):
    for _ in range(200_000):
        candidate = f"{secrets.randbelow(100_000):05d}"
        if candidate not in used_codes:
            return candidate
    raise RuntimeError("Unable to generate a unique wallet link code.")


def shorten_wallet_link_codes(apps, schema_editor):
    Wallet = apps.get_model("wallet", "Wallet")
    used_codes = {
        (code or "").strip()
        for code in Wallet.objects.values_list("link_code", flat=True)
        if _is_short_numeric_code(code)
    }

    for wallet in Wallet.objects.all().order_by("pk").iterator():
        current = (wallet.link_code or "").strip()
        if _is_short_numeric_code(current):
            continue
        candidate = _generate_code(used_codes)
        used_codes.add(candidate)
        wallet.link_code = candidate
        wallet.save(update_fields=["link_code"])


class Migration(migrations.Migration):

    dependencies = [
        ("wallet", "0005_alter_wallet_link_code"),
    ]

    operations = [
        migrations.RunPython(shorten_wallet_link_codes, migrations.RunPython.noop),
    ]
