from decimal import Decimal
import re

from django.db import IntegrityError, transaction
from django.db.models import Q, Sum
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.conf import settings
from django.contrib.auth import get_user_model

from core.utils import send_real_notification

from .models import Transaction, Wallet, WalletDebitRequest
from .serializers import (
    TransactionSerializer,
    WalletDebitRequestSerializer,
    WalletSerializer,
)
from .services import respond_to_debit_request

# ??? ??????? User ??? ????? ??? ???? ???? ???? ????? ????.
User = get_user_model()

# ???? ???? _sync_wallet_balance ?????? ????? ?????? ?? ????? ????.
def _sync_wallet_balance(wallet):
    # ??? ??????? aggregates ??? ????? ??? ???? ???? ???? ????? ????.
    aggregates = wallet.transactions.aggregate(
        # ??? ??????? deposits ??? ????? ??? ???? ???? ???? ????? ????.
        deposits=Sum('amount', filter=Q(transaction_type__in=['DEPOSIT', 'deposit'])),
        # ??? ??????? withdrawals ??? ????? ??? ???? ???? ???? ????? ????.
        withdrawals=Sum('amount', filter=Q(transaction_type__in=['WITHDRAWAL', 'withdrawal'])),
    )
    # ??? ??????? deposits ??? ????? ??? ???? ???? ???? ????? ????.
    deposits = aggregates.get('deposits') or Decimal('0')
    # ??? ??????? withdrawals ??? ????? ??? ???? ???? ???? ????? ????.
    withdrawals = aggregates.get('withdrawals') or Decimal('0')
    # ??? ??????? new_balance ??? ????? ??? ???? ???? ???? ????? ????.
    new_balance = deposits - withdrawals
    if wallet.balance != new_balance:
        wallet.balance = new_balance
        wallet.save(update_fields=['balance'])
    return wallet


def _wallet_payload(wallet):
    wallet = _sync_wallet_balance(wallet)
    wallet.refresh_from_db()

    recent_transactions = (
        wallet.transactions.select_related('cafe').order_by('-created_at')[:20]
    )
    data = WalletSerializer(wallet).data
    data['transactions'] = TransactionSerializer(
        recent_transactions,
        many=True,
    ).data
    debit_requests = (
        wallet.debit_requests.select_related("cafe")
        .filter(status=WalletDebitRequest.Status.PENDING)
        .order_by("-created_at")
    )
    data["pending_debit_requests"] = WalletDebitRequestSerializer(
        debit_requests,
        many=True,
    ).data
    return data

# ???? ???? verify_token_get_user ?????? ????? ?????? ?? ????? ????.
def verify_token_get_user(request):
    """
    External token authentication has been removed.
    """
    raise ValueError("External token authentication is disabled")
# ???? ???? get_request_user ?????? ????? ?????? ?? ????? ????.
def get_request_user(request):
    """
    Return the authenticated Django/DRF user.
    """
    if hasattr(request, 'user') and request.user and request.user.is_authenticated:
        return request.user
    raise ValueError("Authentication required")


def _normalize_card_uid(raw_uid):
    card_uid = str(raw_uid or "").strip().upper()
    if not 4 <= len(card_uid) <= 64 or not re.fullmatch(r"[A-Z0-9:_-]+", card_uid):
        raise ValueError("معرف بطاقة NFC غير صحيح.")
    return card_uid


def _normalize_wallet_link_code(raw_code):
    code = str(raw_code or "").strip().upper()
    if re.fullmatch(r"\d{4,5}", code):
        return code
    if not 12 <= len(code) <= 32 or not re.fullmatch(r"[A-Z0-9_-]+", code):
        raise ValueError("كود المحفظة غير صحيح.")
    return code


def _parse_positive_amount(raw_amount):
    try:
        amount = Decimal(str(raw_amount))
    except Exception as exc:
        raise ValueError("قيمة المبلغ غير صحيحة.") from exc
    if amount <= 0:
        raise ValueError("يجب أن تكون القيمة أكبر من صفر.")
    return amount


def _masked_email(email):
    local, separator, domain = str(email or "").partition("@")
    if not separator:
        return ""
    visible = local[:2]
    return f"{visible}{'*' * max(3, len(local) - len(visible))}@{domain}"


def _nfc_wallet_payload(wallet, requesting_user):
    can_view_private_data = (
        wallet.user_id == requesting_user.id
        or requesting_user.is_staff
        or requesting_user.is_superuser
    )
    payload = {
        "student_name": wallet.user.full_name or wallet.user.email,
        "college": wallet.college,
        "email": wallet.user.email if can_view_private_data else _masked_email(wallet.user.email),
        "wallet_code": wallet.link_code if can_view_private_data else "",
        "card_last4": (wallet.nfc_card_uid or "")[-4:],
        "is_owner": wallet.user_id == requesting_user.id,
    }
    if can_view_private_data:
        payload["balance"] = str(wallet.balance)
        payload["phone"] = wallet.user.phone_number
    return payload


def _transfer_balance(sender_wallet, target_wallet, amount, *, note="", source="USER"):
    if sender_wallet.id == target_wallet.id:
        raise ValueError("لا يمكن التحويل إلى نفس المحفظة.")

    with transaction.atomic():
        wallet_ids = sorted([sender_wallet.id, target_wallet.id])
        locked_wallets = {
            wallet.id: wallet
            for wallet in Wallet.objects.select_for_update()
            .select_related("user")
            .filter(id__in=wallet_ids)
        }
        sender = locked_wallets[sender_wallet.id]
        target = locked_wallets[target_wallet.id]

        if sender.balance < amount:
            raise ValueError("رصيد المحفظة غير كافٍ لإتمام العملية.")

        sender_description = f"تحويل إلى {target.user.full_name or target.user.email}"
        receiver_description = f"تحويل من {sender.user.full_name or sender.user.email}"
        if note:
            sender_description = f"{sender_description} - {note}"
            receiver_description = f"{receiver_description} - {note}"

        Transaction.objects.create(
            wallet=sender,
            amount=amount,
            transaction_type="WITHDRAWAL",
            source=source,
            description=sender_description,
        )
        Transaction.objects.create(
            wallet=target,
            amount=amount,
            transaction_type="DEPOSIT",
            source=source,
            description=receiver_description,
        )

    sender.refresh_from_db()
    target.refresh_from_db()
    try:
        send_real_notification(
            sender.user,
            "تم إرسال التحويل",
            f"تم تحويل {amount} د.ل إلى {target.user.full_name or target.user.email}.",
            event_type="WALLET_TRANSFER_SENT",
        )
        send_real_notification(
            target.user,
            "وصل تحويل إلى محفظتك",
            f"استلمت {amount} د.ل من {sender.user.full_name or sender.user.email}.",
            event_type="WALLET_TRANSFER_RECEIVED",
        )
    except Exception:
        pass
    return sender, target



# ???? ???? get_wallet ?????? ????? ?????? ?? ????? ????.
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_wallet(request):
    try:
        # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
        user = get_request_user(request)
    except Exception as e:
        return Response({'error': str(e)}, status=401)

    wallet, _ = Wallet.objects.get_or_create(user=user)
    return Response(_wallet_payload(wallet))


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def respond_wallet_debit_request(request, request_id):
    raw_decision = str(request.data.get("decision") or "").strip().lower()
    if raw_decision not in {"approve", "reject"}:
        return Response(
            {"error": "اختر الموافقة أو الرفض."},
            status=400,
        )

    try:
        request_item = respond_to_debit_request(
            request_id=request_id,
            user=request.user,
            approve=raw_decision == "approve",
        )
    except ValueError as exc:
        return Response({"error": str(exc)}, status=400)

    request_item = WalletDebitRequest.objects.select_related("cafe", "wallet").get(
        pk=request_item.pk
    )
    wallet_payload = _wallet_payload(request_item.wallet)
    return Response(
        {
            "success": True,
            "request": WalletDebitRequestSerializer(request_item).data,
            "balance": str(wallet_payload["balance"]),
            "wallet": wallet_payload,
        }
    )


# ???? ???? transfer_wallet ?????? ????? ?????? ?? ????? ????.
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def transfer_wallet(request):
    try:
        # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
        user = get_request_user(request)
    except Exception as e:
        return Response({'error': str(e)}, status=401)

    # ??? ??????? wallet_code ??? ????? ??? ???? ???? ???? ????? ????.
    raw_wallet_code = (request.data.get('wallet_code')
                       or request.data.get('link_code')
                       or '')
    # ??? ??????? amount_raw ??? ????? ??? ???? ???? ???? ????? ????.
    amount_raw = request.data.get('amount')
    # ??? ??????? note ??? ????? ??? ???? ???? ???? ????? ????.
    note = (request.data.get('note') or request.data.get('description') or '').strip()

    if not raw_wallet_code:
        return Response({'error': 'يجب إدخال رقم المحفظة.'}, status=400)

    try:
        wallet_code = _normalize_wallet_link_code(raw_wallet_code)
        amount = _parse_positive_amount(amount_raw)
    except ValueError as exc:
        return Response({'error': str(exc)}, status=400)

    try:
        # ??? ??????? sender_wallet ??? ????? ??? ???? ???? ???? ????? ????.
        sender_wallet_lookup = Wallet.objects.get(user=user)

        # ??? ??????? target_wallet ??? ????? ??? ???? ???? ???? ????? ????.
        target_wallet_lookup = Wallet.objects.filter(link_code__iexact=wallet_code).first()

        if not target_wallet_lookup:
            return Response({'error': 'المحفظة المستلمة غير موجودة.'}, status=404)

        sender_wallet, target_wallet = _transfer_balance(
            sender_wallet_lookup,
            target_wallet_lookup,
            amount,
            note=note,
            source="USER",
        )
        return Response({
            'success': True,
            'balance': sender_wallet.balance,
            'recipient': target_wallet.user.full_name or target_wallet.user.email,
        })
    except Wallet.DoesNotExist:
        return Response({'error': 'المحفظة غير موجودة.'}, status=404)
    except ValueError as e:
        return Response({'error': str(e)}, status=400)
    except Exception as e:
        return Response({'error': str(e)}, status=500)


# ???? ???? link_wallet ?????? ????? ?????? ?? ????? ????.
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def link_wallet(request):
    try:
        # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
        user = get_request_user(request)
    except Exception as e:
        return Response({'error': str(e)}, status=401)

    # ??? ??????? link_code ??? ????? ??? ???? ???? ???? ????? ????.
    raw_link_code = request.data.get('link_code')
    if not raw_link_code:
        return Response({'error': 'Code is required'}, status=400)
    try:
        link_code = _normalize_wallet_link_code(raw_link_code)
    except ValueError as exc:
        return Response({'error': str(exc)}, status=400)
    
    try:
        # التأكد من أن الكود فريد وغير مستخدم من شخص آخر
        if Wallet.objects.filter(link_code=link_code).exclude(user=user).exists():
             return Response({'error': 'هذا الكود مستخدم بالفعل من قبل طالب آخر'}, status=400)
        
        wallet, _ = Wallet.objects.get_or_create(user=user)
        wallet.link_code = link_code
        wallet.save()
        return Response({'success': True, 'message': 'تم ربط المحفظة بنجاح'})
    except Exception as e:
         return Response({'error': str(e)}, status=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def link_nfc_card(request):
    try:
        card_uid = _normalize_card_uid(request.data.get('card_uid'))
    except ValueError as exc:
        return Response({'error': str(exc)}, status=400)

    wallet, _ = Wallet.objects.get_or_create(user=request.user)
    if Wallet.objects.filter(nfc_card_uid__iexact=card_uid).exclude(pk=wallet.pk).exists():
        return Response({'error': 'هذه البطاقة مرتبطة بطالب آخر.'}, status=409)

    wallet.nfc_card_uid = card_uid
    try:
        wallet.save(update_fields=['nfc_card_uid', 'updated_at'])
    except IntegrityError:
        return Response({'error': 'هذه البطاقة مرتبطة بطالب آخر.'}, status=409)

    return Response({
        'success': True,
        'message': 'تم ربط بطاقة NFC بمحفظتك بنجاح.',
        'wallet': _nfc_wallet_payload(wallet, request.user),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def lookup_nfc_card(request):
    try:
        card_uid = _normalize_card_uid(request.data.get('card_uid'))
    except ValueError as exc:
        return Response({'error': str(exc)}, status=400)

    wallet = (
        Wallet.objects.select_related('user')
        .filter(nfc_card_uid__iexact=card_uid)
        .first()
    )
    if wallet is None:
        return Response({'error': 'البطاقة غير مرتبطة بأي محفظة.'}, status=404)

    return Response({
        'success': True,
        'card': _nfc_wallet_payload(wallet, request.user),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def transfer_to_nfc_card(request):
    try:
        card_uid = _normalize_card_uid(request.data.get('card_uid'))
        amount = _parse_positive_amount(request.data.get('amount'))
    except ValueError as exc:
        return Response({'error': str(exc)}, status=400)

    sender_wallet, _ = Wallet.objects.get_or_create(user=request.user)
    target_wallet = (
        Wallet.objects.select_related('user')
        .filter(nfc_card_uid__iexact=card_uid)
        .first()
    )
    if target_wallet is None:
        return Response({'error': 'البطاقة غير مرتبطة بأي محفظة.'}, status=404)

    try:
        sender_wallet, target_wallet = _transfer_balance(
            sender_wallet,
            target_wallet,
            amount,
            note=(request.data.get('note') or '').strip(),
            source='NFC',
        )
    except ValueError as exc:
        return Response({'error': str(exc)}, status=400)

    return Response({
        'success': True,
        'balance': sender_wallet.balance,
        'recipient': _nfc_wallet_payload(target_wallet, request.user),
    })


# ???? ???? topup_wallet ?????? ????? ?????? ?? ????? ????.
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def topup_wallet(request):
    """
    شحن المحفظة (لأغراض الاختبار أو إذا كان هناك بوابة دفع).
    """
    try:
        # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
        user = get_request_user(request)
    except Exception as e:
        return Response({'error': str(e)}, status=401)

    if not (getattr(user, 'is_staff', False) or getattr(settings, 'WALLET_APP_TOPUP_ENABLED', False)):
        return Response({'error': 'Wallet top-up is not enabled for app users.'}, status=403)

    # ??? ??????? amount_raw ??? ????? ??? ???? ???? ???? ????? ????.
    amount_raw = request.data.get('amount')
    try:
        # ??? ??????? amount ??? ????? ??? ???? ???? ???? ????? ????.
        amount = Decimal(str(amount_raw))
    except:
        return Response({'error': 'Invalid amount'}, status=400)

    if amount <= 0:
        return Response({'error': 'Amount must be positive'}, status=400)

    try:
        wallet, _ = Wallet.objects.get_or_create(user=user)
        # إنشاء معاملة من نوع إيداع (سيقوم المودل بزيادة الرصيد تلقائياً)
        Transaction.objects.create(
            # ??? ??????? wallet ??? ????? ??? ???? ???? ???? ????? ????.
            wallet=wallet,
            # ??? ??????? amount ??? ????? ??? ???? ???? ???? ????? ????.
            amount=amount,
            # ??? ??????? transaction_type ??? ????? ??? ???? ???? ???? ????? ????.
            transaction_type='DEPOSIT',
            # ??? ??????? source ??? ????? ??? ???? ???? ???? ????? ????.
            source='APP',
            # ??? ??????? description ??? ????? ??? ???? ???? ???? ????? ????.
            description='App top-up'
        )
        wallet.refresh_from_db()
        return Response({'success': True, 'balance': wallet.balance})
    except Exception as e:
        return Response({'error': str(e)}, status=500)


# ???? ???? withdraw_wallet ?????? ????? ?????? ?? ????? ????.
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def withdraw_wallet(request):
    try:
        # ??? ??????? user ??? ????? ??? ???? ???? ???? ????? ????.
        user = get_request_user(request)
    except Exception as e:
        return Response({'error': str(e)}, status=401)

    # ??? ??????? amount_raw ??? ????? ??? ???? ???? ???? ????? ????.
    amount_raw = request.data.get('amount')
    # ??? ??????? note ??? ????? ??? ???? ???? ???? ????? ????.
    note = (request.data.get('note') or request.data.get('description') or '').strip()

    try:
        # ??? ??????? amount ??? ????? ??? ???? ???? ???? ????? ????.
        amount = Decimal(str(amount_raw))
    except Exception:
        return Response({'error': 'Invalid amount'}, status=400)

    if amount <= 0:
        return Response({'error': 'Amount must be positive'}, status=400)

    try:
        wallet, _ = Wallet.objects.get_or_create(user=user)
        # ??? ??????? description ??? ????? ??? ???? ???? ???? ????? ????.
        description = 'دفع للمقهى'
        if note:
            # ??? ??????? description ??? ????? ??? ???? ???? ???? ????? ????.
            description = f"{description} - {note}"

        Transaction.objects.create(
            # ??? ??????? wallet ??? ????? ??? ???? ???? ???? ????? ????.
            wallet=wallet,
            # ??? ??????? amount ??? ????? ??? ???? ???? ???? ????? ????.
            amount=amount,
            # ??? ??????? transaction_type ??? ????? ??? ???? ???? ???? ????? ????.
            transaction_type='WITHDRAWAL',
            # ??? ??????? source ??? ????? ??? ???? ???? ???? ????? ????.
            source='APP',
            # ??? ??????? description ??? ????? ??? ???? ???? ???? ????? ????.
            description=description,
        )
        wallet.refresh_from_db()
        return Response({'success': True, 'balance': wallet.balance})
    except ValueError as e:
        return Response({'error': str(e)}, status=400)
    except Exception as e:
        return Response({'error': str(e)}, status=500)
