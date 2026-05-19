from django.db import migrations, models


def seed_existing_product_stock(apps, schema_editor):
    Product = apps.get_model("core", "Product")
    Product.objects.filter(is_available=True, stock_quantity=0).update(stock_quantity=999)


class Migration(migrations.Migration):

    dependencies = [
        ("core", "0004_notification"),
    ]

    operations = [
        migrations.AddField(
            model_name="product",
            name="stock_quantity",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.RunPython(seed_existing_product_stock, migrations.RunPython.noop),
        migrations.AddIndex(
            model_name="product",
            index=models.Index(fields=["cafe", "stock_quantity"], name="core_produc_cafe_id_33246c_idx"),
        ),
    ]
