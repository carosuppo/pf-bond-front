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
  final String kind;

  const AccountMovementModel({required this.kind});

  factory AccountMovementModel.fromJson(Map<String, dynamic> json) {
    return AccountMovementModel(kind: json['kind'] as String);
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
