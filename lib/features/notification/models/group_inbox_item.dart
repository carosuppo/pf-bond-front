import '../../group/models/group_join_request.dart';
import 'group_inbox_notification.dart';

class GroupInboxItem {
  const GroupInboxItem({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.notificationId,
    this.joinRequest,
  });

  final String id;
  final int groupId;
  final String groupName;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final int? notificationId;
  final GroupJoinRequest? joinRequest;

  bool get isJoinRequest => joinRequest != null;

  factory GroupInboxItem.fromNotification(GroupInboxNotification item) {
    return GroupInboxItem(
      id: 'notification-${item.id}',
      notificationId: item.id,
      groupId: item.groupId,
      groupName: item.groupName,
      type: item.type,
      title: item.title,
      body: item.body,
      createdAt: item.createdAt,
      isRead: item.readAt != null,
    );
  }

  factory GroupInboxItem.fromJoinRequest(GroupJoinRequest request) {
    return GroupInboxItem(
      id: 'request-${request.id}',
      groupId: request.groupId,
      groupName: request.groupName,
      type: 'GROUP_JOIN_REQUEST',
      title: 'Solicitud de ingreso',
      body: '${request.requesterName} quiere ingresar al grupo',
      createdAt: request.requestedAt,
      isRead: false,
      joinRequest: request,
    );
  }

  GroupInboxItem markRead() {
    return GroupInboxItem(
      id: id,
      groupId: groupId,
      groupName: groupName,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: true,
      notificationId: notificationId,
      joinRequest: joinRequest,
    );
  }
}
