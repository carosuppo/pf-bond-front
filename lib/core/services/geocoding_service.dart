import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/geocoding_result.dart';

class GeocodingService {
  final http.Client? client;

  GeocodingService({this.client});

  Future<List<GeocodingResult>> search(String query, {LatLng? near}) async {
    final String text = query.trim();
    if (text.isEmpty) return const [];
    List<GeocodingResult> results = await _searchArea(text, near: near);
    if (near != null && results.isEmpty) {
      await Future<void>.delayed(const Duration(seconds: 1));
      results = await _searchArea(text);
    }
    if (near == null) return results;
    const distance = Distance(roundResult: false);
    final ranked = results.indexed
        .map(
          (entry) => (
            index: entry.$1,
            result: entry.$2,
            meters: distance(
              near,
              LatLng(entry.$2.latitude, entry.$2.longitude),
            ),
          ),
        )
        .toList();
    ranked.sort((first, second) {
      final comparison = first.meters.compareTo(second.meters);
      return comparison != 0 ? comparison : first.index.compareTo(second.index);
    });
    return ranked.map((entry) => entry.result).toList(growable: false);
  }

  Future<List<GeocodingResult>> _searchArea(
    String query, {
    LatLng? near,
  }) async {
    final Map<String, String> parameters = {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '20',
    };
    if (near != null) {
      // A box extending approximately 25 km in each direction from the user.
      const double latitudeDelta = 25 / 111.32;
      final double longitudeDelta =
          latitudeDelta /
          math.max(0.01, math.cos(near.latitude * math.pi / 180).abs());
      final double west = (near.longitude - longitudeDelta).clamp(
        -180.0,
        180.0,
      );
      final double east = (near.longitude + longitudeDelta).clamp(
        -180.0,
        180.0,
      );
      final double south = (near.latitude - latitudeDelta).clamp(-90.0, 90.0);
      final double north = (near.latitude + latitudeDelta).clamp(-90.0, 90.0);
      parameters['viewbox'] = '$west,$south,$east,$north';
      parameters['bounded'] = '1';
    }
    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      parameters,
    );
    const Map<String, String> headers = {'User-Agent': 'Bond/1.0 (geocoding)'};
    final http.Response response =
        await (client?.get(uri, headers: headers) ??
                http.get(uri, headers: headers))
            .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo buscar la dirección.');
    }
    final List<Map<String, Object?>> decoded =
        (jsonDecode(response.body) as List).cast<Map<String, Object?>>();
    return decoded.map(_resultFromJson).toList(growable: false);
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
        .get(uri, headers: const {'User-Agent': 'Bond/1.0 (geocoding)'})
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
