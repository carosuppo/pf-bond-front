import 'balance_status.dart';

class MyExpenseAccountResponseModel {
  final int id;
  final String name;
  final int groupId;
  final String groupName;
  final int? eventId;
  final String? eventName;
  final int balanceCents;
  final BalanceStatus status;

  const MyExpenseAccountResponseModel({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
    this.eventId,
    this.eventName,
    required this.balanceCents,
    required this.status,
  });

  factory MyExpenseAccountResponseModel.fromJson(Map<String, dynamic> json) {
    return MyExpenseAccountResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      groupId: json['groupId'] as int,
      groupName: json['groupName'] as String,
      eventId: json['eventId'] as int?,
      eventName: json['eventName'] as String?,
      balanceCents: json['balanceCents'] as int,
      status: balanceStatusFromString(json['status'] as String),
    );
  }
}
