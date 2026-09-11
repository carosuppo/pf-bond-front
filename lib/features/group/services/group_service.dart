import '../../../core/network/api_client.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/get_group_model.response.dart';
import '../models/get_member_info_model.response.dart';
import '../models/get_groups_model.response.dart';
import '../models/get_member_model.response.dart';
import '../models/group_model.response.dart';
import '../models/join_group_model.request.dart';
import '../models/join_group_model.response.dart';
import '../models/update_group_model.request.dart';
import '../models/update_member_role_model.request.dart';

class GroupService {
  final ApiClient _apiClient;

  GroupService(this._apiClient);

  Future<CreateGroupResponseModel> createGroup({
    required CreateGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group',
      request.toJson(),
    );
    return CreateGroupResponseModel.fromJson(response);
  }

  Future<JoinGroupResponseModel> joinGroup({
    required JoinGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group/join',
      request.toJson(),
    );

    return JoinGroupResponseModel.fromJson(response);
  }

  Future<GroupResponseModel> updateGroup({
    required int groupId,
    required UpdateGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPut(
      '/group/$groupId',
      request.toJson(),
    );
    return GroupResponseModel.fromJson(response);
  }

  Future<void> updateMemberRole({
    required int memberId,
    required RoleEnum role,
  }) async {
    final request = UpdateMemberRoleRequest(role: role);

    await _apiClient.authenticatedPut(
      '/member/$memberId/role',
      request.toJson(),
    );
  }

  Future<List<GetGroupsResponseModel>> getGroups() async {
    final response = await _apiClient.authenticatedGetList('/group');

    return response.map(GetGroupsResponseModel.fromJson).toList();
  }

  Future<GetGroupResponseModel> getGroup({required int groupId}) async {
    final response = await _apiClient.authenticatedGet('/group/$groupId');

    return GetGroupResponseModel.fromJson(response);
  }

  Future<GetMemberInfoResponseModel> getMemberInfo({
    required int memberId,
  }) async {
    final response = await _apiClient.authenticatedGet('/member/$memberId');

    return GetMemberInfoResponseModel.fromJson(response);
  }
}
