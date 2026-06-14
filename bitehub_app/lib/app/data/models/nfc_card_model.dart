class NfcCardModel {
  const NfcCardModel({
    required this.studentName,
    required this.college,
    required this.email,
    required this.cardLast4,
    required this.isOwner,
    this.balance,
  });

  final String studentName;
  final String college;
  final String email;
  final String cardLast4;
  final bool isOwner;
  final double? balance;

  factory NfcCardModel.fromJson(Map<String, dynamic> json) {
    final rawBalance = json['balance'];
    return NfcCardModel(
      studentName: (json['student_name'] ?? '').toString(),
      college: (json['college'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      cardLast4: (json['card_last4'] ?? '').toString(),
      isOwner: json['is_owner'] == true,
      balance: rawBalance == null
          ? null
          : rawBalance is num
              ? rawBalance.toDouble()
              : double.tryParse(rawBalance.toString()),
    );
  }
}
