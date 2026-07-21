import 'user_model.dart';

class AuthResponse {
  final String sessionToken;
  final DateTime expiresAt;
  final UserModel user;

  AuthResponse({
    required this.sessionToken,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      sessionToken: json['sessionToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
