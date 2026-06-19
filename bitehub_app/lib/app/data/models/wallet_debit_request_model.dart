class WalletDebitRequestModel {
  const WalletDebitRequestModel({
    required this.id,
    required this.cafeName,
    required this.amount,
    required this.note,
    required this.status,
    required this.statusDisplay,
    required this.createdAt,
  });

  final String id;
  final String cafeName;
  final double amount;
  final String note;
  final String status;
  final String statusDisplay;
  final DateTime? createdAt;

  bool get isPending => status.toUpperCase() == 'PENDING';

  factory WalletDebitRequestModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    return WalletDebitRequestModel(
      id: (json['id'] ?? '').toString(),
      cafeName: (json['cafe_name'] ?? '').toString(),
      amount: rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount?.toString() ?? '') ?? 0,
      note: (json['note'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      statusDisplay: (json['status_display'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}
