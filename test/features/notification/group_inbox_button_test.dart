import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/notification/models/group_inbox_item.dart';
import 'package:bond_front/features/notification/providers/group_inbox_provider.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/widgets/group_inbox_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _NotificationService extends NotificationApiService {
  _NotificationService() : super(ApiClient(SessionStorageService()));
}

class _GroupService extends GroupService {
  _GroupService() : super(ApiClient(SessionStorageService()));
}

void main() {
  testWidgets('shows a small dot while there are unread inbox items', (
    tester,
  ) async {
    final provider = GroupInboxProvider(_NotificationService(), _GroupService())
      ..items = [
        GroupInboxItem(
          id: 'notification-1',
          notificationId: 1,
          groupId: 4,
          groupName: 'Familia',
          type: 'EVENT_UPDATED',
          title: 'Evento actualizado',
          body: 'Se modificó el evento.',
          createdAt: DateTime(2026),
          isRead: false,
        ),
      ];

    await tester.pumpWidget(
      ChangeNotifierProvider<GroupInboxProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: GroupInboxButton())),
      ),
    );

    expect(
      find.byKey(const Key('group-inbox-unread-indicator')),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Buzón de entrada con notificaciones sin leer'),
      findsOneWidget,
    );

    provider.items = [provider.items.single.markRead()];
    provider.notifyListeners();
    await tester.pump();

    expect(find.byKey(const Key('group-inbox-unread-indicator')), findsNothing);
    expect(find.byTooltip('Buzón de entrada'), findsOneWidget);
  });
}
