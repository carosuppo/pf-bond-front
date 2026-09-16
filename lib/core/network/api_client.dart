import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/session_storage_service.dart';
import 'api_exception.dart';

class ApiClient {
  final SessionStorageService sessionStorage;

  ApiClient(this.sessionStorage);

  static const _timeout = Duration(seconds: 20);

  Future<http.Response> _send(Future<http.Response> Function() request) {
    return request().timeout(_timeout);
  }

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

  Future<void> authenticatedPostNoContent(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final headers = await _buildHeaders(authenticated: true);

    final response = await _send(
      () => http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );

    _decodeSuccessfulResponse(response);
  }

  Future<Map<String, dynamic>> authenticatedPatch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final headers = await _buildHeaders(authenticated: true);

    final response = await _send(
      () => http.patch(uri, headers: headers, body: jsonEncode(body)),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> authenticatedGet(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final headers = await _buildHeaders(authenticated: true);

    final response = await _send(() => http.get(uri, headers: headers));

    return _handleResponse(response);
  }

  Future<void> authenticatedDelete(String path) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    final headers = await _buildHeaders(authenticated: true);

    final response = await _send(() => http.delete(uri, headers: headers));

    _decodeSuccessfulResponse(response);
  }

  Future<List<Map<String, dynamic>>> authenticatedGetList(String path) async {
    final headers = await _buildHeaders(authenticated: true);

    final response = await _send(
      () => http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: headers),
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

    final token = await sessionStorage.getSessionToken();

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

    throw ApiException(
      _getErrorMessage(decodedBody),
      statusCode: response.statusCode,
    );
  }
}
