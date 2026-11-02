class LoginRequest {
  final String email;
  final String password;
  final String? birthDate;
  final String? termsVersion;

  LoginRequest({
    required this.email,
    required this.password,
    this.birthDate,
    this.termsVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (birthDate != null) 'birthDate': birthDate,
      if (termsVersion != null) 'termsVersion': termsVersion,
    };
  }
}
