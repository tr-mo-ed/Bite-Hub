from django.db import transaction
from django.utils import timezone

from core.utils import send_real_notification

from .models import Transaction, Wallet, WalletDebitRequest


def create_cafe_debit_request(*, cafe, wallet, amount, requested_by, note=""):
    request_item = WalletDebitRequest.objects.create(
        wallet=wallet,
        cafe=cafe,
        requested_by=requested_by,
        amount=amount,
        note=(note or "").strip()[:255],
    )
    send_real_notification(
        wallet.user,
        "طلب خصم من المحفظة",
        (
            f"يريد {cafe.name} خصم {amount} د.ل من محفظتك. "
            "افتح المحفظة للموافقة أو الرفض."
        ),
        event_type="WALLET_DEBIT_REQUESTED",
    )
    return request_item


@transaction.atomic
def respond_to_debit_request(*, request_id, user, approve: bool):
    request_item = (
        WalletDebitRequest.objects.select_for_update()
        .select_related("wallet", "wallet__user", "cafe")
        .filter(pk=request_id, wallet__user=user)
        .first()
    )
    if request_item is None:
        raise ValueError("طلب الخصم غير موجود.")
    if request_item.status != WalletDebitRequest.Status.PENDING:
        raise ValueError("تم الرد على طلب الخصم مسبقاً.")

    now = timezone.now()
    if not approve:
        request_item.status = WalletDebitRequest.Status.REJECTED
        request_item.responded_at = now
        request_item.save(update_fields=["status", "responded_at"])
        send_real_notification(
            request_item.requested_by,
            "تم رفض طلب الخصم",
            (
                f"رفض {request_item.wallet.user.full_name or request_item.wallet.user.email} "
                f"خصم {request_item.amount} د.ل."
            ),
            event_type="WALLET_DEBIT_REJECTED",
        )
        return request_item

    wallet = Wallet.objects.select_for_update().get(pk=request_item.wallet_id)
    if wallet.balance < request_item.amount:
        raise ValueError("رصيد المحفظة غير كافٍ للموافقة على الخصم.")

    description = f"{request_item.cafe.name} - خصم وافق عليه الطالب"
    if request_item.note:
        description = f"{description} - {request_item.note}"
    transaction_record = Transaction.objects.create(
        wallet=wallet,
        cafe=request_item.cafe,
        amount=request_item.amount,
        transaction_type="WITHDRAWAL",
        source="SYSTEM",
        description=description,
    )
    request_item.status = WalletDebitRequest.Status.APPROVED
    request_item.responded_at = now
    request_item.transaction_record = transaction_record
    request_item.save(
        update_fields=["status", "responded_at", "transaction_record"]
    )
    send_real_notification(
        request_item.requested_by,
        "تمت الموافقة على الخصم",
        (
            f"وافق {request_item.wallet.user.full_name or request_item.wallet.user.email} "
            f"على خصم {request_item.amount} د.ل."
        ),
        event_type="WALLET_DEBIT_APPROVED",
    )
    return request_item
