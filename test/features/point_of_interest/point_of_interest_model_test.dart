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

  test('parsea temporalidad y serializa una duración explícita', () {
    final point = PointOfInterest.fromJson({
      'id': 2,
      'name': 'Encuentro',
      'description': null,
      'radius': 50,
      'latitude': -34.6,
      'longitude': -58.3,
      'groupId': 3,
      'createdAt': '2026-09-22T10:00:00.000Z',
      'isTemporary': true,
      'endTime': '2026-09-22T11:00:00.000Z',
    });
    const request = CreatePointOfInterestRequest(
      name: '',
      radius: 50,
      latitude: -34.6,
      longitude: -58.3,
      isTemporary: true,
      durationMinutes: 60,
    );

    expect(point.isTemporary, isTrue);
    expect(point.endTime?.isUtc, isTrue);
    expect(request.toJson(), containsPair('durationMinutes', 60));
    expect(request.toJson(), containsPair('isTemporary', true));
  });
}
