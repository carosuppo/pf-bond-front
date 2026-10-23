class ExpenseAccountResponseModel {
  final int id;
  final String name;
  final int groupId;
  final int? eventId;
  final List<int> memberIds;

  const ExpenseAccountResponseModel({
    required this.id,
    required this.name,
    required this.groupId,
    this.eventId,
    required this.memberIds,
  });

  factory ExpenseAccountResponseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseAccountResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      groupId: json['groupId'] as int,
      eventId: json['eventId'] as int?,
      memberIds: (json['memberIds'] as List<dynamic>)
          .map((memberId) => memberId as int)
          .toList(growable: false),
    );
  }
}
