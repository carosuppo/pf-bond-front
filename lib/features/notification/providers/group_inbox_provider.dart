import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../group/services/group_service.dart';
import '../models/group_inbox_item.dart';
import '../services/notification_api_service.dart';

class GroupInboxProvider extends ChangeNotifier {
  GroupInboxProvider(this._notificationService, this._groupService);

  final NotificationApiService _notificationService;
  final GroupService _groupService;

  List<GroupInboxItem> items = [];
  bool isLoading = false;
  bool isProcessing = false;
  String? errorMessage;
  bool _reloadRequested = false;
  bool _markAllNotificationsReadOnLoad = false;

  int get unreadCount => items.where((item) => !item.isRead).length;

  Future<void> load({bool markAllNotificationsRead = false}) async {
    if (markAllNotificationsRead) _markAllNotificationsReadOnLoad = true;

    if (isLoading) {
      _reloadRequested = true;
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final notificationsFuture = _notificationService.getInbox();
      final requestsFuture = _groupService.getJoinRequests();
      final notifications = await notificationsFuture;
      final requests = await requestsFuture;
      items = [
        ...notifications.map(GroupInboxItem.fromNotification),
        ...requests.map(GroupInboxItem.fromJoinRequest),
      ]..sort((first, second) => second.createdAt.compareTo(first.createdAt));

      if (_markAllNotificationsReadOnLoad) {
        _markAllNotificationsReadOnLoad = false;
        await Future.wait(
          items
              .where((item) => item.notificationId != null && !item.isRead)
              .map(markRead),
        );
      }
    } catch (_) {
      if (!_reloadRequested) _markAllNotificationsReadOnLoad = false;
      errorMessage = 'No se pudo cargar el buzón. Intentá de nuevo.';
    } finally {
      isLoading = false;
      notifyListeners();
      if (_reloadRequested) {
        _reloadRequested = false;
        unawaited(load());
      }
    }
  }

  Future<bool> markRead(GroupInboxItem item) async {
    final notificationId = item.notificationId;
    if (notificationId == null || item.isRead) return true;

    try {
      await _notificationService.markInboxNotificationRead(notificationId);
      items = items
          .map(
            (current) => current.id == item.id ? current.markRead() : current,
          )
          .toList(growable: false);
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'No se pudo actualizar la notificación. Intentá de nuevo.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> respondToRequest({
    required int requestId,
    required bool accept,
  }) async {
    isProcessing = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (accept) {
        await _groupService.acceptJoinRequest(requestId: requestId);
      } else {
        await _groupService.rejectJoinRequest(requestId: requestId);
      }
      await load();
      return true;
    } catch (_) {
      errorMessage = 'No se pudo resolver la solicitud. Intentá de nuevo.';
      return false;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }
}
