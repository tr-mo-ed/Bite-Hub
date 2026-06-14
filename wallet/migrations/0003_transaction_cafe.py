import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0008_alter_order_payment_method"),
        ("wallet", "0002_wallet_nfc_card_uid"),
    ]

    operations = [
        migrations.AddField(
            model_name="transaction",
            name="cafe",
            field=models.ForeignKey(
                blank=True,
                db_index=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="wallet_transactions",
                to="core.cafe",
            ),
        ),
    ]
