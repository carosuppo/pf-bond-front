import '../../../core/timezone/app_timezone.dart';

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
      'startAt': AppTimezone.argentinaToUtc(startAt).toIso8601String(),
      'endAt': endAt != null
          ? AppTimezone.argentinaToUtc(endAt!).toIso8601String()
          : null,
      'memberIds': memberIds,
    };
  }
}
