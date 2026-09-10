import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_member_model.response.dart';
import 'package:bond_front/features/group/models/update_member_role_model.request.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGroupService extends GroupService {
  _FakeGroupService() : super(ApiClient(SessionStorageService()));

  int? updatedMemberId;
  RoleEnum? updatedRole;

  @override
  Future<void> updateMemberRole({
    required int memberId,
    required RoleEnum role,
  }) async {
    updatedMemberId = memberId;
    updatedRole = role;
  }
}

void main() {
  test('serializes both member roles for the role endpoint', () {
    expect(const UpdateMemberRoleRequest(role: RoleEnum.admin).toJson(), {
      'role': 'ADMIN',
    });
    expect(const UpdateMemberRoleRequest(role: RoleEnum.member).toJson(), {
      'role': 'MEMBER',
    });
  });

  test('maps the membership id returned by the group endpoint', () {
    final member = GetMemberResponseModel.fromJson({
      'id': 17,
      'idUser': 42,
      'name': 'Alex',
      'role': 'MEMBER',
    });

    expect(member.id, 17);
    expect(member.idUser, 42);
    expect(member.role, RoleEnum.member);
  });

  test('updates the selected member role in the active group', () async {
    final service = _FakeGroupService();
    final provider = GroupProvider(service, AppPreferencesService());
    provider.groupDetails = const GetGroupResponseModel(
      id: 1,
      name: 'Grupo',
      description: null,
      shareLocationMandatorily: false,
      invitationCode: 'ABC123',
      members: [
        GetMemberResponseModel(
          id: 17,
          idUser: 42,
          name: 'Alex',
          role: RoleEnum.member,
        ),
      ],
    );

    final success = await provider.updateMemberRole(
      memberId: 17,
      role: RoleEnum.admin,
      isCurrentUserAdmin: true,
    );

    expect(success, isTrue);
    expect(service.updatedMemberId, 17);
    expect(service.updatedRole, RoleEnum.admin);
    expect(provider.groupDetails!.members.single.role, RoleEnum.admin);
  });

  test(
    'does not update a role when the current user is not an admin',
    () async {
      final service = _FakeGroupService();
      final provider = GroupProvider(service, AppPreferencesService());

      final success = await provider.updateMemberRole(
        memberId: 17,
        role: RoleEnum.admin,
        isCurrentUserAdmin: false,
      );

      expect(success, isFalse);
      expect(service.updatedMemberId, isNull);
      expect(
        provider.errorMessage,
        'Solo los administradores pueden modificar los roles.',
      );
    },
  );
}
