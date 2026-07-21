import '../../../core/network/api_client.dart';
import '../models/auth_response.dart';
import '../models/register_request.dart';
import '../models/login_request.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<AuthResponse> register(RegisterRequest request) async {
    final json = await _apiClient.post(
      '/user',
      request.toJson(),
    );

    return AuthResponse.fromJson(json);
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final json = await _apiClient.post(
      '/user/login',
      request.toJson(),
    );

    return AuthResponse.fromJson(json);
  }
}
