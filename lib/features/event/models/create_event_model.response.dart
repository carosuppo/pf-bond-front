class CreateEventResponseModel {
  final int id;
  final String name;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final List<int> memberIds;

  const CreateEventResponseModel({
    required this.id,
    required this.name,
    this.description,
    required this.startAt,
    this.endAt,
    required this.memberIds,
  });

  factory CreateEventResponseModel.fromJson(Map<String, dynamic> json) {
    return CreateEventResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: json['endAt'] != null
          ? DateTime.parse(json['endAt'] as String)
          : null,
      memberIds: (json['memberIds'] as List<dynamic>)
          .map((memberId) => memberId as int)
          .toList(),
    );
  }
}
