import 'balance_status.dart';

class AccountMemberBalanceModel {
  final int memberId;
  final int balanceCents;
  final BalanceStatus status;

  const AccountMemberBalanceModel({
    required this.memberId,
    required this.balanceCents,
    required this.status,
  });

  factory AccountMemberBalanceModel.fromJson(Map<String, dynamic> json) {
    return AccountMemberBalanceModel(
      memberId: json['memberId'] as int,
      balanceCents: json['balanceCents'] as int,
      status: balanceStatusFromString(json['status'] as String),
    );
  }
}

class AccountShareModel {
  final int memberId;
  final int amountCents;

  const AccountShareModel({required this.memberId, required this.amountCents});

  factory AccountShareModel.fromJson(Map<String, dynamic> json) {
    return AccountShareModel(
      memberId: json['memberId'] as int,
      amountCents: json['amountCents'] as int,
    );
  }
}

class AccountDebtModel {
  final int memberId;
  final int amountCents;

  const AccountDebtModel({required this.memberId, required this.amountCents});

  factory AccountDebtModel.fromJson(Map<String, dynamic> json) {
    return AccountDebtModel(
      memberId: json['memberId'] as int,
      amountCents: json['amountCents'] as int,
    );
  }
}

class AccountMovementModel {
  final int id;
  final String kind;
  final String? title;
  final int amountCents;
  final int? payerMemberId;
  final int? fromMemberId;
  final int? toMemberId;
  final DateTime createdAt;
  final List<AccountShareModel> shares;

  const AccountMovementModel({
    required this.id,
    required this.kind,
    this.title,
    required this.amountCents,
    this.payerMemberId,
    this.fromMemberId,
    this.toMemberId,
    required this.createdAt,
    this.shares = const [],
  });

  factory AccountMovementModel.fromJson(Map<String, dynamic> json) {
    return AccountMovementModel(
      id: json['id'] as int,
      kind: json['kind'] as String,
      title: json['title'] as String?,
      amountCents: json['amountCents'] as int,
      payerMemberId: json['payerMemberId'] as int?,
      fromMemberId: json['fromMemberId'] as int?,
      toMemberId: json['toMemberId'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      shares:
          (json['shares'] as List<dynamic>?)
              ?.map(
                (share) =>
                    AccountShareModel.fromJson(share as Map<String, dynamic>),
              )
              .toList(growable: false) ??
          [],
    );
  }
}

class ExpenseAccountDetailResponseModel {
  final int id;
  final String name;
  final int groupId;
  final String groupName;
  final int? eventId;
  final String? eventName;
  final List<AccountMemberBalanceModel> members;
  final int myMemberId;
  final int myBalanceCents;
  final BalanceStatus myStatus;
  final List<AccountDebtModel> debtsToMe;
  final List<AccountDebtModel> myDebts;
  final List<AccountMovementModel> movements;

  const ExpenseAccountDetailResponseModel({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
    this.eventId,
    this.eventName,
    required this.members,
    required this.myMemberId,
    required this.myBalanceCents,
    required this.myStatus,
    required this.debtsToMe,
    required this.myDebts,
    required this.movements,
  });

  factory ExpenseAccountDetailResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ExpenseAccountDetailResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      groupId: json['groupId'] as int,
      groupName: json['groupName'] as String,
      eventId: json['eventId'] as int?,
      eventName: json['eventName'] as String?,
      members: (json['members'] as List<dynamic>)
          .map(
            (member) => AccountMemberBalanceModel.fromJson(
              member as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      myMemberId: json['myMemberId'] as int,
      myBalanceCents: json['myBalanceCents'] as int,
      myStatus: balanceStatusFromString(json['myStatus'] as String),
      debtsToMe: (json['debtsToMe'] as List<dynamic>)
          .map(
            (debt) => AccountDebtModel.fromJson(debt as Map<String, dynamic>),
          )
          .toList(growable: false),
      myDebts: (json['myDebts'] as List<dynamic>)
          .map(
            (debt) => AccountDebtModel.fromJson(debt as Map<String, dynamic>),
          )
          .toList(growable: false),
      movements: (json['movements'] as List<dynamic>)
          .map(
            (movement) =>
                AccountMovementModel.fromJson(movement as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}
