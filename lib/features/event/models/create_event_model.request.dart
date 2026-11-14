import '../../../core/timezone/app_timezone.dart';

class CreateEventRequestModel {
  final EventRecurrenceRequest? recurrence;
  final String name;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final List<int> memberIds;

  const CreateEventRequestModel({
    this.recurrence,
    required this.name,
    this.description,
    required this.startAt,
    this.endAt,
    required this.memberIds,
  });

  Map<String, dynamic> toJson() {
    return {
      if (recurrence != null) 'recurrence': recurrence!.toJson(),
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

enum EventRecurrenceFrequency {
  daily('DAILY', 'Diariamente'),
  weekly('WEEKLY', 'Semanalmente'),
  monthly('MONTHLY', 'Mensualmente');

  final String value;
  final String label;
  const EventRecurrenceFrequency(this.value, this.label);
}

class EventRecurrenceRequest {
  final EventRecurrenceFrequency frequency;
  final DateTime? until;
  const EventRecurrenceRequest({required this.frequency, this.until});

  factory EventRecurrenceRequest.fromJson(Map<String, dynamic> json) {
    final String frequencyValue = json['frequency'] as String;
    final frequency = EventRecurrenceFrequency.values.firstWhere(
      (value) => value.value == frequencyValue,
    );

    return EventRecurrenceRequest(
      frequency: frequency,
      until: json['until'] == null
          ? null
          : DateTime.parse(json['until'] as String),
    );
  }

  String? validateFor(DateTime startAt) =>
      until != null && !until!.isAfter(startAt)
      ? 'La fecha final de la recurrencia debe ser posterior al inicio.'
      : null;

  Map<String, String?> toJson() => {
    'frequency': frequency.value,
    'until': until == null
        ? null
        : AppTimezone.argentinaToUtc(until!).toIso8601String(),
  };
}
