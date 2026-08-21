import '../../../core/network/api_client.dart';
import '../../auth/models/user_model.dart';
import '../models/update_profile_request.dart';

class ProfileService {
  final ApiClient _apiClient;

  ProfileService(this._apiClient);

  Future<UserModel> getCurrentUser() async {
    final json = await _apiClient.authenticatedGet('/user/me');

    return UserModel.fromJson(json);
  }

  Future<UserModel> updateCurrentUser(UpdateProfileRequest request) async {
    final json = await _apiClient.authenticatedPatch(
      '/user/me',
      request.toJson(),
    );

    return UserModel.fromJson(json);
  }
}
