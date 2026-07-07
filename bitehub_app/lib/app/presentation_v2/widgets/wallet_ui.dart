import 'package:bitehub_app/app/data/models/transaction_model.dart';

String transactionTypeLabel(TransactionModel transaction) {
  switch (transaction.type.toUpperCase()) {
    case 'DEPOSIT':
      if (transaction.isRefund) {
        return 'استرداد مبلغ';
      }
      return 'شحن';
    case 'WITHDRAWAL':
    case 'PURCHASE':
    case 'DEBIT':
      return 'خصم';
    case 'TRANSFER':
      return 'تحويل';
    default:
      return 'عملية مالية';
  }
}

String transactionSourceLabel(TransactionModel transaction) {
  final source = transaction.source.trim().toUpperCase();
  switch (source) {
    case 'SYSTEM':
      return 'النظام';
    case 'CAFE':
      return 'المقهى';
    case 'USER':
      return 'المستخدم';
    default:
      return transaction.source.trim().isEmpty
          ? 'المحفظة'
          : transaction.source.trim();
  }
}
