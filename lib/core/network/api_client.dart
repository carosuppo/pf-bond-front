import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiClient {
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    print('POST: $path');
    print(body);

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');

    print(uri);

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decodedBody = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody as Map<String, dynamic>;
    }

    throw Exception(_getErrorMessage(decodedBody));
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
}
