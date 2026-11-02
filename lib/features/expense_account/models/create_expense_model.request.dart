import 'expense_split_type.dart';

class ExpenseShareRequestModel {
  final int memberId;
  final int amountCents;

  const ExpenseShareRequestModel({
    required this.memberId,
    required this.amountCents,
  });

  Map<String, dynamic> toJson() {
    return {'memberId': memberId, 'amountCents': amountCents};
  }
}

class CreateExpenseRequestModel {
  final String? title;
  final int amountCents;
  final int payerMemberId;
  final ExpenseSplitType splitType;
  final List<int>? participantIds;
  final List<ExpenseShareRequestModel>? shares;

  const CreateExpenseRequestModel({
    this.title,
    required this.amountCents,
    required this.payerMemberId,
    required this.splitType,
    this.participantIds,
    this.shares,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title?.isEmpty ?? true ? null : title,
      'amountCents': amountCents,
      'payerMemberId': payerMemberId,
      'splitType': splitType.value,
      'participantIds': participantIds,
      'shares': shares?.map((share) => share.toJson()).toList(),
    };
  }
}
