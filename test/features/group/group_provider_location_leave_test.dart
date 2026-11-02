import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Preferences extends AppPreferencesService {
  int? savedGroupId;
  bool cleared = false;

  @override
  Future<void> saveActiveGroupId(int groupId) async {
    savedGroupId = groupId;
  }

  @override
  Future<void> clearActiveGroupId() async {
    cleared = true;
  }
}

class _GroupService extends GroupService {
  _GroupService() : super(ApiClient(SessionStorageService()));

  int? leftGroupId;
  final availableGroups = [GetGroupsResponseModel(id: 2, name: 'Opcional')];

  @override
  Future<void> leaveGroup({required int groupId}) async {
    leftGroupId = groupId;
  }

  @override
  Future<List<GetGroupsResponseModel>> getGroups() async => availableGroups;

  @override
  Future<GetGroupResponseModel> getGroup({required int groupId}) async =>
      const GetGroupResponseModel(
        id: 2,
        name: 'Opcional',
        shareLocationMandatorily: false,
        invitationCode: 'ABCDEF',
        members: [],
      );
}

class _FailingGroupService extends _GroupService {
  @override
  Future<void> leaveGroup({required int groupId}) async {
    throw const ApiException('Cannot DELETE /group/1/leave', statusCode: 404);
  }
}

void main() {
  test('actualiza el grupo activo al salir de uno obligatorio', () async {
    final service = _GroupService();
    final preferences = _Preferences();
    final provider = GroupProvider(service, preferences)
      ..groups = [
        GetGroupsResponseModel(id: 1, name: 'Obligatorio'),
        ...service.availableGroups,
      ]
      ..activeGroup = GetGroupsResponseModel(id: 1, name: 'Obligatorio')
      ..groupDetails = const GetGroupResponseModel(
        id: 1,
        name: 'Obligatorio',
        shareLocationMandatorily: true,
        invitationCode: 'GHIJKL',
        members: [],
      );

    final success = await provider.leaveGroupForLocationPermission(1);

    expect(success, isTrue);
    expect(service.leftGroupId, 1);
    expect(provider.groups.map((group) => group.id), [2]);
    expect(provider.activeGroup?.id, 2);
    expect(provider.groupDetails?.id, 2);
    expect(preferences.savedGroupId, 2);
  });

  test('no muestra rutas del servidor si falla la salida del grupo', () async {
    final provider = GroupProvider(_FailingGroupService(), _Preferences());

    final success = await provider.leaveGroupForLocationPermission(1);

    expect(success, isFalse);
    expect(
      provider.errorMessage,
      'No se pudo salir del grupo. Intentá de nuevo.',
    );
  });
}
