import '../../../core/network/api_client.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/get_group_model.response.dart';
import '../models/get_groups_model.response.dart';
import '../models/group_model.response.dart';
import '../models/join_group_model.request.dart';
import '../models/join_group_model.response.dart';
import '../models/update_group_model.request.dart';

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

  Future<List<GetGroupsResponseModel>> getGroups() async {
    final response = await _apiClient.authenticatedGetList('/group');

    return response
        .map(
          (json) =>
              GetGroupsResponseModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<GetGroupResponseModel> getGroup({required int groupId}) async {
    final response = await _apiClient.authenticatedGet('/group/$groupId');

    return GetGroupResponseModel.fromJson(response);
  }
}
