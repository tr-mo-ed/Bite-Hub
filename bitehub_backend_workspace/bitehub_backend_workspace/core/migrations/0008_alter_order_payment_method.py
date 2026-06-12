from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0007_cafe_suspension_fields"),
    ]

    operations = [
        migrations.AlterField(
            model_name="order",
            name="payment_method",
            field=models.CharField(
                choices=[
                    ("WALLET", "Wallet"),
                    ("CASH", "Cash"),
                    ("NFC", "NFC"),
                ],
                default="WALLET",
                max_length=10,
            ),
        ),
    ]
