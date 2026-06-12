from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse

from core.models import Notification
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

    def test_staff_user_cannot_have_student_wallet(self):
        self.client.force_login(self.admin)

        response = self.client.post(self.url, data={"amount": "10.00"})

        self.assertEqual(response.status_code, 403, response.content)
        self.assertFalse(hasattr(self.admin, "wallet"))

    @override_settings(WALLET_APP_TOPUP_ENABLED=True)
    def test_app_topup_stays_disabled_even_if_legacy_flag_is_enabled(self):
        self.client.force_login(self.student)

        response = self.client.post(self.url, data={"amount": "10.00"})

        self.assertEqual(response.status_code, 403, response.content)
        self.student.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("0.00"))

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

        self.assertEqual(response.status_code, 403)
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
                "recipient_name": "زميل الدراسة",
            },
        )

        self.assertEqual(response.status_code, 200, response.content)
        self.student.wallet.refresh_from_db()
        self.receiver.wallet.refresh_from_db()
        self.assertEqual(self.student.wallet.balance, Decimal("7.00"))
        self.assertEqual(self.receiver.wallet.balance, Decimal("5.00"))
        self.assertTrue(
            self.student.wallet.transactions.filter(
                transaction_type="WITHDRAWAL",
                description__contains="تحويل إلى زميل الدراسة",
            ).exists()
        )
        self.assertTrue(
            Notification.objects.filter(
                user=self.student,
                event_type="WALLET_TRANSFER_SENT",
                title="تم إرسال التحويل",
            ).exists()
        )
        self.assertTrue(
            Notification.objects.filter(
                user=self.receiver,
                event_type="WALLET_TRANSFER_RECEIVED",
                title="وصل تحويل إلى محفظتك",
            ).exists()
        )

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

    def test_student_can_link_unique_nfc_card_without_changing_wallet_code(self):
        original_wallet_code = self.student.wallet.link_code
        self.client.force_login(self.student)

        response = self.client.post(
            reverse("link_nfc_card"),
            data={"card_uid": "NFC-00112233445566"},
        )

        self.assertEqual(response.status_code, 200, response.content)
        self.student.wallet.refresh_from_db()
        self.assertEqual(
            self.student.wallet.nfc_card_uid,
            "NFC-00112233445566",
        )
        self.assertEqual(self.student.wallet.link_code, original_wallet_code)

    def test_nfc_card_cannot_be_linked_to_two_students(self):
        self.student.wallet.nfc_card_uid = "NFC-00112233445566"
        self.student.wallet.save(update_fields=["nfc_card_uid", "updated_at"])
        self.client.force_login(self.receiver)

        response = self.client.post(
            reverse("link_nfc_card"),
            data={"card_uid": "NFC-00112233445566"},
        )

        self.assertEqual(response.status_code, 400, response.content)
        self.receiver.wallet.refresh_from_db()
        self.assertIsNone(self.receiver.wallet.nfc_card_uid)
