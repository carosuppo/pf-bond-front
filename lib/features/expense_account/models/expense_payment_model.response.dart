class ExpensePaymentResponseModel {
  final String kind;
  final int id;
  final int expenseId;
  final int expenseShareId;
  final int? adjustmentId;
  final int fromMemberId;
  final int toMemberId;
  final int amountCents;
  final DateTime createdAt;
  final DateTime confirmedAt;

  const ExpensePaymentResponseModel({
    required this.kind,
    required this.id,
    required this.expenseId,
    required this.expenseShareId,
    required this.adjustmentId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountCents,
    required this.createdAt,
    required this.confirmedAt,
  });

  factory ExpensePaymentResponseModel.fromJson(Map<String, dynamic> json) {
    return ExpensePaymentResponseModel(
      kind: json['kind'] as String? ?? 'EXPENSE_SHARE',
      id: json['id'] as int,
      expenseId: json['expenseId'] as int,
      expenseShareId: json['expenseShareId'] as int,
      adjustmentId: json['adjustmentId'] as int?,
      fromMemberId: json['fromMemberId'] as int,
      toMemberId: json['toMemberId'] as int,
      amountCents: json['amountCents'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      confirmedAt: DateTime.parse(json['confirmedAt'] as String),
    );
  }
}
