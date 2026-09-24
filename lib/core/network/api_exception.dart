class ApiException implements Exception {
  const ApiException(
    this.message, {
    required this.statusCode,
    this.responseBody,
  });

  final String message;
  final int statusCode;
  final Map<String, dynamic>? responseBody;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
