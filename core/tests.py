from decimal import Decimal
from io import StringIO
from pathlib import Path
from tempfile import TemporaryDirectory

from django.conf import settings
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


class AppLoginApiTests(TestCase):
    def test_student_can_login_with_email_identifier(self):
        user = get_user_model().objects.create_user(
            email="student-login@example.com",
            password="StrongPass123",
            full_name="Student Login",
            phone_number="0912345601",
        )

        response = self.client.post(
            reverse("v2_app_login"),
            data={
                "identifier": "STUDENT-LOGIN@example.com",
                "password": "StrongPass123",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.json()["user"]["id"], user.id)
        self.assertTrue(response.json()["access"])

    def test_signup_rejects_duplicate_email_cleanly(self):
        get_user_model().objects.create_user(
            email="duplicate@example.com",
            password="StrongPass123",
            full_name="Existing Student",
            phone_number="0912345602",
        )

        response = self.client.post(
            reverse("v2_app_signup"),
            data={
                "full_name": "New Student",
                "email": "DUPLICATE@example.com",
                "phone_number": "0912345603",
                "password": "StrongPass123",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400, response.content)
        self.assertEqual(response.json()["error"], "Email is already registered.")

    @override_settings(
        DEBUG=True,
        BREVO_API_KEY="",
        BREVO_DEBUG_EMAIL_CODES=True,
    )
    def test_student_can_login_with_email_verification_code(self):
        user = get_user_model().objects.create_user(
            email="email-code@example.com",
            password="StrongPass123",
            full_name="Email Code Student",
            phone_number="0912345691",
        )

        request_response = self.client.post(
            reverse("v2_app_email_code_request"),
            data={"email": "EMAIL-CODE@example.com"},
            content_type="application/json",
        )

        self.assertEqual(request_response.status_code, 200, request_response.content)
        challenge = request_response.json()
        self.assertEqual(len(challenge["debug_code"]), 6)
        self.assertNotIn("email-code", challenge["masked_email"])

        verify_response = self.client.post(
            reverse("v2_app_email_code_verify"),
            data={
                "email": "email-code@example.com",
                "request_id": challenge["request_id"],
                "code": challenge["debug_code"],
            },
            content_type="application/json",
        )

        self.assertEqual(verify_response.status_code, 200, verify_response.content)
        self.assertEqual(verify_response.json()["user"]["id"], user.id)
        self.assertTrue(verify_response.json()["access"])

    @override_settings(
        DEBUG=True,
        BREVO_API_KEY="",
        BREVO_DEBUG_EMAIL_CODES=True,
    )
    def test_email_verification_code_cannot_be_reused(self):
        get_user_model().objects.create_user(
            email="single-use-code@example.com",
            password="StrongPass123",
            full_name="Single Use Student",
            phone_number="0912345692",
        )
        challenge = self.client.post(
            reverse("v2_app_email_code_request"),
            data={"email": "single-use-code@example.com"},
            content_type="application/json",
        ).json()
        payload = {
            "email": "single-use-code@example.com",
            "request_id": challenge["request_id"],
            "code": challenge["debug_code"],
        }

        first_response = self.client.post(
            reverse("v2_app_email_code_verify"),
            data=payload,
            content_type="application/json",
        )
        second_response = self.client.post(
            reverse("v2_app_email_code_verify"),
            data=payload,
            content_type="application/json",
        )

        self.assertEqual(first_response.status_code, 200)
        self.assertEqual(second_response.status_code, 400)

    @override_settings(
        DEBUG=True,
        BREVO_API_KEY="",
        BREVO_DEBUG_EMAIL_CODES=True,
    )
    def test_signup_creates_account_only_after_email_verification(self):
        signup_response = self.client.post(
            reverse("v2_app_signup"),
            data={
                "full_name": "Verified Student",
                "email": "verified-signup@example.com",
                "phone_number": "0912345693",
                "password": "StrongPass123",
            },
            content_type="application/json",
        )

        self.assertEqual(signup_response.status_code, 202, signup_response.content)
        self.assertFalse(
            get_user_model().objects.filter(
                email="verified-signup@example.com"
            ).exists()
        )
        challenge = signup_response.json()

        verify_response = self.client.post(
            reverse("v2_app_signup_verify"),
            data={
                "email": "verified-signup@example.com",
                "request_id": challenge["request_id"],
                "code": challenge["debug_code"],
            },
            content_type="application/json",
        )

        self.assertEqual(verify_response.status_code, 201, verify_response.content)
        user = get_user_model().objects.get(email="verified-signup@example.com")
        self.assertTrue(user.check_password("StrongPass123"))
        self.assertTrue(hasattr(user, "wallet"))
        self.assertTrue(verify_response.json()["access"])

    @override_settings(
        DEBUG=True,
        BREVO_API_KEY="",
        BREVO_DEBUG_EMAIL_CODES=True,
    )
    def test_signup_rejects_invalid_verification_code(self):
        challenge = self.client.post(
            reverse("v2_app_signup"),
            data={
                "full_name": "Unverified Student",
                "email": "unverified-signup@example.com",
                "phone_number": "0912345694",
                "password": "StrongPass123",
            },
            content_type="application/json",
        ).json()

        verify_response = self.client.post(
            reverse("v2_app_signup_verify"),
            data={
                "email": "unverified-signup@example.com",
                "request_id": challenge["request_id"],
                "code": "000000",
            },
            content_type="application/json",
        )

        self.assertEqual(verify_response.status_code, 400)
        self.assertFalse(
            get_user_model().objects.filter(
                email="unverified-signup@example.com"
            ).exists()
        )


class SuperAdminCafeIdentityTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.superuser = User.objects.create_superuser(
            email="root-cafe-identity@example.com",
            password="StrongPass123",
            full_name="Root Admin",
            phone_number="0912345604",
        )
        self.manager = User.objects.create_user(
            email="manager-cafe-identity@example.com",
            password="CafePass2026",
            full_name="Cafe Manager",
            phone_number="0912345605",
            is_staff=True,
        )
        self.cafe = provision_cafe(
            name="Identity Cafe",
            code="identity-cafe",
            owner_id=self.manager.id,
        )

    def test_super_admin_uploads_image_and_app_api_returns_absolute_url(self):
        self.client.force_login(self.superuser)
        image = SimpleUploadedFile(
            "cafe.gif",
            b"GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!"
            b"\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01"
            b"\x00\x00\x02\x02D\x01\x00;",
            content_type="image/gif",
        )

        with TemporaryDirectory() as media_root, override_settings(MEDIA_ROOT=media_root):
            response = self.client.post(
                reverse("core:update_cafe_image_from_dashboard", args=[self.cafe.id]),
                data={"image": image},
                follow=True,
            )

            self.assertEqual(response.status_code, 200)
            self.cafe.refresh_from_db()
            self.assertTrue(self.cafe.image.name.startswith("cafes/"))
            self.assertContains(response, self.cafe.image.url)

            api_response = self.client.get(reverse("v2_app_cafes"))
            payload = next(item for item in api_response.json() if item["id"] == self.cafe.id)
            self.assertIn("http://testserver/media/cafes/", payload["image"])

    def test_super_admin_suspends_cafe_and_hides_it_from_app(self):
        self.client.force_login(self.superuser)
        response = self.client.post(
            reverse("core:toggle_cafe_status_from_dashboard", args=[self.cafe.id]),
            data={
                "action": "suspend",
                "suspension_reason": "Subscription overdue",
            },
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        self.cafe.refresh_from_db()
        self.assertFalse(self.cafe.is_active)
        self.assertEqual(self.cafe.suspension_reason, "Subscription overdue")
        self.assertIsNotNone(self.cafe.suspended_at)

        self.client.logout()
        api_response = self.client.get(reverse("v2_app_cafes"))
        self.assertNotIn(self.cafe.id, [item["id"] for item in api_response.json()])

        self.client.force_login(self.manager)
        blocked_response = self.client.get(reverse("core:route_after_login"), follow=True)
        self.assertEqual(blocked_response.status_code, 200)
        self.assertNotIn("_auth_user_id", self.client.session)

    def test_password_reset_recreates_missing_operator(self):
        self.cafe.owner = None
        self.cafe.save(update_fields=["owner", "updated_at"])
        self.client.force_login(self.superuser)

        response = self.client.post(
            reverse("core:reset_cafe_password_from_dashboard", args=[self.cafe.id]),
            data={"manager_password": "NewCafePass2026"},
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        self.cafe.refresh_from_db()
        self.assertIsNotNone(self.cafe.owner)
        self.assertTrue(self.cafe.owner.check_password("NewCafePass2026"))

    def test_password_reset_form_contains_csrf_and_refreshes_token_before_submit(self):
        self.client.force_login(self.superuser)

        response = self.client.get(reverse("core:super_admin_dashboard"))

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'id="resetCafePasswordForm"')
        self.assertContains(response, 'name="csrfmiddlewaretoken"')
        javascript = (
            Path(settings.BASE_DIR)
            / "static"
            / "admin_v2"
            / "super_admin_dashboard.js"
        ).read_text(encoding="utf-8")
        self.assertIn(
            'resetCafePasswordForm?.addEventListener("submit"',
            javascript,
        )
        self.assertIn("submitWithFreshCsrf(resetCafePasswordForm)", javascript)


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

    def test_super_admin_creates_cafe_login_password_from_dashboard(self):
        User = get_user_model()
        superuser = User.objects.create_superuser(
            email="root-password@example.com",
            password="StrongPass123",
            full_name="Root Admin",
            phone_number="0911000020",
        )
        self.client.force_login(superuser)

        response = self.client.post(
            reverse("core:create_cafe_from_dashboard"),
            data={
                "faculty_name": "كلية تقنية المعلومات",
                "manager_password": "CafePass@2026",
            },
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        cafe = Cafe.objects.get(faculty__name="كلية تقنية المعلومات")
        self.assertEqual(cafe.name, "مقهى كلية تقنية المعلومات")
        self.assertIsNotNone(cafe.owner)
        self.assertTrue(cafe.owner.check_password("CafePass@2026"))
        self.assertTrue(cafe.owner.groups.filter(name=CAFE_OWNER_GROUP_NAME).exists())

        self.client.logout()
        login_response = self.client.post(
            reverse("core:cafe_login"),
            data={"cafe_id": cafe.id, "password": "CafePass@2026"},
            follow=True,
        )
        self.assertEqual(login_response.status_code, 200)
        self.assertContains(login_response, "confirmCafePanelActionModal")

    def test_super_admin_can_reset_cafe_password_from_dashboard(self):
        User = get_user_model()
        superuser = User.objects.create_superuser(
            email="root-reset@example.com",
            password="StrongPass123",
            full_name="Root Admin",
            phone_number="0911000021",
        )
        manager = User.objects.create_user(
            email="reset-manager@example.com",
            password="OldCafePass1",
            full_name="Reset Manager",
            phone_number="0911000022",
            is_staff=True,
        )
        cafe = provision_cafe(name="Reset Cafe", code="reset-cafe", owner_id=manager.id)
        self.client.force_login(superuser)

        response = self.client.post(
            reverse("core:reset_cafe_password_from_dashboard", args=[cafe.id]),
            data={"manager_password": "NewCafePass2026"},
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        manager.refresh_from_db()
        self.assertTrue(manager.check_password("NewCafePass2026"))

        self.client.logout()
        login_response = self.client.post(
            reverse("core:cafe_login"),
            data={"cafe_id": cafe.id, "password": "NewCafePass2026"},
            follow=True,
        )
        self.assertEqual(login_response.status_code, 200)
        self.assertContains(login_response, "confirmCafePanelActionModal")

    def test_cafe_login_accepts_reset_password_pasted_with_outer_whitespace(self):
        User = get_user_model()
        superuser = User.objects.create_superuser(
            email="root-copy-password@example.com",
            password="StrongPass123",
            full_name="Root Admin",
            phone_number="0911000023",
        )
        manager = User.objects.create_user(
            email="copy-password-manager@example.com",
            password="OldCafePass1",
            full_name="Copy Password Manager",
            phone_number="0911000024",
            is_staff=True,
        )
        cafe = provision_cafe(name="Copy Password Cafe", code="copy-password-cafe", owner_id=manager.id)
        self.client.force_login(superuser)
        self.client.post(
            reverse("core:reset_cafe_password_from_dashboard", args=[cafe.id]),
            data={"manager_password": "NewCafePass2026"},
        )

        self.client.logout()
        login_response = self.client.post(
            reverse("core:cafe_login"),
            data={"cafe_id": cafe.id, "password": "  NewCafePass2026  "},
            follow=True,
        )

        self.assertEqual(login_response.status_code, 200)
        self.assertContains(login_response, "confirmCafePanelActionModal")

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
                "order_note": "البرغر بدون لحم",
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
        self.assertEqual(order.notes, "البرغر بدون لحم")
        self.assertRegex(order.order_number, r"^BH-\d{6}$")
        self.assertEqual(
            response.json()["order"]["notes"],
            "البرغر بدون لحم",
        )
        self.assertEqual(OrderItem.objects.filter(order=order).count(), 1)

        self.client.force_login(self.cashier)
        panel_response = self.client.get(reverse("core:cafe_panel"))
        self.assertContains(panel_response, "البرغر بدون لحم")
        self.assertContains(panel_response, order.display_order_number)

    def test_removed_legacy_order_endpoint_returns_not_found(self):
        self.client.force_login(self.customer)

        response = self.client.post(
            "/api/v2/app/orders/create/",
            data={"cafe_id": self.cafe.id, "items": []},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 404)

    def test_create_order_with_linked_nfc_card_withdraws_wallet_balance(self):
        wallet = Wallet.objects.get(user=self.customer)
        wallet.nfc_card_uid = "NFC-A1B2C3D4"
        wallet.save(update_fields=["nfc_card_uid", "updated_at"])
        Transaction.objects.create(
            wallet=wallet,
            amount=Decimal("20.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Test top-up",
        )
        self.client.force_login(self.customer)

        response = self.client.post(
            reverse("v2_app_orders"),
            data={
                "cafe_id": self.cafe.id,
                "payment_method": "NFC",
                "nfc_card_uid": "nfc-a1b2c3d4",
                "total_price": "10.00",
                "items": [{"product_id": self.product.id, "quantity": 2}],
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201, response.content)
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal("10.00"))
        self.assertEqual(Order.objects.get().payment_method, "NFC")
        self.assertTrue(
            wallet.transactions.filter(
                transaction_type="WITHDRAWAL",
                source="NFC",
                amount=Decimal("10.00"),
                cafe=self.cafe,
            ).exists()
        )

    def test_create_order_rejects_nfc_card_owned_by_another_wallet(self):
        wallet = Wallet.objects.get(user=self.customer)
        wallet.nfc_card_uid = "NFC-OWN-CARD"
        wallet.save(update_fields=["nfc_card_uid", "updated_at"])
        Transaction.objects.create(
            wallet=wallet,
            amount=Decimal("20.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
        )
        self.client.force_login(self.customer)

        response = self.client.post(
            reverse("v2_app_orders"),
            data={
                "cafe_id": self.cafe.id,
                "payment_method": "NFC",
                "nfc_card_uid": "NFC-OTHER-CARD",
                "total_price": "5.00",
                "items": [{"product_id": self.product.id, "quantity": 1}],
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400, response.content)
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal("20.00"))
        self.assertFalse(Order.objects.exists())
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
class NfcWalletApiTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.sender = User.objects.create_user(
            email="nfc-sender@example.com",
            password="StrongPass123",
            full_name="NFC Sender",
            phone_number="0910000031",
        )
        self.recipient = User.objects.create_user(
            email="nfc-recipient@example.com",
            password="StrongPass123",
            full_name="NFC Recipient",
            phone_number="0910000032",
        )
        Transaction.objects.create(
            wallet=self.sender.wallet,
            amount=Decimal("100.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
        )

    def test_link_lookup_and_transfer_to_nfc_card(self):
        self.client.force_login(self.recipient)
        link_response = self.client.post(
            reverse("link_nfc_card"),
            data={"card_uid": "nfc-deadbeef"},
            content_type="application/json",
        )
        self.assertEqual(link_response.status_code, 200, link_response.content)

        self.client.force_login(self.sender)
        lookup_response = self.client.post(
            reverse("lookup_nfc_card"),
            data={"card_uid": "NFC-DEADBEEF"},
            content_type="application/json",
        )
        self.assertEqual(lookup_response.status_code, 200, lookup_response.content)
        self.assertEqual(
            lookup_response.json()["card"]["student_name"],
            self.recipient.full_name,
        )
        self.assertNotIn("balance", lookup_response.json()["card"])

        transfer_response = self.client.post(
            reverse("transfer_to_nfc_card"),
            data={
                "card_uid": "NFC-DEADBEEF",
                "amount": "25.00",
                "note": "Card transfer",
            },
            content_type="application/json",
        )
        self.assertEqual(transfer_response.status_code, 200, transfer_response.content)
        self.sender.wallet.refresh_from_db()
        self.recipient.wallet.refresh_from_db()
        self.assertEqual(self.sender.wallet.balance, Decimal("75.00"))
        self.assertEqual(self.recipient.wallet.balance, Decimal("25.00"))
        self.assertTrue(
            self.recipient.wallet.transactions.filter(source="NFC").exists()
        )

    def test_card_cannot_be_linked_to_two_students(self):
        self.client.force_login(self.recipient)
        self.client.post(
            reverse("link_nfc_card"),
            data={"card_uid": "NFC-UNIQUE01"},
            content_type="application/json",
        )
        self.client.force_login(self.sender)

        response = self.client.post(
            reverse("link_nfc_card"),
            data={"card_uid": "NFC-UNIQUE01"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 409, response.content)


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
        self.assertContains(response, "دخول المقاهي")
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
        self.assertEqual(
            set(
                self.student.wallet.transactions.values_list("cafe_id", flat=True)
            ),
            {self.cafe.id},
        )

    def test_wallet_ledger_is_scoped_to_cafe_and_shows_student_once(self):
        User = get_user_model()
        other_cashier = User.objects.create_user(
            email="other-panel-cashier@example.com",
            password="StrongPass123",
            full_name="Other Cafe Cashier",
            phone_number="0910000024",
            is_staff=True,
        )
        other_cafe = Cafe.objects.create(
            name="Other Faculty Cafe",
            code="other-faculty-cafe",
            owner=other_cashier,
        )
        Transaction.objects.create(
            wallet=self.student.wallet,
            cafe=self.cafe,
            amount=Decimal("30.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Panel Cafe deposit",
        )
        Transaction.objects.create(
            wallet=self.student.wallet,
            cafe=self.cafe,
            amount=Decimal("5.00"),
            transaction_type="WITHDRAWAL",
            source="SYSTEM",
            description="Panel Cafe latest purchase",
        )
        Transaction.objects.create(
            wallet=self.student.wallet,
            cafe=other_cafe,
            amount=Decimal("3.00"),
            transaction_type="WITHDRAWAL",
            source="SYSTEM",
            description="Other Faculty purchase",
        )
        self.client.force_login(self.cashier)

        response = self.client.get(reverse("core:cafe_panel"))

        self.assertEqual(response.status_code, 200)
        activity = response.context["recent_wallet_activity"]
        self.assertEqual(len(activity), 1)
        self.assertEqual(activity[0].description, "Panel Cafe latest purchase")
        self.assertContains(response, "Panel Cafe latest purchase")
        self.assertNotContains(response, "Other Faculty purchase")

    def test_wallet_history_api_returns_only_current_cafe_transactions(self):
        User = get_user_model()
        other_cashier = User.objects.create_user(
            email="history-other-cashier@example.com",
            password="StrongPass123",
            full_name="History Other Cashier",
            phone_number="0910000025",
            is_staff=True,
        )
        other_cafe = Cafe.objects.create(
            name="History Other Cafe",
            code="history-other-cafe",
            owner=other_cashier,
        )
        Transaction.objects.create(
            wallet=self.student.wallet,
            cafe=self.cafe,
            amount=Decimal("12.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Visible cafe operation",
        )
        Transaction.objects.create(
            wallet=self.student.wallet,
            cafe=other_cafe,
            amount=Decimal("2.00"),
            transaction_type="WITHDRAWAL",
            source="SYSTEM",
            description="Hidden cafe operation",
        )
        self.client.force_login(self.cashier)

        response = self.client.get(
            reverse(
                "core:cafe_wallet_history_api",
                args=[self.student.wallet.id],
            )
        )

        self.assertEqual(response.status_code, 200, response.content)
        payload = response.json()
        self.assertEqual(payload["student"]["name"], self.student.full_name)
        self.assertEqual(len(payload["transactions"]), 1)
        self.assertEqual(
            payload["transactions"][0]["description"],
            "Visible cafe operation",
        )

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
        self.assertEqual(wallet.nfc_card_uid, "CARD-001")

        deposit_response = self.client.post(
            reverse("core:cafe_wallet_operation_api"),
            data={"identifier": "CARD-001", "operation": "DEPOSIT", "amount": "10.00"},
        )
        self.assertEqual(deposit_response.status_code, 200, deposit_response.content)
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal("10.00"))

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

    @override_settings(BACKOFFICE_SUPER_ADMIN_EMAIL="admin@example.com")
    def test_super_admin_password_only_login_opens_dashboard(self):
        response = self.client.post(
            reverse("core:login"),
            data={"password": "StrongPass123"},
            follow=True,
        )

        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "confirmCafeToggleModal")

    def test_cafe_login_uses_cafe_selection_and_password(self):
        response = self.client.post(
            reverse("core:cafe_login"),
            data={"cafe_id": self.cafe.id, "password": "StrongPass123"},
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
        self.assertNotContains(admin_response, "دخول تجريبي")
        self.assertNotContains(cafe_response, "دخول تجريبي")
        self.assertNotContains(admin_response, 'name="username"')
        self.assertContains(cafe_response, 'name="cafe_id"')
