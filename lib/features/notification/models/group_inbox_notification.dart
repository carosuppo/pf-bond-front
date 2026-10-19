class GroupInboxNotification {
  const GroupInboxNotification({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final int id;
  final int groupId;
  final String groupName;
  final String type;
  final String title;
  final String body;
  final Map<String, String> data;
  final DateTime? readAt;
  final DateTime createdAt;

  factory GroupInboxNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = rawData is Map
        ? rawData.map<String, String>(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    final rawReadAt = json['readAt'];

    return GroupInboxNotification(
      id: json['id'] as int,
      groupId: json['groupId'] as int,
      groupName: json['groupName'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: data,
      readAt: rawReadAt is String ? DateTime.tryParse(rawReadAt) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
