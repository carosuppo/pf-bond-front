import '../../../core/network/api_client.dart';
import '../../../core/storage/session_storage_service.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';

class AuthService {
  final ApiClient _apiClient;
  final SessionStorageService _sessionStorage;

  AuthService(this._apiClient, this._sessionStorage);

  Future<bool> register(RegisterRequest request) async {
    await _apiClient.post('/user', request.toJson());

    return true;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final json = await _apiClient.post('/user/login', request.toJson());
    final response = AuthResponse.fromJson(json);

    await _sessionStorage.saveSession(
      sessionToken: response.sessionToken,
      expiresAt: response.expiresAt,
    );

    return response;
  }
}
