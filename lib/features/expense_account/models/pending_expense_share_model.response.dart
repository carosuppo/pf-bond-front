class PendingExpenseShareResponseModel {
  final int expenseShareId;
  final int expenseId;
  final String? expenseTitle;
  final int payerMemberId;
  final int amountCents;
  final DateTime createdAt;

  const PendingExpenseShareResponseModel({
    required this.expenseShareId,
    required this.expenseId,
    required this.expenseTitle,
    required this.payerMemberId,
    required this.amountCents,
    required this.createdAt,
  });

  factory PendingExpenseShareResponseModel.fromJson(Map<String, dynamic> json) {
    return PendingExpenseShareResponseModel(
      expenseShareId: json['expenseShareId'] as int,
      expenseId: json['expenseId'] as int,
      expenseTitle: json['expenseTitle'] as String?,
      payerMemberId: json['payerMemberId'] as int,
      amountCents: json['amountCents'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
