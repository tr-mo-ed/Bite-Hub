from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0008_alter_order_payment_method"),
    ]

    operations = [
        migrations.AddField(
            model_name="order",
            name="notes",
            field=models.TextField(blank=True, default=""),
        ),
    ]
