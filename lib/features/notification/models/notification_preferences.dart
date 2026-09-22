const notificationTypeLabels = {
  'POINT_OF_INTEREST_CREATED': 'Nuevos puntos de interés',
  'POINT_OF_INTEREST_UPDATED': 'Modificaciones de puntos de interés',
  'POINT_OF_INTEREST_ENTERED': 'Ingresos a puntos de interés',
  'POINT_OF_INTEREST_EXITED': 'Egresos de puntos de interés',
  'EVENT_CANCELLED': 'Cancelaciones de eventos',
};

class GroupNotificationPreferences {
  final int groupId;
  final String groupName;
  bool enabled;
  final Map<String, bool> types;
  GroupNotificationPreferences({
    required this.groupId,
    required this.groupName,
    required this.enabled,
    required this.types,
  });
  factory GroupNotificationPreferences.fromJson(Map<String, dynamic> json) {
    final values = json['types'] as Map<String, dynamic>? ?? {};
    return GroupNotificationPreferences(
      groupId: json['groupId'] as int,
      groupName: json['groupName'] as String,
      enabled: json['enabled'] as bool? ?? true,
      types: {
        for (final type in notificationTypeLabels.keys)
          type: values[type] as bool? ?? true,
      },
    );
  }
}

class NotificationPreferences {
  bool enabled;
  final List<GroupNotificationPreferences> groups;
  NotificationPreferences({required this.enabled, required this.groups});
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        enabled: json['enabled'] as bool? ?? true,
        groups: (json['groups'] as List<dynamic>)
            .map(
              (item) => GroupNotificationPreferences.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}
