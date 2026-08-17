import '../../../core/network/api_client.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';
import '../models/group_model.response.dart';
import '../models/join_group_model.request.dart';
import '../models/join_group_model.response.dart';
import '../models/update_group_model.request.dart';

class GroupService {
  final ApiClient _apiClient;

  GroupService(this._apiClient);

  Future<CreateGroupResponseModel> createGroup({
    required CreateGroupRequest request,
    required int userId,
  }) async {
    final response = await _apiClient.post('/group/$userId', request.toJson());

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
    required String groupId,
    required UpdateGroupRequest request,
  }) async {
    // Temporal hasta que exista el endpoint en backend.
    // Endpoint esperado a futuro:
    // final response = await _apiClient.patch('/group/$groupId', request.toJson());
    // return GroupResponseModel.fromJson(response);

    await Future.delayed(const Duration(milliseconds: 500));

    return GroupResponseModel(
      id: groupId,
      name: request.name,
      description: request.description,
      shareLocationMandatorily: request.shareLocationMandatorily,
    );
  }
}
