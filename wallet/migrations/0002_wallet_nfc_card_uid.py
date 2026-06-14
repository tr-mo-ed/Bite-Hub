from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("wallet", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="wallet",
            name="nfc_card_uid",
            field=models.CharField(
                blank=True,
                max_length=64,
                null=True,
                unique=True,
                verbose_name="معرف بطاقة NFC",
            ),
        ),
        migrations.AlterField(
            model_name="transaction",
            name="source",
            field=models.CharField(
                choices=[
                    ("SYSTEM", "المنظومة"),
                    ("APP", "التطبيق"),
                    ("USER", "المستخدم"),
                    ("NFC", "بطاقة NFC"),
                ],
                default="SYSTEM",
                max_length=20,
            ),
        ),
    ]
