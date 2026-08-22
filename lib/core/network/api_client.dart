import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/session_storage_service.dart';

class ApiClient {
  final SessionStorageService _sessionStorage;

  ApiClient(this._sessionStorage);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http.post(
      uri,
      headers: await _buildHeaders(),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> authenticatedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http.post(
      uri,
      headers: await _buildHeaders(authenticated: true),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> authenticatedPatch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http.patch(
      uri,
      headers: await _buildHeaders(authenticated: true),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> authenticatedGet(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http.get(
      uri,
      headers: await _buildHeaders(authenticated: true),
    );

    return _handleResponse(response);
  }

  Future<List<Map<String, dynamic>>> authenticatedGetList(String path) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _buildHeaders(authenticated: true),
    );
    final decodedBody = _decodeSuccessfulResponse(response);
    if (decodedBody is! List<Object?>) {
      throw Exception('La respuesta del servidor no es una lista valida.');
    }
    return decodedBody
        .map((item) => Map<String, dynamic>.from(item! as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> authenticatedPut(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final response = await http.put(
      uri,
      headers: await _buildHeaders(authenticated: true),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, String>> _buildHeaders({
    bool authenticated = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (!authenticated) {
      return headers;
    }

    final token = await _sessionStorage.getSessionToken();

    if (token == null || token.isEmpty) {
      throw Exception('No existe una sesión válida.');
    }

    headers['Authorization'] = 'Bearer $token';

    return headers;
  }

  String _getErrorMessage(dynamic decodedBody) {
    if (decodedBody is Map<String, dynamic>) {
      final message = decodedBody['message'];

      if (message is String) {
        return message;
      }

      if (message is List) {
        return message.join('\n');
      }
    }

    return 'Ocurrió un error inesperado.';
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final decodedBody = _decodeSuccessfulResponse(response);
    return Map<String, dynamic>.from(decodedBody as Map);
  }

  Object? _decodeSuccessfulResponse(http.Response response) {
    final Object? decodedBody = response.body.isNotEmpty
        ? jsonDecode(response.body) as Object?
        : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }
    throw Exception(_getErrorMessage(decodedBody));
  }
}
