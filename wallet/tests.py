from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse

from wallet.models import Transaction


class WalletTopupPermissionTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.student = User.objects.create_user(
            email="wallet-student@example.com",
            password="StrongPass123",
            full_name="Wallet Student",
            phone_number="0910000010",
        )
        self.admin = User.objects.create_user(
            email="wallet-admin@example.com",
            password="StrongPass123",
            full_name="Wallet Admin",
            phone_number="0910000011",
            is_staff=True,
        )
        self.receiver = User.objects.create_user(
            email="wallet-receiver@example.com",
            password="StrongPass123",
            full_name="Wallet Receiver",
            phone_number="0910000012",
        )
        self.url = reverse("topup_wallet")

    def test_regular_user_cannot_topup_wallet(self):
        with override_settings(WALLET_APP_TOPUP_ENABLED=False):
            self.client.force_login(self.student)

            response = self.client.post(self.url, data={"amount": "10.00"})

        self.assertEqual(response.status_code, 403)
        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("0.00"))

    def test_staff_user_can_topup_wallet(self):
        self.client.force_login(self.admin)

        response = self.client.post(self.url, data={"amount": "10.00"})

        self.assertEqual(response.status_code, 200, response.content)
        self.admin.wallet.refresh_from_db()
        self.assertEqual(self.admin.wallet.balance, Decimal("10.00"))

    @override_settings(WALLET_APP_TOPUP_ENABLED=True)
    def test_regular_user_can_topup_wallet_when_app_topup_is_enabled(self):
        self.client.force_login(self.student)

        response = self.client.post(self.url, data={"amount": "10.00"})

        self.assertEqual(response.status_code, 200, response.content)
        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("10.00"))

    def test_user_save_does_not_overwrite_existing_wallet_balance(self):
        Transaction.objects.create(
            wallet=self.student.wallet,
            amount=Decimal("12.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Test funding",
        )

        self.student.full_name = "Wallet Student Updated"
        self.student.save(update_fields=["full_name"])

        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("12.00"))

    def test_regular_user_cannot_withdraw_more_than_balance(self):
        self.client.force_login(self.student)

        response = self.client.post(
            reverse("withdraw_wallet"),
            data={"amount": "10.00"},
        )

        self.assertEqual(response.status_code, 400)
        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("0.00"))

    def test_regular_user_can_transfer_to_another_wallet(self):
        Transaction.objects.create(
            wallet=self.student.wallet,
            amount=Decimal("12.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Test funding",
        )
        self.client.force_login(self.student)

        response = self.client.post(
            reverse("transfer_wallet"),
            data={
                "wallet_code": self.receiver.wallet.link_code,
                "amount": "5.00",
            },
        )

        self.assertEqual(response.status_code, 200, response.content)
        self.student.wallet.refresh_from_db()
        self.receiver.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("7.00"))
        self.assertEqual(self.receiver.wallet.balance, Decimal("5.00"))

    def test_wallet_link_codes_are_generated_as_short_numeric_codes(self):
        self.student.wallet.refresh_from_db()
        self.assertRegex(self.student.wallet.link_code, r"^\d{5}$")

    def test_transfer_rejects_malformed_wallet_code(self):
        Transaction.objects.create(
            wallet=self.student.wallet,
            amount=Decimal("12.00"),
            transaction_type="DEPOSIT",
            source="SYSTEM",
            description="Test funding",
        )
        self.client.force_login(self.student)

        response = self.client.post(
            reverse("transfer_wallet"),
            data={
                "wallet_code": "ABC' OR 1=1 --",
                "amount": "5.00",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.receiver.wallet.refresh_from_db()
        self.assertEqual(self.receiver.wallet.balance, Decimal("0.00"))

    def test_link_wallet_rejects_weak_or_malformed_code(self):
        self.client.force_login(self.student)

        weak_response = self.client.post(
            reverse("link_wallet"),
            data={"link_code": "ABC123"},
        )
        malformed_response = self.client.post(
            reverse("link_wallet"),
            data={"link_code": "ABC' OR 1=1 --"},
        )

        self.assertEqual(weak_response.status_code, 400)
        self.assertEqual(malformed_response.status_code, 400)

    def test_transfer_rejects_insufficient_balance_without_receiver_deposit(self):
        self.client.force_login(self.student)

        response = self.client.post(
            reverse("transfer_wallet"),
            data={
                "wallet_code": self.receiver.wallet.link_code,
                "amount": "5.00",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.student.wallet.refresh_from_db()
        self.receiver.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("0.00"))
        self.assertEqual(self.receiver.wallet.balance, Decimal("0.00"))

    def test_regular_user_cannot_transfer_to_own_wallet(self):
        self.client.force_login(self.student)

        response = self.client.post(
            reverse("transfer_wallet"),
            data={
                "wallet_code": self.student.wallet.link_code,
                "amount": "1.00",
            },
        )

        self.assertEqual(response.status_code, 400)
        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("0.00"))
