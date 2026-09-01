import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest_request.dart';
import 'package:bond_front/features/point_of_interest/providers/point_of_interest_provider.dart';
import 'package:bond_front/features/point_of_interest/services/point_of_interest_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService extends PointOfInterestService {
  _FakeService() : super(ApiClient(SessionStorageService()));

  List<PointOfInterest> stored = [];
  Object? error;

  @override
  Future<List<PointOfInterest>> getAll(int groupId) async {
    if (error != null) throw error!;
    return stored.where((point) => point.groupId == groupId).toList();
  }

  @override
  Future<PointOfInterest> create(
    int groupId,
    CreatePointOfInterestRequest request,
  ) async {
    if (error != null) throw error!;
    final point = _point(
      id: 2,
      groupId: groupId,
      name: request.name.trim(),
      radius: request.radius,
      latitude: request.latitude,
      longitude: request.longitude,
    );
    stored.add(point);
    return point;
  }

  @override
  Future<PointOfInterest> update(
    int groupId,
    int pointId,
    UpdatePointOfInterestRequest request,
  ) async {
    if (error != null) throw error!;
    final previous = stored.singleWhere((point) => point.id == pointId);
    final updated = _point(
      id: pointId,
      groupId: groupId,
      name: request.name ?? previous.name,
      radius: request.radius ?? previous.radius,
      latitude: request.latitude ?? previous.latitude,
      longitude: request.longitude ?? previous.longitude,
    );
    stored = stored
        .map((point) => point.id == pointId ? updated : point)
        .toList();
    return updated;
  }

  @override
  Future<void> delete(int groupId, int pointId) async {
    if (error != null) throw error!;
    stored.removeWhere((point) => point.id == pointId);
  }
}

PointOfInterest _point({
  int id = 1,
  int groupId = 3,
  String name = 'Facultad',
  double radius = 150,
  double latitude = -34,
  double longitude = -58,
}) => PointOfInterest(
  id: id,
  name: name,
  radius: radius,
  latitude: latitude,
  longitude: longitude,
  groupId: groupId,
  createdAt: DateTime(2026),
);

void main() {
  test('carga y limpia los POIs al cambiar de grupo', () async {
    final service = _FakeService()
      ..stored = [_point(), _point(id: 8, groupId: 4)];
    final provider = PointOfInterestProvider(service);

    await provider.loadPoints(3);
    expect(provider.points.map((point) => point.id), [1]);

    await provider.loadPoints(4);
    expect(provider.points.map((point) => point.id), [8]);
  });

  test(
    'alta, modificación parcial y baja actualizan el estado inmediatamente',
    () async {
      final service = _FakeService()..stored = [_point()];
      final provider = PointOfInterestProvider(service);
      await provider.loadPoints(3);

      expect(
        await provider.create(
          3,
          const CreatePointOfInterestRequest(
            name: ' Plaza ',
            radius: 50,
            latitude: -31,
            longitude: -60,
          ),
        ),
        isTrue,
      );
      expect(provider.points.last.name, 'Plaza');

      expect(
        await provider.update(
          3,
          1,
          const UpdatePointOfInterestRequest(name: 'Nueva facultad'),
        ),
        isTrue,
      );
      expect(provider.points.first.name, 'Nueva facultad');
      expect(provider.points.first.radius, 150);

      expect(await provider.delete(3, 1), isTrue);
      expect(provider.points.map((point) => point.id), isNot(contains(1)));
    },
  );

  test('un error no aplica cambios visuales falsos', () async {
    final service = _FakeService()..stored = [_point()];
    final provider = PointOfInterestProvider(service);
    await provider.loadPoints(3);
    service.error = Exception('No perteneces a este grupo.');

    expect(await provider.delete(3, 1), isFalse);
    expect(provider.points, hasLength(1));
    expect(provider.errorMessage, 'No perteneces a este grupo.');
  });
}
