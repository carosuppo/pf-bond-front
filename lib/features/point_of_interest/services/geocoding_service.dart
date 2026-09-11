import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geocoding_result.dart';

class GeocodingService {
  Future<List<GeocodingResult>> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query.trim(),
      'format': 'jsonv2',
      'limit': '5',
    });
    final response = await http
        .get(
          uri,
          headers: const {'User-Agent': 'Bond/1.0 (point-of-interest-search)'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo buscar la dirección.');
    }
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) {
          final json = item as Map<String, dynamic>;
          return GeocodingResult(
            displayName: json['display_name'] as String,
            latitude: double.parse(json['lat'] as String),
            longitude: double.parse(json['lon'] as String),
          );
        })
        .toList(growable: false);
  }
}
