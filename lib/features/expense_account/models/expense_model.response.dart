import 'expense_split_type.dart';

class ExpenseShareResponseModel {
  final int memberId;
  final int amountCents;

  const ExpenseShareResponseModel({
    required this.memberId,
    required this.amountCents,
  });

  factory ExpenseShareResponseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseShareResponseModel(
      memberId: json['memberId'] as int,
      amountCents: json['amountCents'] as int,
    );
  }
}

class ExpenseResponseModel {
  final int id;
  final int expenseAccountId;
  final String? title;
  final int amountCents;
  final ExpenseSplitType splitType;
  final int payerMemberId;
  final int? createdByUserId;
  final List<ExpenseShareResponseModel> shares;

  const ExpenseResponseModel({
    required this.id,
    required this.expenseAccountId,
    this.title,
    required this.amountCents,
    required this.splitType,
    required this.payerMemberId,
    this.createdByUserId,
    required this.shares,
  });

  factory ExpenseResponseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseResponseModel(
      id: json['id'] as int,
      expenseAccountId: json['expenseAccountId'] as int,
      title: json['title'] as String?,
      amountCents: json['amountCents'] as int,
      splitType: expenseSplitTypeFromString(json['splitType'] as String),
      payerMemberId: json['payerMemberId'] as int,
      createdByUserId: json['createdByUserId'] as int?,
      shares: (json['shares'] as List<dynamic>)
          .map(
            (share) => ExpenseShareResponseModel.fromJson(
              share as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}
