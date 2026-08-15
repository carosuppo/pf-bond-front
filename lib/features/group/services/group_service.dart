import '../../../core/network/api_client.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/group_model.response.dart';
import '../models/update_group_model.request.dart';

class GroupService {
  final ApiClient _apiClient;

  GroupService(this._apiClient);

  Future<List<GroupResponseModel>> getGroups() async {
    final response = await _apiClient.authenticatedGetList('/group');

    return response
        .map(GroupResponseModel.fromJson)
        .toList(growable: false);
  }

  Future<CreateGroupResponseModel> createGroup({
    required CreateGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPost(
      '/group',
      request.toJson(),
    );

    return CreateGroupResponseModel.fromJson(response);
  }

  Future<GroupResponseModel> updateGroup({
    required String groupId,
    required UpdateGroupRequest request,
  }) async {
    final response = await _apiClient.authenticatedPut(
      '/group/$groupId',
      request.toJson(),
    );

    return GroupResponseModel.fromJson(response);
  }
}
