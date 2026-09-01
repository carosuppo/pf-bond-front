import 'package:bond_front/features/point_of_interest/models/point_of_interest.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deserializa la respuesta plana del backend', () {
    final point = PointOfInterest.fromJson({
      'id': 1,
      'name': 'Facultad',
      'description': null,
      'radius': 150,
      'latitude': -34.6,
      'longitude': -58.3,
      'groupId': 3,
      'createdAt': '2026-08-01T00:00:00.000Z',
    });

    expect(point.radius, 150.0);
    expect(point.groupId, 3);
  });

  test('normaliza nombre y descripción al crear', () {
    const request = CreatePointOfInterestRequest(
      name: ' Facultad ',
      description: '   ',
      radius: 100,
      latitude: -34,
      longitude: -58,
    );

    expect(request.toJson()['name'], 'Facultad');
    expect(request.toJson()['description'], isNull);
  });

  test('PATCH sólo serializa los campos provistos', () {
    const request = UpdatePointOfInterestRequest(name: 'Nuevo nombre');
    expect(request.toJson(), {'name': 'Nuevo nombre'});
  });
}
