from decimal import Decimal
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse

from .api_views import get_products_cached
from .backoffice_services import CAFE_OWNER_GROUP_NAME, provision_cafe, toggle_product_stock
from .models import Cafe, Category, Faculty, Notification, Order, OrderItem, OrderStatus, Product
from .services import ValidationServiceError, cancel_user_order, create_order
from wallet.models import Transaction, Wallet


# ??? ??????? TEST_CHANNEL_LAYERS ??? ????? ??? ???? ???? ???? ????? ????.
TEST_CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    },
}


# ???? ???? CafeProvisioningTests ???? ?????? ????????? ???? ???? ?????.
class CafeProvisioningTests(TestCase):
    def test_seed_cafes_creates_unique_codes_and_is_idempotent(self):
        call_command("seed_cafes", stdout=StringIO())

        codes = list(Cafe.objects.values_list("code", flat=True))
        self.assertEqual(Cafe.objects.count(), 3)
        self.assertEqual(len(set(codes)), 3)
        self.assertTrue(all(codes))

        call_command("seed_cafes", stdout=StringIO())

        self.assertEqual(Cafe.objects.count(), 3)
        self.assertEqual(get_user_model().objects.filter(email__endswith="@bitehub.local").count(), 3)

    def test_seed_cafes_repairs_existing_cafe_with_blank_code(self):
        User = get_user_model()
        owner = User.objects.create_user(
            email="cafe-0911111111@bitehub.local",
            password="12345678",
            full_name="مقهى اللغة العربية",
            phone_number="0911111111",
        )
        cafe = Cafe.objects.create(name="مقهى اللغة العربية", owner=owner, code="")

        call_command("seed_cafes", stdout=StringIO())

        cafe.refresh_from_db()
        self.assertTrue(cafe.code)

    # ???? ???? test_create_cafe_without_faculty ?????? ????? ?????? ?? ????? ????.
    def test_create_cafe_without_faculty(self):
        # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
        cafe = provision_cafe(name="Tripoli Central Cafe", code="tripoli-central")

        self.assertEqual(cafe.name, "Tripoli Central Cafe")
        self.assertEqual(cafe.code, "tripoli-central")
        self.assertIsNone(cafe.faculty)
        self.assertTrue(cafe.is_active)
        self.assertGreaterEqual(Category.objects.for_cafe(cafe.id).count(), 1)

    # ???? ???? test_create_cafe_with_faculty ?????? ????? ?????? ?? ????? ????.
    def test_create_cafe_with_faculty(self):
        # ??? ??????? faculty ??? ????? ??? ???? ???? ???? ????? ????.
        faculty = Faculty.objects.create(
            # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
            name="Faculty of Engineering",
            # ??? ??????? code ??? ????? ??? ???? ???? ???? ????? ????.
            code="engineering",
        )

        # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
        cafe = provision_cafe(
            # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
            name="Engineering Cafe",
            # ??? ??????? code ??? ????? ??? ???? ???? ???? ????? ????.
            code="engineering-cafe",
            # ??? ??????? faculty_id ??? ????? ??? ???? ???? ???? ????? ????.
            faculty_id=faculty.id,
        )

        self.assertEqual(cafe.faculty, faculty)
        self.assertEqual(Cafe.objects.filter(faculty=faculty).count(), 1)

    def test_super_admin_create_cafe_assigns_manager_runtime_access(self):
        User = get_user_model()
        superuser = User.objects.create_superuser(
            email="root@example.com",
            password="StrongPass123",
            full_name="Root Admin",
            phone_number="0911000000",
        )
        manager = User.objects.create_user(
            email="manager@example.com",
            password="StrongPass123",
            full_name="Cafe Manager",
            phone_number="0911000001",
            is_staff=True,
        )
        self.client.force_login(superuser)

        response = self.client.post(
            reverse("core:create_cafe_from_dashboard"),
            data={
                "name": "Medical Cafe",
                "code": "medical-cafe",
                "owner_id": manager.id,
            },
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        cafe = Cafe.objects.get(code="medical-cafe")
        self.assertEqual(cafe.owner, manager)
        self.assertGreaterEqual(Category.objects.for_cafe(cafe.id).count(), 1)
        self.assertTrue(manager.groups.filter(name=CAFE_OWNER_GROUP_NAME).exists())
        self.assertTrue(hasattr(manager, "wallet"))
        manager.wallet.refresh_from_db()
        self.assertEqual(manager.wallet.college, "Medical Cafe")

    def test_super_admin_cannot_assign_same_manager_to_two_cafes(self):
        User = get_user_model()
        manager = User.objects.create_user(
            email="duplicate-manager@example.com",
            password="StrongPass123",
            full_name="Duplicate Manager",
            phone_number="0911000002",
            is_staff=True,
        )
        first_cafe = provision_cafe(
            name="First Cafe",
            code="first-cafe",
            owner_id=manager.id,
        )

        with self.assertRaisesMessage(
            ValidationServiceError,
            "Selected manager is already assigned to another cafe.",
        ):
            provision_cafe(
                name="Second Cafe",
                code="second-cafe",
                owner_id=manager.id,
            )

        self.assertEqual(Cafe.objects.filter(owner=manager).count(), 1)
        self.assertEqual(first_cafe.owner, manager)


# ???? ???? OrderWorkflowTests ???? ?????? ????????? ???? ???? ?????.
@override_settings(CHANNEL_LAYERS=TEST_CHANNEL_LAYERS)
class OrderWorkflowTests(TestCase):
    # ???? ???? setUp ?????? ????? ?????? ?? ????? ????.
    def setUp(self):
        # ??? ??????? User ??? ????? ??? ???? ???? ???? ????? ????.
        User = get_user_model()
        self.customer = User.objects.create_user(
            # ??? ??????? email ??? ????? ??? ???? ???? ???? ????? ????.
            email="student@example.com",
            # ??? ??????? password ??? ????? ??? ???? ???? ???? ????? ????.
            password="StrongPass123",
            # ??? ??????? full_name ??? ????? ??? ???? ???? ???? ????? ????.
            full_name="Student User",
            # ??? ??????? phone_number ??? ????? ??? ???? ???? ???? ????? ????.
            phone_number="0910000001",
        )
        self.cashier = User.objects.create_user(
            # ??? ??????? email ??? ????? ??? ???? ???? ???? ????? ????.
            email="cashier@example.com",
            # ??? ??????? password ??? ????? ??? ???? ???? ???? ????? ????.
            password="StrongPass123",
            # ??? ??????? full_name ??? ????? ??? ???? ???? ???? ????? ????.
            full_name="Cafe Cashier",
            # ??? ??????? phone_number ??? ????? ??? ???? ???? ???? ????? ????.
            phone_number="0910000002",
            # ??? ??????? is_staff ??? ????? ??? ???? ???? ???? ????? ????.
            is_staff=True,
        )
        self.cafe = Cafe.objects.create(
            # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
            name="Main Campus Cafe",
            # ??? ??????? code ??? ????? ??? ???? ???? ???? ????? ????.
            code="main-campus",
            # ??? ??????? owner ??? ????? ??? ???? ???? ???? ????? ????.
            owner=self.cashier,
        )
        self.category = Category.objects.create(cafe=self.cafe, name="Coffee")
        self.product = Product.objects.create(
            # ??? ??????? cafe ??? ????? ??? ???? ???? ???? ????? ????.
            cafe=self.cafe,
            # ??? ??????? category ??? ????? ??? ???? ???? ???? ????? ????.
            category=self.category,
            # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
            name="Espresso",
            # ??? ??????? price ??? ????? ??? ???? ???? ???? ????? ????.
            price=Decimal("5.00"),
            stock_quantity=20,
        )

    # ???? ???? test_create_order_from_app_api ?????? ????? ?????? ?? ????? ????.
    def test_create_order_from_app_api(self):
        self.client.force_login(self.customer)

        # ??? ??????? response ??? ????? ??? ???? ???? ???? ????? ????.
        response = self.client.post(
            reverse("v2_app_orders"),
            # ??? ??????? data ??? ????? ??? ???? ???? ???? ????? ????.
            data={
                "cafe_id": self.cafe.id,
                "payment_method": "CASH",
                "total_price": "10.00",
                "items": [
                    {
                        "product_id": self.product.id,
                        "quantity": 2,
                    }
                ],
            },
            # ??? ??????? content_type ??? ????? ??? ???? ???? ???? ????? ????.
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201, response.content)
        # ??? ??????? order ??? ????? ??? ???? ???? ???? ????? ????.
        order = Order.objects.get()
        self.assertEqual(order.cafe, self.cafe)
        self.assertEqual(order.user, self.customer)
        self.assertEqual(order.status, OrderStatus.PENDING)
        self.assertEqual(order.total_price, Decimal("10.00"))
        self.assertEqual(OrderItem.objects.filter(order=order).count(), 1)

    def test_legacy_create_order_endpoint_marks_deprecation(self):
        self.client.force_login(self.customer)

        response = self.client.post(
            reverse("v2_app_create_order"),
            data={
                "cafe_id": self.cafe.id,
                "payment_method": "CASH",
                "total_price": "5.00",
                "items": [
                    {
                        "product_id": self.product.id,
                        "quantity": 1,
                    }
                ],
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.headers["Deprecation"], "true")
        self.assertIn("/api/v2/app/orders/", response.headers["Link"])
        self.assertEqual(Order.objects.count(), 1)

    # ???? ???? test_cashier_can_change_order_status_from_panel ?????? ????? ?????? ?? ????? ????.
    def test_cashier_can_change_order_status_from_panel(self):
        # ??? ??????? order ??? ????? ??? ???? ???? ???? ????? ????.
        order = create_order(
            # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
            user=self.customer,
            # ??? ??????? cafe_id ??? ????? ??? ???? ???? ???? ????? ????.
            cafe_id=self.cafe.id,
            # ??? ??????? payment_method ??? ????? ??? ???? ???? ???? ????? ????.
            payment_method="CASH",
            # ??? ??????? total_price ??? ????? ??? ???? ???? ???? ????? ????.
            total_price=Decimal("5.00"),
            # ??? ??????? items_data ??? ????? ??? ???? ???? ???? ????? ????.
            items_data=[
                {
                    "product_id": self.product.id,
                    "quantity": 1,
                }
            ],
        )
        self.client.force_login(self.cashier)

        # ??? ??????? response ??? ????? ??? ???? ???? ???? ????? ????.
        response = self.client.post(
            reverse("core:update_order_status_api", args=[order.id]),
            # ??? ??????? data ??? ????? ??? ???? ???? ???? ????? ????.
            data={
                "cafe_id": self.cafe.id,
                "status": "ACCEPTED",
            },
        )

        self.assertEqual(response.status_code, 200, response.content)
        # ??? ??????? payload ??? ????? ??? ???? ???? ???? ????? ????.
        payload = response.json()
        self.assertTrue(payload["success"])
        order.refresh_from_db()
        self.assertEqual(order.status, OrderStatus.ACCEPTED)
        self.assertTrue(
            Notification.objects.filter(
                user=self.customer,
                order=order,
                event_type="ORDER_ACCEPTED",
            ).exists()
        )

        self.client.force_login(self.customer)
        notifications_response = self.client.get(reverse("v2_app_notifications"))
        self.assertEqual(notifications_response.status_code, 200, notifications_response.content)
        self.assertGreaterEqual(notifications_response.json()["unread_count"], 1)

    def test_cashier_can_progress_accepted_order_through_preparing_to_ready(self):
        order = create_order(
            user=self.customer,
            cafe_id=self.cafe.id,
            payment_method="CASH",
            total_price=Decimal("5.00"),
            items_data=[
                {
                    "product_id": self.product.id,
                    "quantity": 1,
                }
            ],
        )
        self.client.force_login(self.cashier)

        accept_response = self.client.post(
            reverse("core:update_order_status_api", args=[order.id]),
            data={"cafe_id": self.cafe.id, "status": "ACCEPTED"},
        )
        self.assertEqual(accept_response.status_code, 200, accept_response.content)

        panel_response = self.client.get(reverse("core:cafe_panel"))
        self.assertEqual(panel_response.status_code, 200)
        self.assertContains(panel_response, f"#{order.order_number}")
        self.assertContains(panel_response, 'data-status="PREPARING"')

        preparing_response = self.client.post(
            reverse("core:update_order_status_api", args=[order.id]),
            data={"cafe_id": self.cafe.id, "status": "PREPARING"},
        )
        self.assertEqual(preparing_response.status_code, 200, preparing_response.content)

        ready_response = self.client.post(
            reverse("core:update_order_status_api", args=[order.id]),
            data={"cafe_id": self.cafe.id, "status": "READY"},
        )
        self.assertEqual(ready_response.status_code, 200, ready_response.content)

        order.refresh_from_db()
        self.assertEqual(order.status, OrderStatus.READY)

    def test_cashier_cannot_change_order_status_for_another_cafe(self):
        User = get_user_model()
        other_cashier = User.objects.create_user(
            email="other-cashier@example.com",
            password="StrongPass123",
            full_name="Other Cafe Cashier",
            phone_number="0910000099",
            is_staff=True,
        )
        other_cafe = Cafe.objects.create(
            name="Other Campus Cafe",
            code="other-campus",
            owner=other_cashier,
        )
        other_category = Category.objects.create(cafe=other_cafe, name="Tea")
        other_product = Product.objects.create(
            cafe=other_cafe,
            category=other_category,
            name="Mint Tea",
            price=Decimal("4.00"),
            stock_quantity=5,
        )
        order = create_order(
            user=self.customer,
            cafe_id=other_cafe.id,
            payment_method="CASH",
            total_price=Decimal("4.00"),
            items_data=[
                {
                    "product_id": other_product.id,
                    "quantity": 1,
                }
            ],
        )
        self.client.force_login(self.cashier)

        response = self.client.post(
            reverse("core:update_order_status_api", args=[order.id]),
            data={
                "cafe_id": other_cafe.id,
                "status": "ACCEPTED",
            },
        )

        self.assertEqual(response.status_code, 400, response.content)
        self.assertFalse(response.json()["success"])
        order.refresh_from_db()
        self.assertEqual(order.status, OrderStatus.PENDING)

    def test_wallet_order_cancel_refunds_student_balance(self):
        wallet = self.customer.wallet
        Transaction.objects.create(
            wallet=wallet,
            amount=Decimal("20.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Test wallet funding",
        )
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal("20.00"))

        order = create_order(
            user=self.customer,
            cafe_id=self.cafe.id,
            payment_method="wallet",
            total_price=Decimal("5.00"),
            items_data=[
                {
                    "product_id": self.product.id,
                    "quantity": 1,
                }
            ],
        )
        wallet.refresh_from_db()
        self.assertEqual(order.payment_method, "WALLET")
        self.assertEqual(wallet.balance, Decimal("15.00"))

        cancelled_order = cancel_user_order(order.id, self.customer)

        wallet.refresh_from_db()
        self.assertEqual(cancelled_order.status, OrderStatus.CANCELLED)
        self.assertEqual(wallet.balance, Decimal("20.00"))
        self.assertTrue(
            wallet.transactions.filter(
                transaction_type="DEPOSIT",
                source="SYSTEM",
                amount=Decimal("5.00"),
                description__contains="Refund for cancelled order",
            ).exists()
        )

    def test_cafe_cancel_wallet_order_refunds_student_balance(self):
        wallet = self.customer.wallet
        Transaction.objects.create(
            wallet=wallet,
            amount=Decimal("20.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Test wallet funding",
        )
        order = create_order(
            user=self.customer,
            cafe_id=self.cafe.id,
            payment_method="WALLET",
            total_price=Decimal("5.00"),
            items_data=[
                {
                    "product_id": self.product.id,
                    "quantity": 1,
                }
            ],
        )
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal("15.00"))
        self.client.force_login(self.cashier)

        response = self.client.post(
            reverse("core:update_order_status_api", args=[order.id]),
            data={"cafe_id": self.cafe.id, "status": "CANCELLED"},
        )

        self.assertEqual(response.status_code, 200, response.content)
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal("20.00"))

    def test_create_order_rejects_unavailable_product_before_wallet_withdrawal(self):
        self.product.is_available = False
        self.product.save(update_fields=["is_available", "updated_at"])

        wallet = self.customer.wallet
        Transaction.objects.create(
            wallet=wallet,
            amount=Decimal("20.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Test wallet funding",
        )
        wallet.refresh_from_db()

        with self.assertRaisesMessage(ValidationServiceError, "Espresso is out of stock."):
            create_order(
                user=self.customer,
                cafe_id=self.cafe.id,
                payment_method="WALLET",
                total_price=Decimal("5.00"),
                items_data=[
                    {
                        "product_id": self.product.id,
                        "quantity": 1,
                    }
                ],
            )

        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal("20.00"))
        self.assertFalse(Order.objects.exists())
        self.assertFalse(wallet.transactions.filter(transaction_type="WITHDRAWAL").exists())

    def test_create_order_decrements_stock_and_marks_product_unavailable_at_zero(self):
        order = create_order(
            user=self.customer,
            cafe_id=self.cafe.id,
            payment_method="CASH",
            total_price=Decimal("100.00"),
            items_data=[
                {
                    "product_id": self.product.id,
                    "quantity": 20,
                }
            ],
        )

        self.assertEqual(order.total_price, Decimal("100.00"))
        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, 0)
        self.assertFalse(self.product.is_available)

        response = self.client.get(reverse("v2_app_products"), data={"cafe_id": self.cafe.id})
        self.assertEqual(response.status_code, 200, response.content)
        product_payload = next(item for item in response.json() if item["id"] == self.product.id)
        self.assertFalse(product_payload["is_available"])
        self.assertEqual(product_payload["stock_quantity"], 0)

    def test_create_order_rejects_quantity_above_available_stock(self):
        with self.assertRaisesMessage(ValidationServiceError, "Only 20 items left for Espresso."):
            create_order(
                user=self.customer,
                cafe_id=self.cafe.id,
                payment_method="CASH",
                total_price=Decimal("105.00"),
                items_data=[
                    {
                        "product_id": self.product.id,
                        "quantity": 21,
                    }
                ],
            )

        self.product.refresh_from_db()
        self.assertEqual(self.product.stock_quantity, 20)
        self.assertFalse(Order.objects.exists())

    def test_toggle_product_stock_invalidates_cached_product_list(self):
        cached_products = get_products_cached(self.cafe.id)
        self.assertEqual(len(cached_products), 1)
        self.assertTrue(cached_products[0].is_available)

        toggle_product_stock(
            cafe_id=self.cafe.id,
            product_id=self.product.id,
            is_available=False,
            user=self.cashier,
        )

        refreshed_products = get_products_cached(self.cafe.id)
        self.assertEqual(len(refreshed_products), 1)
        self.assertFalse(refreshed_products[0].is_in_stock)

    def test_cafe_panel_creates_product_with_image_discount_and_app_order_uses_current_price(self):
        self.client.force_login(self.cashier)
        image = SimpleUploadedFile(
            "latte.jpg",
            b"GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;",
            content_type="image/gif",
        )

        create_response = self.client.post(
            reverse("core:create_product_api"),
            data={
                "cafe_id": self.cafe.id,
                "name": "Discount Latte",
                "category": self.category.id,
                "price": "8.00",
                "original_price": "10.00",
                "description": "Morning offer",
                "image": image,
                "stock_quantity": "10",
                "is_available": "on",
            },
        )

        self.assertEqual(create_response.status_code, 200, create_response.content)
        product = Product.objects.get(name="Discount Latte")
        self.assertEqual(product.price, Decimal("8.00"))
        self.assertEqual(product.original_price, Decimal("10.00"))
        self.assertTrue(product.has_discount)
        self.assertEqual(product.discount_percentage, 20)
        self.assertTrue(product.image.name.startswith("products/"))
        self.assertEqual(product.stock_quantity, 10)

        products_response = self.client.get(
            reverse("v2_app_products"),
            data={"cafe_id": self.cafe.id},
        )
        self.assertEqual(products_response.status_code, 200, products_response.content)
        payload = products_response.json()
        created_payload = next(item for item in payload if item["id"] == product.id)
        self.assertEqual(created_payload["price"], "8.00")
        self.assertEqual(created_payload["original_price"], "10.00")
        self.assertTrue(created_payload["has_discount"])
        self.assertEqual(created_payload["discount_percentage"], 20)
        self.assertEqual(created_payload["stock_quantity"], 10)
        self.assertTrue(created_payload["is_available"])
        self.assertIn("/media/products/", created_payload["image_url"])

        self.client.force_login(self.customer)
        order_response = self.client.post(
            reverse("v2_app_orders"),
            data={
                "cafe_id": self.cafe.id,
                "payment_method": "CASH",
                "total_price": "16.00",
                "items": [
                    {
                        "product_id": product.id,
                        "quantity": 2,
                    }
                ],
            },
            content_type="application/json",
        )
        self.assertEqual(order_response.status_code, 201, order_response.content)
        order_payload = order_response.json()["order"]
        self.assertIn(
            "http://testserver/media/products/",
            order_payload["items"][0]["product_image"],
        )
        order = Order.objects.latest("id")
        self.assertEqual(order.total_price, Decimal("16.00"))
        self.assertEqual(order.items.get().price, Decimal("8.00"))
        product.refresh_from_db()
        self.assertEqual(product.stock_quantity, 8)

        orders_response = self.client.get(reverse("v2_app_orders"))
        self.assertEqual(orders_response.status_code, 200, orders_response.content)
        self.assertIn(
            "http://testserver/media/products/",
            orders_response.json()[0]["items"][0]["product_image"],
        )


# ???? ???? DashboardRenderSmokeTests ???? ?????? ????????? ???? ???? ?????.
class DashboardRenderSmokeTests(TestCase):
    # ???? ???? setUp ?????? ????? ?????? ?? ????? ????.
    def setUp(self):
        # ??? ??????? User ??? ????? ??? ???? ???? ???? ????? ????.
        User = get_user_model()
        self.superuser = User.objects.create_superuser(
            # ??? ??????? email ??? ????? ??? ???? ???? ???? ????? ????.
            email="admin@example.com",
            # ??? ??????? password ??? ????? ??? ???? ???? ???? ????? ????.
            password="StrongPass123",
            # ??? ??????? full_name ??? ????? ??? ???? ???? ???? ????? ????.
            full_name="System Admin",
            # ??? ??????? phone_number ??? ????? ??? ???? ???? ???? ????? ????.
            phone_number="0910000003",
        )
        self.cashier = User.objects.create_user(
            # ??? ??????? email ??? ????? ??? ???? ???? ???? ????? ????.
            email="panel-cashier@example.com",
            # ??? ??????? password ??? ????? ??? ???? ???? ???? ????? ????.
            password="StrongPass123",
            # ??? ??????? full_name ??? ????? ??? ???? ???? ???? ????? ????.
            full_name="Panel Cashier",
            # ??? ??????? phone_number ??? ????? ??? ???? ???? ???? ????? ????.
            phone_number="0910000004",
            # ??? ??????? is_staff ??? ????? ??? ???? ???? ???? ????? ????.
            is_staff=True,
        )
        self.cafe = Cafe.objects.create(
            # ??? ??????? name ??? ????? ??? ???? ???? ???? ????? ????.
            name="Panel Cafe",
            # ??? ??????? code ??? ????? ??? ???? ???? ???? ????? ????.
            code="panel-cafe",
            # ??? ??????? owner ??? ????? ??? ???? ???? ???? ????? ????.
            owner=self.cashier,
        )
        self.student = User.objects.create_user(
            email="student-panel@example.com",
            password="StrongPass123",
            full_name="Panel Student",
            phone_number="0910000014",
        )

    # ???? ???? test_super_admin_dashboard_renders_polished_controls ?????? ????? ?????? ?? ????? ????.
    def test_super_admin_dashboard_renders_polished_controls(self):
        category = Category.objects.create(cafe=self.cafe, name="Coffee")
        product = Product.objects.create(
            cafe=self.cafe,
            category=category,
            name="Latte",
            price=Decimal("7.00"),
            stock_quantity=5,
        )
        create_order(
            user=self.student,
            cafe_id=self.cafe.id,
            payment_method="CASH",
            total_price=Decimal("35.00"),
            items_data=[
                {
                    "product_id": product.id,
                    "quantity": 5,
                }
            ],
        )
        self.client.force_login(self.superuser)

        # ??? ??????? response ??? ????? ??? ???? ???? ???? ????? ????.
        response = self.client.get(reverse("core:super_admin_dashboard"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "confirmCafeToggleModal")
        self.assertContains(response, "js-toggle-cafe-form")
        self.assertContains(response, reverse("core:cafe_login_for_code", args=[self.cafe.code]))
        self.assertContains(response, "الأصناف المباعة")
        self.assertContains(response, "<td>5</td>", html=True)
        self.assertNotContains(response, reverse("core:cafe_panel"))

    def test_super_admin_cannot_open_cafe_operator_panel(self):
        self.client.force_login(self.superuser)

        response = self.client.get(reverse("core:cafe_panel"), follow=True)

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "confirmCafeToggleModal")
        self.assertNotContains(response, "confirmCafePanelActionModal")

    def test_super_admin_opening_cafe_login_link_sees_cafe_login(self):
        self.client.force_login(self.superuser)

        response = self.client.get(reverse("core:cafe_login_for_code", args=[self.cafe.code]))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "بوابة المقهى")
        self.assertContains(response, self.cafe.name)
        self.assertNotContains(response, "confirmCafeToggleModal")
        self.assertNotIn("_auth_user_id", self.client.session)

    # ???? ???? test_cafe_panel_renders_confirmation_modal ?????? ????? ?????? ?? ????? ????.
    def test_cafe_panel_renders_confirmation_modal(self):
        self.client.force_login(self.cashier)

        # ??? ??????? response ??? ????? ??? ???? ???? ???? ????? ????.
        response = self.client.get(reverse("core:cafe_panel"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "confirmCafePanelActionModal")
        self.assertContains(response, "محطة المحافظ والدفع")
        self.assertContains(response, "تعريف بطاقات NFC")

    def test_cafe_operator_can_deposit_and_withdraw_student_wallet(self):
        self.client.force_login(self.cashier)

        deposit_response = self.client.post(
            reverse("core:cafe_wallet_operation_api"),
            data={"identifier": self.student.email, "operation": "DEPOSIT", "amount": "25.50"},
        )
        self.assertEqual(deposit_response.status_code, 200, deposit_response.content)
        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("25.50"))

        withdraw_response = self.client.post(
            reverse("core:cafe_wallet_operation_api"),
            data={"identifier": self.student.email, "operation": "WITHDRAWAL", "amount": "5.50"},
        )
        self.assertEqual(withdraw_response.status_code, 200, withdraw_response.content)
        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("20.00"))

    def test_cafe_wallet_operation_requires_existing_wallet_code(self):
        self.client.force_login(self.cashier)

        response = self.client.post(
            reverse("core:cafe_wallet_operation_api"),
            data={"identifier": "MISSING-CARD", "operation": "DEPOSIT", "amount": "10.00"},
        )

        self.assertEqual(response.status_code, 404, response.content)
        self.assertFalse(Transaction.objects.filter(amount=Decimal("10.00")).exists())

    def test_cafe_operator_can_bind_nfc_card_code_to_wallet(self):
        self.client.force_login(self.cashier)

        response = self.client.post(
            reverse("core:cafe_bind_wallet_card_api"),
            data={"identifier": self.student.email, "card_code": "CARD-001"},
        )

        self.assertEqual(response.status_code, 200, response.content)
        wallet = Wallet.objects.get(user=self.student)
        self.assertEqual(wallet.link_code, "CARD-001")

    def test_cafe_panel_snapshot_returns_current_live_orders(self):
        category = Category.objects.create(cafe=self.cafe, name="Coffee")
        product = Product.objects.create(
            cafe=self.cafe,
            category=category,
            name="Latte",
            price=Decimal("7.00"),
            stock_quantity=4,
        )
        order = create_order(
            user=self.superuser,
            cafe_id=self.cafe.id,
            payment_method="CASH",
            total_price=Decimal("7.00"),
            items_data=[
                {
                    "product_id": product.id,
                    "quantity": 1,
                }
            ],
        )
        self.client.force_login(self.cashier)

        response = self.client.get(
            reverse("core:cafe_panel_snapshot_api"),
            data={"cafe_id": self.cafe.id},
        )

        self.assertEqual(response.status_code, 200, response.content)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertEqual(payload["cafe_id"], self.cafe.id)
        self.assertEqual(len(payload["orders"]), 1)
        self.assertEqual(payload["orders"][0]["id"], order.id)

    @override_settings(DEBUG=True)
    def test_dev_passwordless_super_admin_login_opens_dashboard(self):
        response = self.client.post(
            reverse("core:login"),
            data={"dev_role": "super_admin"},
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "confirmCafeToggleModal")

    @override_settings(DEBUG=True)
    def test_dev_passwordless_cafe_login_opens_panel(self):
        response = self.client.post(
            reverse("core:cafe_login"),
            data={"dev_role": "cafe"},
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "confirmCafePanelActionModal")

    def test_role_specific_login_pages_render_distinct_actions(self):
        admin_response = self.client.get(reverse("core:admin_login"))
        cafe_response = self.client.get(reverse("core:cafe_login_for_code", args=[self.cafe.code]))

        self.assertEqual(admin_response.status_code, 200)
        self.assertEqual(cafe_response.status_code, 200)
        self.assertContains(admin_response, reverse("core:admin_login"))
        self.assertContains(cafe_response, reverse("core:cafe_login_for_code", args=[self.cafe.code]))
