import 'dart:convert';

import 'package:bond_front/core/services/geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const origin = LatLng(-32.4, -63.2);
  final data = [
    {'display_name': 'Lejana', 'lat': '-32.5', 'lon': '-63.2'},
    {'display_name': 'Cercana', 'lat': '-32.401', 'lon': '-63.2'},
  ];

  test('consulta la zona antes de ordenar las coincidencias', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(jsonEncode(data), 200);
    });
    addTearDown(client.close);
    final results = await GeocodingService(
      client: client,
    ).search('San Martín', near: origin);
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['bounded'], '1');
    expect(requests.single.queryParameters['limit'], '20');
    final box = requests.single.queryParameters['viewbox']!
        .split(',')
        .map(double.parse)
        .toList();
    expect(box[0], lessThan(origin.longitude));
    expect(box[2], greaterThan(origin.longitude));
    expect(box[1], lessThan(origin.latitude));
    expect(box[3], greaterThan(origin.latitude));
    expect(results.map((result) => result.displayName), ['Cercana', 'Lejana']);
  });

  test(
    'sin coincidencias locales amplía y conserva la ciudad escrita',
    () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          requests.length == 1 ? '[]' : jsonEncode(data),
          200,
        );
      });
      addTearDown(client.close);
      await GeocodingService(
        client: client,
      ).search('San Martín, Córdoba', near: origin);
      expect(requests, hasLength(2));
      expect(requests.last.queryParameters.containsKey('viewbox'), isFalse);
      expect(requests.last.queryParameters.containsKey('bounded'), isFalse);
      expect(requests.last.queryParameters['q'], 'San Martín, Córdoba');
    },
  );

  test('sin GPS usa una consulta global y conserva su orden', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters.containsKey('viewbox'), isFalse);
      return http.Response(jsonEncode(data), 200);
    });
    addTearDown(client.close);
    final results = await GeocodingService(client: client).search('San Martín');
    expect(results.map((result) => result.displayName), ['Lejana', 'Cercana']);
  });

  test('un error del proveedor no dispara otra consulta', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 429);
    });
    addTearDown(client.close);
    await expectLater(
      GeocodingService(client: client).search('San Martín', near: origin),
      throwsException,
    );
    expect(calls, 1);
  });
}
