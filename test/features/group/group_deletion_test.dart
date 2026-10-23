import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/models/get_member_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences extends AppPreferencesService {
  int? savedGroupId;
  bool cleared = false;

  @override
  Future<int?> getActiveGroupId() async => savedGroupId;

  @override
  Future<void> clearActiveGroupId() async {
    cleared = true;
    savedGroupId = null;
  }
}

class _GroupService extends GroupService {
  _GroupService() : super(ApiClient(SessionStorageService()));

  int? deletedGroupId;

  @override
  Future<void> deleteGroup({required int groupId}) async {
    deletedGroupId = groupId;
  }
}

GroupProvider _provider(_GroupService service, _Preferences preferences) {
  return GroupProvider(service, preferences)
    ..groups = [
      GetGroupsResponseModel(id: 1, name: 'Grupo eliminado'),
      GetGroupsResponseModel(id: 2, name: 'Otro grupo'),
    ]
    ..activeGroup = GetGroupsResponseModel(id: 1, name: 'Grupo eliminado')
    ..groupDetails = const GetGroupResponseModel(
      id: 1,
      name: 'Grupo eliminado',
      shareLocationMandatorily: false,
      invitationCode: 'ABC123',
      members: [
        GetMemberResponseModel(
          id: 10,
          idUser: 1,
          name: 'Admin',
          role: RoleEnum.admin,
        ),
      ],
    );
}

void main() {
  test(
    'elimina el grupo de la sesión activa tras confirmar con el backend',
    () async {
      final service = _GroupService();
      final preferences = _Preferences()..savedGroupId = 1;
      final provider = _provider(service, preferences);

      final success = await provider.deleteGroup(
        groupId: 1,
        isCurrentUserAdmin: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(success, isTrue);
      expect(service.deletedGroupId, 1);
      expect(provider.groups.map((group) => group.id), [2]);
      expect(provider.activeGroup, isNull);
      expect(provider.groupDetails, isNull);
      expect(preferences.cleared, isTrue);
    },
  );

  test(
    'actualiza inmediatamente la sesión al recibir eliminación remota',
    () async {
      final preferences = _Preferences()..savedGroupId = 1;
      final provider = _provider(_GroupService(), preferences);

      provider.handleGroupDeleted(1);
      await Future<void>.delayed(Duration.zero);

      expect(provider.groups.map((group) => group.id), [2]);
      expect(provider.activeGroup, isNull);
      expect(provider.groupDetails, isNull);
      expect(preferences.cleared, isTrue);
    },
  );

  test(
    'rechaza la eliminación desde el provider para miembros no admin',
    () async {
      final service = _GroupService();
      final provider = _provider(service, _Preferences());

      final success = await provider.deleteGroup(
        groupId: 1,
        isCurrentUserAdmin: false,
      );

      expect(success, isFalse);
      expect(service.deletedGroupId, isNull);
      expect(provider.activeGroup?.id, 1);
      expect(
        provider.errorMessage,
        'Solo los administradores pueden eliminar el grupo.',
      );
    },
  );
}
