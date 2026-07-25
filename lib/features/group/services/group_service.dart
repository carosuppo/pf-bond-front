import '../../../core/network/api_client.dart';
import '../models/create_group_model.request.dart';
import '../models/create_group_model.response.dart';

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
}
