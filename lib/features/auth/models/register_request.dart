class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String birthDate;
  final String termsVersion;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.birthDate,
    required this.termsVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'birthDate': birthDate,
      'termsVersion': termsVersion,
    };
  }
}
