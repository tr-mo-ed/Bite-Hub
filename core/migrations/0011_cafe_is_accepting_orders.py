from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0010_cafe_operator_password_ciphertext"),
    ]

    operations = [
        migrations.AddField(
            model_name="cafe",
            name="is_accepting_orders",
            field=models.BooleanField(default=True),
        ),
    ]
