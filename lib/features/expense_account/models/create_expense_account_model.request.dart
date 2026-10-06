class CreateExpenseAccountRequestModel {
  final String name;
  final List<int> memberIds;
  final int? eventId;

  const CreateExpenseAccountRequestModel({
    required this.name,
    required this.memberIds,
    this.eventId,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'memberIds': memberIds, 'eventId': eventId};
  }
}
