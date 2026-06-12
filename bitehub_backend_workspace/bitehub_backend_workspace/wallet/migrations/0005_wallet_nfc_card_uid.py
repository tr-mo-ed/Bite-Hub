from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("wallet", "0004_alter_transaction_source_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="wallet",
            name="nfc_card_uid",
            field=models.CharField(
                blank=True,
                max_length=20,
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
