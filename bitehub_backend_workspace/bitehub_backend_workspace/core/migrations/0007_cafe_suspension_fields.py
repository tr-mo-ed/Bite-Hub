from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0006_seed_backoffice_super_admin"),
    ]

    operations = [
        migrations.AddField(
            model_name="cafe",
            name="suspended_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="cafe",
            name="suspension_reason",
            field=models.CharField(blank=True, max_length=255),
        ),
    ]
