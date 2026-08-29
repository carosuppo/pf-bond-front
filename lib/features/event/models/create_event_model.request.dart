class CreateEventRequestModel {
  final String name;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final List<int> memberIds;

  const CreateEventRequestModel({
    required this.name,
    this.description,
    required this.startAt,
    this.endAt,
    required this.memberIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt?.toUtc().toIso8601String(),
      'memberIds': memberIds,
    };
  }
}
