class UpdateExpenseAccountRequestModel {
  final String name;
  final List<int> memberIds;
  final int? eventId;
  final bool updateEvent;

  const UpdateExpenseAccountRequestModel({
    required this.name,
    required this.memberIds,
    required this.eventId,
    required this.updateEvent,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'memberIds': memberIds,
      if (updateEvent) 'eventId': eventId,
    };
  }
}
