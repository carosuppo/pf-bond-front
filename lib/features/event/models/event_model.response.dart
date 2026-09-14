import 'event_location_model.dart';

class EventResponseModel {
  final int id;
  final String name;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final List<int> memberIds;
  final EventLocationModel? location;

  const EventResponseModel({
    required this.id,
    required this.name,
    this.description,
    required this.startAt,
    this.endAt,
    required this.memberIds,
    this.location,
  });

  factory EventResponseModel.fromJson(Map<String, dynamic> json) {
    return EventResponseModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      startAt: DateTime.parse(json['startAt'] as String),
      endAt: json['endAt'] != null
          ? DateTime.parse(json['endAt'] as String)
          : null,
      memberIds: (json['memberIds'] as List<dynamic>)
          .map((memberId) => memberId as int)
          .toList(growable: false),
      location: json['location'] != null
          ? EventLocationModel.fromJson(
              json['location'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
