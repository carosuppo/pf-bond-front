class PendingExpenseAdjustmentResponseModel {
  final int adjustmentId;
  final int expenseId;
  final int expenseShareId;
  final String? expenseTitle;
  final int debtorMemberId;
  final int creditorMemberId;
  final int amountCents;
  final DateTime createdAt;

  const PendingExpenseAdjustmentResponseModel({
    required this.adjustmentId,
    required this.expenseId,
    required this.expenseShareId,
    required this.expenseTitle,
    required this.debtorMemberId,
    required this.creditorMemberId,
    required this.amountCents,
    required this.createdAt,
  });

  factory PendingExpenseAdjustmentResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return PendingExpenseAdjustmentResponseModel(
      adjustmentId: json['adjustmentId'] as int,
      expenseId: json['expenseId'] as int,
      expenseShareId: json['expenseShareId'] as int,
      expenseTitle: json['expenseTitle'] as String?,
      debtorMemberId: json['debtorMemberId'] as int,
      creditorMemberId: json['creditorMemberId'] as int,
      amountCents: json['amountCents'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
