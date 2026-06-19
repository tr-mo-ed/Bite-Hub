import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet parses pending cafe debit requests', () {
    final wallet = WalletModel.fromJson({
      'id': 12,
      'balance': '42.50',
      'currency': 'LYD',
      'college': 'كلية العلوم',
      'link_code': 'WALLET12',
      'user_full_name': 'طالب تجريبي',
      'has_nfc_card': false,
      'nfc_card_last4': '',
      'transactions': <dynamic>[],
      'pending_debit_requests': [
        {
          'id': '7ce6ce12-8878-4b30-a136-6f14c60137d9',
          'cafe_name': 'مقهى العلوم',
          'amount': '6.25',
          'note': 'طلب يدوي',
          'status': 'PENDING',
          'status_display': 'بانتظار موافقة الطالب',
          'created_at': '2026-06-19T10:30:00Z',
        },
      ],
    });

    expect(wallet.pendingDebitRequests, hasLength(1));
    final request = wallet.pendingDebitRequests.single;
    expect(request.cafeName, 'مقهى العلوم');
    expect(request.amount, 6.25);
    expect(request.isPending, isTrue);
  });
}
