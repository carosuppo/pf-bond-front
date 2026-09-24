class EventReminderModel {
  final int id;
  final int leadMinutes;
  final DateTime remindAt;
  final DateTime? sentAt;

  const EventReminderModel({
    required this.id,
    required this.leadMinutes,
    required this.remindAt,
    this.sentAt,
  });

  factory EventReminderModel.fromJson(Map<String, dynamic> json) {
    return EventReminderModel(
      id: json['id'] as int,
      leadMinutes: json['leadMinutes'] as int,
      remindAt: DateTime.parse(json['remindAt'] as String),
      sentAt: json['sentAt'] == null
          ? null
          : DateTime.parse(json['sentAt'] as String),
    );
  }
}
