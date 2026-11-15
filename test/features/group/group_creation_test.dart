import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/routes/app_routes.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/core/widgets/buttons/app_primary_button.dart';
import 'package:bond_front/features/group/models/create_group_model.request.dart';
import 'package:bond_front/features/group/models/create_group_model.response.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/models/group_socket_event.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/screens/groups_screen.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/group/services/group_socket_service.dart';
import 'package:bond_front/features/group/widgets/create_group_form.dart';
import 'package:bond_front/features/group/widgets/invitation_code_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends AppPreferencesService {
  int? id;
  int failures = 0;
  final List<int> writes = [];
  @override
  Future<int?> getActiveGroupId() async => id;
  @override
  Future<void> clearActiveGroupId() async => id = null;
  @override
  Future<void> saveActiveGroupId(int groupId) async {
    if (failures > 0) {
      failures--;
      throw Exception('storage unavailable');
    }
    writes.add(groupId);
    id = groupId;
  }
}

class _Socket extends GroupSocketService {
  _Socket() : super(SessionStorageService());
  final StreamController<GroupSocketEvent> controller =
      StreamController<GroupSocketEvent>.broadcast(sync: true);
  @override
  Stream<GroupSocketEvent> get events => controller.stream;
  @override
  Future<void> connect() async {}
  @override
  Future<void> dispose() => controller.close();
}

class _Service extends GroupService {
  _Service() : super(ApiClient(SessionStorageService()));
  List<GetGroupsResponseModel> remote = [];
  int lists = 0;
  int posts = 0;
  int detailFailures = 0;
  bool failCreate = false;
  Completer<List<GetGroupsResponseModel>>? pendingList;
  Completer<GetGroupResponseModel>? pendingDetails;
  final List<int> detailIds = [];
  @override
  Future<List<GetGroupsResponseModel>> getGroups() async {
    lists++;
    return pendingList == null ? List.of(remote) : pendingList!.future;
  }

  @override
  Future<CreateGroupResponseModel> createGroup({
    required CreateGroupRequest request,
  }) async {
    posts++;
    if (failCreate) throw Exception('POST failed');
    remote = [...remote, GetGroupsResponseModel(id: 2, name: request.name)];
    return CreateGroupResponseModel(
      id: 2,
      name: request.name,
      shareLocationMandatorily: request.shareLocationMandatorily,
      invitationCode: 'ABC123',
      description: request.description,
    );
  }

  @override
  Future<GetGroupResponseModel> getGroup({required int groupId}) async {
    detailIds.add(groupId);
    if (detailFailures > 0) {
      detailFailures--;
      throw Exception('details unavailable');
    }
    if (pendingDetails != null) return pendingDetails!.future;
    return details(groupId);
  }

  GetGroupResponseModel details(int id) => GetGroupResponseModel(
    id: id,
    name: id == 2 ? 'Trabajo' : 'Familia',
    shareLocationMandatorily: false,
    invitationCode: 'ABC123',
    members: [],
  );
}

// Drain queued Futures without wall-clock sleeps or retry timers.
Future<void> settle() async {
  for (int i = 0; i < 60; i++) {
    await Future<void>.value();
  }
}

void main() {
  late _Service service;
  late _Preferences preferences;
  late _Socket socket;
  late GroupProvider provider;
  setUp(() {
    service = _Service();
    preferences = _Preferences();
    socket = _Socket();
    provider = GroupProvider(service, preferences, null, socket);
  });
  tearDown(() => provider.dispose());
  Future<void> existingGroup() async {
    service.remote = [GetGroupsResponseModel(id: 1, name: 'Familia')];
    preferences.id = 1;
    await provider.initialize();
  }

  Future<bool> create() =>
      provider.createGroup(name: 'Trabajo', shareLocationMandatorily: false);

  test(
    'first creation selects, persists and loads details without a list request',
    () async {
      expect(await create(), isTrue);
      expect(provider.group?.id, 2);
      expect(provider.activeGroup?.id, 2);
      expect(provider.groups.single.id, 2);
      expect(provider.groupDetails?.id, 2);
      expect(preferences.writes, [2]);
      expect(service.lists, 0);
      expect(service.detailIds, [2]);
      expect(provider.isInitialized, isTrue);
      await provider.initialize();
      expect(provider.activeGroup?.id, 2);
      expect(service.lists, 0);
    },
  );
  test(
    'second creation replaces selection and consumers see new details',
    () async {
      await existingGroup();
      final List<int?> observed = [];
      provider.addListener(() => observed.add(provider.activeGroup?.id));
      expect(await create(), isTrue);
      expect(provider.groups.map((g) => g.id), [1, 2]);
      expect(provider.activeGroup?.id, 2);
      expect(provider.groupDetails?.id, 2);
      expect(preferences.id, 2);
      expect(observed.last, 2);
      expect(service.lists, 1);
      await provider.selectGroup(provider.groups.first);
      expect(provider.activeGroup?.id, 1);
      expect(provider.groupDetails?.id, 1);
      expect(preferences.id, 1);
    },
  );
  test(
    'failed POST preserves list, selection, details and stored preference',
    () async {
      await existingGroup();
      final List<GetGroupsResponseModel> before = provider.groups;
      final GetGroupsResponseModel? active = provider.activeGroup;
      final GetGroupResponseModel? details = provider.groupDetails;
      service.failCreate = true;
      expect(await create(), isFalse);
      expect(provider.groups, same(before));
      expect(provider.activeGroup, same(active));
      expect(provider.groupDetails, same(details));
      expect(preferences.id, 1);
      expect(preferences.writes, isEmpty);
      expect(service.detailIds, [1]);
    },
  );
  for (final bool storageFailure in [true, false]) {
    test(
      'successful POST survives secondary ${storageFailure ? 'storage' : 'details'} failure and reconciles',
      () async {
        await existingGroup();
        if (storageFailure) {
          preferences.failures = 1;
        } else {
          service.detailFailures = 1;
        }
        expect(await create(), isTrue);
        expect(provider.group?.id, 2);
        await settle();
        expect(service.posts, 1);
        expect(provider.activeGroup?.id, 2);
        expect(provider.groupDetails?.id, 2);
        expect(provider.groups.map((g) => g.id), [1, 2]);
        expect(preferences.id, 2);
        expect(provider.errorMessage, isNull);
      },
    );
  }
  test(
    'stale realtime list cannot undo creation; repeated events are idempotent',
    () async {
      await existingGroup();
      final Completer<List<GetGroupsResponseModel>> pending = Completer();
      service.pendingList = pending;
      socket.controller.add(const GroupSocketAuthenticated());
      await settle();
      expect(await create(), isTrue);
      final List<int?> observed = [];
      provider.addListener(() => observed.add(provider.activeGroup?.id));
      service.pendingList = null;
      pending.complete([GetGroupsResponseModel(id: 1, name: 'Familia')]);
      await settle();
      for (int i = 0; i < 3; i++) {
        socket.controller.add(const GroupsChanged(2, 'created'));
      }
      await settle();
      expect(provider.groups.map((g) => g.id), [1, 2]);
      expect(observed, everyElement(2));
      expect(provider.activeGroup?.id, 2);
      expect(provider.groupDetails?.id, 2);
      expect(preferences.id, 2);
    },
  );
  test(
    'initialize already in flight cannot restore the previous group',
    () async {
      final Completer<List<GetGroupsResponseModel>> pending = Completer();
      service.pendingList = pending;
      final Future<void> initializing = provider.initialize();
      expect(await create(), isTrue);
      service.pendingList = null;
      pending.complete([]);
      await initializing;
      expect(provider.activeGroup?.id, 2);
      expect(provider.groupDetails?.id, 2);
      expect(preferences.id, 2);
    },
  );
  test('old details cannot replace details of the created group', () async {
    await existingGroup();
    final Completer<GetGroupResponseModel> pending = Completer();
    service.pendingDetails = pending;
    final Future<bool> loading = provider.getGroupDetails(groupId: 1);
    service.pendingDetails = null;
    expect(await create(), isTrue);
    pending.complete(service.details(1));
    expect(await loading, isFalse);
    expect(provider.groupDetails?.id, 2);
  });
  for (final bool firstGroup in [true, false]) {
    testWidgets(
      'form modal and navigation keep created group active (first=$firstGroup)',
      (tester) async {
        provider.dispose();
        service = _Service();
        preferences = _Preferences();
        socket = _Socket();
        provider = GroupProvider(service, preferences, null, socket);
        tester.view.physicalSize = const Size(600, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (!firstGroup) await existingGroup();
        await tester.pumpWidget(
          ChangeNotifierProvider<GroupProvider>.value(
            value: provider,
            child: MaterialApp(
              home: firstGroup
                  ? const GroupsScreen()
                  : Builder(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.createGroup,
                          ),
                          child: const Text('Nuevo'),
                        ),
                      ),
                    ),
              routes: {
                AppRoutes.createGroup: (_) =>
                    const Scaffold(body: CreateGroupForm()),
                AppRoutes.map: (_) => const Scaffold(body: Text('Mapa')),
              },
            ),
          ),
        );
        await tester.tap(find.text(firstGroup ? 'Crear un grupo' : 'Nuevo'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Trabajo');
        await tester.tap(find.byType(AppPrimaryButton));
        await tester.pumpAndSettle();
        final InvitationCodeModal modal = tester.widget(
          find.byType(InvitationCodeModal),
        );
        expect(modal.groupName, 'Trabajo');
        expect(modal.invitationCode, 'ABC123');
        expect(provider.activeGroup?.id, 2);
        await tester.tap(find.text('Listo'));
        await tester.pumpAndSettle();
        expect(find.byType(CreateGroupForm), findsNothing);
        expect(find.text(firstGroup ? 'Mapa' : 'Nuevo'), findsOneWidget);
        expect(provider.activeGroup?.id, 2);
        expect(preferences.id, 2);
        expect(service.lists, firstGroup ? 0 : 1);
        expect(service.detailIds, firstGroup ? [2] : [1, 2]);
      },
    );
  }
}
