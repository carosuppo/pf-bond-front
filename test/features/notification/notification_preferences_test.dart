import 'dart:async';
import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/notification/models/notification_preferences.dart';
import 'package:bond_front/features/notification/models/push_notification_data.dart';
import 'package:bond_front/features/notification/providers/notification_preferences_provider.dart';
import 'package:bond_front/features/notification/screens/notification_preferences_screen.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> response() => {
  'enabled': true,
  'groups': [
    {
      'groupId': 3,
      'groupName': 'Familia',
      'enabled': true,
      'types': {'POINT_OF_INTEREST_CREATED': false},
    },
  ],
};

class FakeApi extends ApiClient {
  FakeApi() : super(SessionStorageService());
  Map<String, dynamic> data = response();
  final requests = <String>[];
  Object? error;
  Completer<void>? pending;
  @override
  Future<Map<String, dynamic>> authenticatedGet(String path) async {
    if (error != null) throw error!;
    return data;
  }

  @override
  Future<Map<String, dynamic>> authenticatedPatch(
    String path,
    Map<String, dynamic> body,
  ) async {
    requests.add('$path:${body.toString()}');
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
    return body;
  }
}

void main() {
  late FakeApi api;
  late NotificationPreferencesProvider state;
  setUp(() async {
    api = FakeApi();
    state = NotificationPreferencesProvider(NotificationApiService(api));
    await state.load();
  });
  tearDown(() => state.dispose());

  test('parses current groups, defaults missing types to enabled', () {
    final data = NotificationPreferences.fromJson(response());
    expect(data.enabled, isTrue);
    expect(data.groups.single.groupId, 3);
    expect(data.groups.single.types['POINT_OF_INTEREST_CREATED'], isFalse);
    expect(data.groups.single.types['POINT_OF_INTEREST_EXITED'], isTrue);
  });
  test('global switch persists and preserves type preferences', () async {
    final types = Map.of(state.preferences!.groups.single.types);
    expect(await state.setGlobal(false), isTrue);
    expect(state.preferences!.enabled, isFalse);
    expect(state.preferences!.groups.single.types, types);
    await state.setGlobal(true);
    expect(state.preferences!.groups.single.types, types);
    expect(api.requests.first, contains('/notification/preferences/global'));
  });
  test(
    'group mute preserves type preferences and disables type updates',
    () async {
      final group = state.preferences!.groups.single;
      final types = Map.of(group.types);
      await state.setGroup(group, false);
      expect(group.enabled, isFalse);
      expect(
        await state.setType(group, 'POINT_OF_INTEREST_EXITED', false),
        isFalse,
      );
      await state.setGroup(group, true);
      expect(group.types, types);
      expect(
        api.requests.first,
        contains('/notification/preferences/group/3:'),
      );
    },
  );
  for (final type in notificationTypeLabels.keys) {
    test('persists toggle $type', () async {
      final group = state.preferences!.groups.single;
      final value = !group.types[type]!;
      expect(await state.setType(group, type, value), isTrue);
      expect(group.types[type], value);
      expect(api.requests.single, contains('/group/3/type'));
      expect(api.requests.single, contains(type));
    });
  }
  test('HTTP error rolls back global, group and type toggles', () async {
    final group = state.preferences!.groups.single;
    api.error = Exception('HTTP 500');
    expect(await state.setGlobal(false), isFalse);
    expect(state.preferences!.enabled, isTrue);
    expect(await state.setGroup(group, false), isFalse);
    expect(group.enabled, isTrue);
    expect(
      await state.setType(group, 'POINT_OF_INTEREST_ENTERED', false),
      isFalse,
    );
    expect(group.types['POINT_OF_INTEREST_ENTERED'], isTrue);
    expect(state.errorMessage, contains('HTTP 500'));
  });
  test('rapid double tap sends only one request', () async {
    api.pending = Completer<void>();
    final first = state.setGlobal(false);
    expect(state.isSaving, isTrue);
    expect(await state.setGlobal(true), isFalse);
    expect(api.requests, hasLength(1));
    api.pending!.complete();
    await first;
    expect(state.preferences!.enabled, isFalse);
  });
  test(
    'refresh replaces groups so previous memberships are not shown',
    () async {
      api.data = {'enabled': true, 'groups': <dynamic>[]};
      await state.load();
      expect(state.preferences!.groups, isEmpty);
    },
  );
  for (final type in [
    'POINT_OF_INTEREST_ENTERED',
    'POINT_OF_INTEREST_EXITED',
  ]) {
    test('parses and round trips $type and memberUserId', () {
      final data = PushNotificationData.fromMap({
        'type': type,
        'groupId': '3',
        'pointOfInterestId': '8',
        'memberUserId': 7,
      });
      expect(data.type, type);
      expect(data.memberUserId, '7');
      expect(PushNotificationData.fromMap(data.toMap()).memberUserId, '7');
    });
  }
  testWidgets('general screen disables group interaction when globally muted', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: NotificationPreferencesScreen()),
      ),
    );
    expect(find.text('Familia'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(state.preferences!.enabled, isFalse);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Familia')).enabled,
      isFalse,
    );
  });
  testWidgets('group screen keeps specific switch values while disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: GroupNotificationPreferencesScreen(groupId: 3),
        ),
      ),
    );
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    final switches = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(switches.first.value, isFalse);
    expect(switches[1].value, isFalse);
    expect(switches[2].value, isTrue);
    expect(switches.skip(1).every((item) => item.onChanged == null), isTrue);
  });
  testWidgets('load error offers retry', (tester) async {
    state.preferences = null;
    api.error = Exception('HTTP unavailable');
    await state.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: NotificationPreferencesScreen()),
      ),
    );
    expect(find.text('Reintentar'), findsOneWidget);
    api.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Familia'), findsOneWidget);
  });
}
