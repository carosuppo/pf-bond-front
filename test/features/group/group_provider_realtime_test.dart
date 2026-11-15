import 'dart:async';

import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/models/get_member_model.response.dart';
import 'package:bond_front/features/group/models/group_socket_event.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/group/services/group_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences extends AppPreferencesService {
  int? id = 1;
  @override
  Future<int?> getActiveGroupId() async => id;
  @override
  Future<void> saveActiveGroupId(int groupId) async {
    id = groupId;
  }

  @override
  Future<void> clearActiveGroupId() async {
    id = null;
  }
}

class _Socket extends GroupSocketService {
  _Socket() : super(SessionStorageService());
  final StreamController<GroupSocketEvent> controller =
      StreamController<GroupSocketEvent>.broadcast();
  int connections = 0;
  int disconnections = 0;
  @override
  Stream<GroupSocketEvent> get events => controller.stream;
  @override
  Future<void> connect() async {
    connections++;
  }

  @override
  Future<void> disconnect() async {
    disconnections++;
  }

  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

class _Service extends GroupService {
  _Service() : super(ApiClient(SessionStorageService()));
  List<GetGroupsResponseModel> remote = [
    GetGroupsResponseModel(id: 1, name: 'Familia'),
  ];
  RoleEnum role = RoleEnum.member;
  int requests = 0;
  int detailsRequests = 0;
  Completer<List<GetGroupsResponseModel>>? pending;
  bool fail = false;
  @override
  Future<List<GetGroupsResponseModel>> getGroups() async {
    requests++;
    if (fail) throw Exception('offline');
    return pending == null ? List.of(remote) : pending!.future;
  }

  @override
  Future<GetGroupResponseModel> getGroup({required int groupId}) async {
    detailsRequests++;
    return GetGroupResponseModel(
      id: groupId,
      name: remote
          .firstWhere((GetGroupsResponseModel g) => g.id == groupId)
          .name,
      shareLocationMandatorily: false,
      invitationCode: 'ABC123',
      members: [
        GetMemberResponseModel(id: 8, idUser: 8, name: 'B', role: role),
      ],
    );
  }
}

Future<void> settle() async {
  for (int i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Service service;
  late _Preferences preferences;
  late _Socket socket;
  late GroupProvider provider;
  setUp(() async {
    service = _Service();
    preferences = _Preferences();
    socket = _Socket();
    provider = GroupProvider(service, preferences, null, socket);
    await provider.initialize();
  });
  tearDown(() async {
    provider.dispose();
    await settle();
  });
  test(
    'rename updates list, active group and details without switching groups',
    () async {
      service.remote = [
        GetGroupsResponseModel(id: 2, name: 'Other'),
        GetGroupsResponseModel(id: 1, name: 'Nuevo', image: 'new.png'),
      ];
      socket.controller.add(const GroupsChanged(1, 'updated'));
      await settle();
      expect(provider.groups.length, 2);
      expect(provider.activeGroup?.id, 1);
      expect(provider.activeGroup?.name, 'Nuevo');
      expect(provider.activeGroup?.image, 'new.png');
      expect(provider.groupDetails?.name, 'Nuevo');
      expect(preferences.id, 1);
    },
  );
  test('creation and membership acceptance add authoritative groups', () async {
    service.remote.add(GetGroupsResponseModel(id: 2, name: 'Nuevo'));
    socket.controller.add(const GroupsChanged(2, 'memberAdded'));
    await settle();
    expect(provider.groups.map((GetGroupsResponseModel g) => g.id), [1, 2]);
    expect(provider.activeGroup?.id, 1);
  });
  for (final String reason in ['deleted', 'memberRemoved']) {
    test(
      '$reason removes active group and selects a valid replacement',
      () async {
        service.remote = [GetGroupsResponseModel(id: 2, name: 'Otro')];
        socket.controller.add(GroupsChanged(1, reason));
        await settle();
        expect(provider.groups.single.id, 2);
        expect(provider.activeGroup?.id, 2);
        expect(provider.groupDetails?.id, 2);
        expect(preferences.id, 2);
        service.remote = [];
        socket.controller.add(GroupsChanged(2, reason));
        await settle();
        expect(provider.groups, isEmpty);
        expect(provider.activeGroup, isNull);
        expect(provider.groupDetails, isNull);
        expect(preferences.id, isNull);
      },
    );
  }
  test(
    'reconnect authenticated resyncs missed changes without groupsChanged',
    () async {
      service.remote = [GetGroupsResponseModel(id: 1, name: 'Offline change')];
      socket.controller.add(const GroupSocketAuthenticated());
      await settle();
      expect(provider.activeGroup?.name, 'Offline change');
      expect(service.requests, 2);
      expect(service.detailsRequests, 2);
    },
  );
  test('role changes refresh permissions independently from push', () async {
    for (final RoleEnum role in [RoleEnum.admin, RoleEnum.member]) {
      service.role = role;
      socket.controller.add(const GroupsChanged(1, 'roleChanged'));
      await settle();
      expect(provider.groupDetails?.members.single.role, role);
    }
  });
  test('burst coalesces into a serial follow-up request', () async {
    service.pending = Completer<List<GetGroupsResponseModel>>();
    socket.controller.add(const GroupsChanged(1, 'updated'));
    await settle();
    for (int i = 0; i < 30; i++) {
      socket.controller.add(const GroupsChanged(1, 'updated'));
    }
    await settle();
    expect(service.requests, 2);
    final Completer<List<GetGroupsResponseModel>> pending = service.pending!;
    service.pending = null;
    pending.complete(service.remote);
    await settle();
    expect(service.requests, 3);
  });
  test(
    'logout disconnects, ignores queued REST and supports a new session',
    () async {
      service.pending = Completer<List<GetGroupsResponseModel>>();
      socket.controller.add(const GroupSocketAuthenticated());
      await settle();
      await provider.resetSessionState();
      expect(socket.disconnections, 1);
      service.pending!.complete(service.remote);
      await settle();
      expect(provider.groups, isEmpty);
      expect(provider.activeGroup, isNull);
      service.pending = null;
      service.remote = [GetGroupsResponseModel(id: 4, name: 'New session')];
      await provider.initialize();
      expect(socket.connections, 2);
      expect(provider.groups.single.id, 4);
    },
  );
  test(
    'REST failure preserves data and does not display a blocking error',
    () async {
      service.fail = true;
      socket.controller.add(const GroupSocketAuthenticated());
      await settle();
      expect(provider.groups.single.id, 1);
      expect(provider.errorMessage, isNull);
    },
  );
  test(
    'without an addressed socket event there is no request or list mutation',
    () async {
      service.remote.add(GetGroupsResponseModel(id: 9, name: 'Unrelated'));
      await settle();
      expect(service.requests, 1);
      expect(provider.groups.map((GetGroupsResponseModel g) => g.id), [1]);
    },
  );

  test(
    'invitation entry starts one socket even when initialize is bypassed',
    () async {
      await provider.resetSessionState();
      expect(await provider.refreshAndSelectGroup(groupId: 1), isTrue);
      expect(socket.connections, 2);
      await provider.refreshAndSelectGroup(groupId: 1);
      expect(socket.connections, 2);
    },
  );
  test('failed invalidation retries and restores authoritative data', () async {
    service.fail = true;
    socket.controller.add(const GroupsChanged(1, 'updated'));
    await settle();
    service.fail = false;
    service.remote = [GetGroupsResponseModel(id: 1, name: 'Recovered')];
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await settle();
    expect(provider.activeGroup?.name, 'Recovered');
  });
}
