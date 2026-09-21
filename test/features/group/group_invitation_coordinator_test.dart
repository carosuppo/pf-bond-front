import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/models/join_group_model.request.dart';
import 'package:bond_front/features/group/models/join_group_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_invitation_coordinator.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPreferences extends AppPreferencesService {
  String? pendingInvitationCode;
  int? activeGroupId;

  @override
  Future<void> savePendingInvitationCode(String invitationCode) async {
    pendingInvitationCode = invitationCode;
  }

  @override
  Future<String?> getPendingInvitationCode() async => pendingInvitationCode;

  @override
  Future<bool> clearPendingInvitationCode({String? expectedCode}) async {
    if (expectedCode != null && expectedCode != pendingInvitationCode) {
      return false;
    }
    pendingInvitationCode = null;
    return true;
  }

  @override
  Future<void> saveActiveGroupId(int groupId) async {
    activeGroupId = groupId;
  }

  @override
  Future<int?> getActiveGroupId() async => activeGroupId;

  @override
  Future<void> clearActiveGroupId() async {
    activeGroupId = null;
  }
}

class _FakeGroupService extends GroupService {
  _FakeGroupService() : super(ApiClient(SessionStorageService()));

  int joinCalls = 0;
  ApiException? joinError;
  JoinGroupResponseModel response = const JoinGroupResponseModel(
    message: 'Ingresaste al grupo correctamente.',
    group: JoinedGroupResponseModel(id: 12, name: 'Familia'),
  );
  List<GetGroupsResponseModel> availableGroups = [
    GetGroupsResponseModel(id: 12, name: 'Familia'),
  ];

  @override
  Future<JoinGroupResponseModel> joinGroup({
    required JoinGroupRequest request,
  }) async {
    joinCalls++;
    final error = joinError;
    if (error != null) {
      throw error;
    }
    return response;
  }

  @override
  Future<List<GetGroupsResponseModel>> getGroups() async => availableGroups;

  @override
  Future<GetGroupResponseModel> getGroup({required int groupId}) async {
    final group = availableGroups.firstWhere((item) => item.id == groupId);
    return GetGroupResponseModel(
      id: group.id,
      name: group.name,
      shareLocationMandatorily: false,
      invitationCode: 'ABCDEF',
      members: const [],
    );
  }
}

void main() {
  test('pending invitation joins, refreshes, selects, and clears', () async {
    final preferences = _MemoryPreferences()..pendingInvitationCode = 'abc-def';
    final service = _FakeGroupService();
    final provider = GroupProvider(service, preferences);
    final coordinator = GroupInvitationCoordinator(preferences);

    final result = await coordinator.processPendingInvitation(provider);

    expect(result.status, GroupInvitationProcessingStatus.joined);
    expect(service.joinCalls, 1);
    expect(provider.activeGroup?.id, 12);
    expect(provider.groupDetails?.id, 12);
    expect(preferences.activeGroupId, 12);
    expect(preferences.pendingInvitationCode, isNull);
  });

  test(
    'existing member selects the invitation group instead of failing',
    () async {
      final preferences = _MemoryPreferences()
        ..pendingInvitationCode = 'ABCDEF';
      final service = _FakeGroupService()
        ..response = const JoinGroupResponseModel(
          message: 'Ya eres miembro de este grupo.',
          group: JoinedGroupResponseModel(id: 12, name: 'Familia'),
          alreadyMember: true,
        );
      final provider = GroupProvider(service, preferences);

      final result = await GroupInvitationCoordinator(
        preferences,
      ).processPendingInvitation(provider);

      expect(result.status, GroupInvitationProcessingStatus.alreadyMember);
      expect(result.message, 'Ya pertenecés al grupo Familia.');
      expect(provider.activeGroup?.id, 12);
      expect(preferences.pendingInvitationCode, isNull);
    },
  );

  test('two concurrent processors produce only one join request', () async {
    final preferences = _MemoryPreferences()..pendingInvitationCode = 'ABCDEF';
    final service = _FakeGroupService();
    final provider = GroupProvider(service, preferences);
    final coordinator = GroupInvitationCoordinator(preferences);

    final first = coordinator.processPendingInvitation(provider);
    final second = coordinator.processPendingInvitation(provider);
    await Future.wait([first, second]);

    expect(service.joinCalls, 1);
  });

  test(
    'network failure keeps the pending invitation and current group',
    () async {
      final preferences = _MemoryPreferences()
        ..pendingInvitationCode = 'ABCDEF';
      final service = _FakeGroupService()
        ..joinError = const ApiException('Sin red', statusCode: 503);
      final provider = GroupProvider(service, preferences)
        ..groups = [GetGroupsResponseModel(id: 4, name: 'Amigos')]
        ..activeGroup = GetGroupsResponseModel(id: 4, name: 'Amigos');

      final result = await GroupInvitationCoordinator(
        preferences,
      ).processPendingInvitation(provider);

      expect(result.status, GroupInvitationProcessingStatus.retryableFailure);
      expect(preferences.pendingInvitationCode, 'ABCDEF');
      expect(provider.activeGroup?.id, 4);
    },
  );

  test('expired session keeps the invitation for the next login', () async {
    final preferences = _MemoryPreferences()..pendingInvitationCode = 'ABCDEF';
    final service = _FakeGroupService()
      ..joinError = const ApiException('Sesión vencida', statusCode: 401);
    final provider = GroupProvider(service, preferences);

    final result = await GroupInvitationCoordinator(
      preferences,
    ).processPendingInvitation(provider);

    expect(
      result.status,
      GroupInvitationProcessingStatus.authenticationRequired,
    );
    expect(preferences.pendingInvitationCode, 'ABCDEF');
  });

  test('permanent invalid invitation is removed', () async {
    final preferences = _MemoryPreferences()..pendingInvitationCode = 'ABCDEF';
    final service = _FakeGroupService()
      ..joinError = const ApiException('Grupo eliminado', statusCode: 400);
    final provider = GroupProvider(service, preferences);

    final result = await GroupInvitationCoordinator(
      preferences,
    ).processPendingInvitation(provider);

    expect(result.status, GroupInvitationProcessingStatus.invalidInvitation);
    expect(preferences.pendingInvitationCode, isNull);
  });

  test(
    'pending code survives unauthenticated login-register-login flow',
    () async {
      final preferences = _MemoryPreferences();
      await preferences.savePendingInvitationCode('ABCDEF');

      expect(await preferences.getPendingInvitationCode(), 'ABCDEF');
      expect(await preferences.getPendingInvitationCode(), 'ABCDEF');
      expect(await preferences.getPendingInvitationCode(), 'ABCDEF');
    },
  );
}
