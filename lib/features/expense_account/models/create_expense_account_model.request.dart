class CreateExpenseAccountRequestModel {
  final String name;
  final int groupId;
  final List<int> memberIds;
  final int? eventId;

  const CreateExpenseAccountRequestModel({
    required this.name,
    required this.groupId,
    required this.memberIds,
    this.eventId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'groupId': groupId,
      'memberIds': memberIds,
      'eventId': eventId,
    };
  }
}
