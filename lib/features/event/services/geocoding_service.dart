import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/geocoding_result.dart';

class GeocodingService {
  Future<List<GeocodingResult>> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query.trim(),
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '5',
    });

    final response = await http
        .get(
          uri,
          headers: const {'User-Agent': 'Bond/1.0 (event-location-search)'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo buscar la dirección.');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;

    return decoded
        .map((item) {
          return _resultFromJson(item as Map<String, dynamic>);
        })
        .toList(growable: false);
  }

  Future<GeocodingResult> reverse(LatLng location) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': location.latitude.toString(),
      'lon': location.longitude.toString(),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
    });

    final response = await http
        .get(
          uri,
          headers: const {'User-Agent': 'Bond/1.0 (event-location-search)'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo obtener la dirección.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _resultFromJson(json);
  }

  GeocodingResult _resultFromJson(Map<String, dynamic> json) {
    final displayName = _formatAddress(json);

    return GeocodingResult(
      displayName: displayName.isEmpty
          ? json['display_name'] as String
          : displayName,
      latitude: double.parse(json['lat'] as String),
      longitude: double.parse(json['lon'] as String),
    );
  }

  String _formatAddress(Map<String, dynamic> result) {
    final address = (result['address'] as Map?)?.cast<String, dynamic>();

    if (address == null) {
      return '';
    }

    final street = _firstNonEmpty([
      address['road'],
      address['pedestrian'],
      address['residential'],
      address['footway'],
      address['path'],
    ]);
    final houseNumber = _firstNonEmpty([address['house_number']]);
    final city = _firstNonEmpty([
      address['city'],
      address['town'],
      address['village'],
    ]);
    final province = _firstNonEmpty([address['state']]);
    final country = _firstNonEmpty([address['country']]);

    final streetAndNumber = [
      street,
      houseNumber,
    ].where((part) => part.isNotEmpty).join(' ');

    return [
      streetAndNumber,
      city,
      province,
      country,
    ].where((part) => part.isNotEmpty).join(', ');
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }
}
