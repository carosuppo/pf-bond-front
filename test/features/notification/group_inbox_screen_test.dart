import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/group_join_request.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/notification/models/group_inbox_notification.dart';
import 'package:bond_front/features/notification/providers/group_inbox_provider.dart';
import 'package:bond_front/features/notification/screens/group_inbox_screen.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _NotificationService extends NotificationApiService {
  _NotificationService() : super(ApiClient(SessionStorageService()));

  List<GroupInboxNotification> notifications = [];
  final List<int> readIds = [];

  @override
  Future<List<GroupInboxNotification>> getInbox() async => notifications;

  @override
  Future<void> markInboxNotificationRead(int notificationId) async {
    readIds.add(notificationId);
  }
}

class _GroupService extends GroupService {
  _GroupService() : super(ApiClient(SessionStorageService()));

  final List<int> acceptedIds = [];
  final List<int> rejectedIds = [];
  List<GroupJoinRequest> requests = [];

  @override
  Future<List<GroupJoinRequest>> getJoinRequests() async => requests;

  @override
  Future<void> acceptJoinRequest({required int requestId}) async {
    acceptedIds.add(requestId);
    requests = [];
  }

  @override
  Future<void> rejectJoinRequest({required int requestId}) async {
    rejectedIds.add(requestId);
    requests = [];
  }
}

GroupJoinRequest _request() => GroupJoinRequest(
  id: 12,
  groupId: 3,
  groupName: 'Familia',
  requesterUserId: 7,
  requesterName: 'Bruno',
  requesterProfilePhoto: null,
  requestedAt: DateTime(2026, 10, 9),
);

void main() {
  test('combina notificaciones del grupo con solicitudes pendientes', () async {
    final notifications = _NotificationService()
      ..notifications = [
        GroupInboxNotification(
          id: 5,
          groupId: 3,
          groupName: 'Familia',
          type: 'EVENT_UPDATED',
          title: 'Evento actualizado',
          body: 'Se modificó el evento.',
          data: const {},
          readAt: DateTime(2026, 10, 9),
          createdAt: DateTime(2026, 10, 8),
        ),
      ];
    final groups = _GroupService()..requests = [_request()];
    final provider = GroupInboxProvider(notifications, groups);

    await provider.load();

    expect(provider.items, hasLength(2));
    expect(provider.items.first.isJoinRequest, isTrue);
    expect(provider.items.last.title, 'Evento actualizado');
    expect(provider.unreadCount, 1);
  });

  testWidgets('marca como vistas las notificaciones al abrir el buzón', (
    tester,
  ) async {
    final notifications = _NotificationService()
      ..notifications = [
        GroupInboxNotification(
          id: 5,
          groupId: 3,
          groupName: 'Familia',
          type: 'EVENT_UPDATED',
          title: 'Evento actualizado',
          body: 'Se modificó el evento.',
          data: const {},
          readAt: null,
          createdAt: DateTime(2026, 10, 8),
        ),
        GroupInboxNotification(
          id: 6,
          groupId: 3,
          groupName: 'Familia',
          type: 'EVENT_CREATED',
          title: 'Nuevo evento',
          body: 'Se creó un evento.',
          data: const {},
          readAt: DateTime(2026, 10, 9),
          createdAt: DateTime(2026, 10, 9),
        ),
      ];
    final provider = GroupInboxProvider(notifications, _GroupService());

    await tester.pumpWidget(
      ChangeNotifierProvider<GroupInboxProvider>.value(
        value: provider,
        child: const MaterialApp(home: GroupInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(notifications.readIds, [5]);
    expect(provider.items.every((item) => item.isRead), isTrue);
    expect(provider.unreadCount, 0);
  });

  testWidgets('muestra la solicitud y permite rechazarla desde el modal', (
    tester,
  ) async {
    final groups = _GroupService()..requests = [_request()];
    final provider = GroupInboxProvider(_NotificationService(), groups);
    await provider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<GroupInboxProvider>.value(
        value: provider,
        child: const MaterialApp(home: GroupInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bruno quiere ingresar al grupo'),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('Bruno quiere ingresar al grupo'));
    await tester.pumpAndSettle();

    expect(find.text('Solicitud para Familia'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);

    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();

    expect(groups.rejectedIds, [12]);
    expect(groups.acceptedIds, isEmpty);
    expect(find.text('No hay notificaciones de tus grupos.'), findsOneWidget);
  });

  testWidgets('acepta la solicitud desde el modal', (tester) async {
    final groups = _GroupService()..requests = [_request()];
    final provider = GroupInboxProvider(_NotificationService(), groups);
    await provider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<GroupInboxProvider>.value(
        value: provider,
        child: const MaterialApp(home: GroupInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bruno quiere ingresar al grupo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(groups.acceptedIds, [12]);
    expect(groups.rejectedIds, isEmpty);
    expect(find.text('Solicitud aceptada.'), findsOneWidget);
  });
}
