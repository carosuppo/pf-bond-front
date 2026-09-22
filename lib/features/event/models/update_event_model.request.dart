import '../../../core/timezone/app_timezone.dart';

class UpdateEventRequestModel {
  final String? name;
  final String? description;
  final bool clearDescription;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool clearEndAt;
  final List<int>? memberIds;

  const UpdateEventRequestModel({
    this.name,
    this.description,
    this.clearDescription = false,
    this.startAt,
    this.endAt,
    this.clearEndAt = false,
    this.memberIds,
  });

  bool get isEmpty =>
      name == null &&
      description == null &&
      !clearDescription &&
      startAt == null &&
      endAt == null &&
      !clearEndAt &&
      memberIds == null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (name != null) {
      json['name'] = name;
    }

    if (clearDescription) {
      json['description'] = null;
    } else if (description != null) {
      json['description'] = description;
    }

    if (startAt != null) {
      json['startAt'] = AppTimezone.argentinaToUtc(startAt!).toIso8601String();
    }

    if (clearEndAt) {
      json['endAt'] = null;
    } else if (endAt != null) {
      json['endAt'] = AppTimezone.argentinaToUtc(endAt!).toIso8601String();
    }

    if (memberIds != null) {
      json['memberIds'] = memberIds;
    }

    return json;
  }
}
