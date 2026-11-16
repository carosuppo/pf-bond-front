import 'event_location_model.dart';
import 'create_event_model.request.dart';

class EventResponseModel {
  final int? recurrenceId;
  final EventRecurrenceRequest? recurrence;
  final int id;
  final String name;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final List<int> memberIds;
  final EventLocationModel? location;

  const EventResponseModel({
    this.recurrenceId,
    this.recurrence,
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
      recurrenceId: json['recurrenceId'] as int?,
      recurrence: json['recurrence'] == null
          ? null
          : EventRecurrenceRequest.fromJson(
              json['recurrence'] as Map<String, dynamic>,
            ),
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
