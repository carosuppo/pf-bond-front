import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../location/models/location_model.dart';
import '../../location/models/location_permission_status.dart';
import '../../location/services/location_service.dart';
import '../../point_of_interest/models/point_of_interest.dart';
import '../constants/navigation_config.dart';
import '../models/route_mode.dart';
import '../models/route_response.dart';
import '../services/route_service.dart';
import '../utils/route_progress_tracker.dart';

class NavigationProvider extends ChangeNotifier {
  NavigationProvider(
    this._routeService,
    this._locationService, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RouteService _routeService;
  final LocationService _locationService;
  final DateTime Function() _clock;

  PointOfInterest? destination;
  RouteMode? mode;
  LocationModel? currentLocation;
  List<LatLng> remainingPoints = const [];
  double remainingDistanceMeters = 0;
  double durationSeconds = 0;
  bool loading = false;
  bool recalculating = false;
  String? errorMessage;

  RouteProgressTracker? _tracker;
  StreamSubscription<LocationModel>? _locationSubscription;
  DateTime? _lastRecalculationAt;
  int _offRouteReadings = 0;
  int _requestVersion = 0;
  int _routeRevision = 0;
  String? _notice;
  int? _requestedGroupId;
  int? _requestedPointId;

  bool get active => destination != null;
  int get routeRevision => _routeRevision;
  int? get targetGroupId => destination?.groupId ?? _requestedGroupId;
  int? get targetPointId => destination?.id ?? _requestedPointId;

  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  Future<bool> start({
    required PointOfInterest point,
    required RouteMode selectedMode,
  }) async {
    final requestVersion = ++_requestVersion;
    await _cancelSubscription();
    _resetRouteState();
    _requestedGroupId = point.groupId;
    _requestedPointId = point.id;
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final permission = await _locationService.requestForegroundPermission();
      if (requestVersion != _requestVersion) return false;
      if (permission != LocationPermissionStatus.whileInUse &&
          permission != LocationPermissionStatus.always) {
        errorMessage = _permissionMessage(permission);
        return false;
      }

      late final LocationModel location;
      try {
        location = await _locationService.getCurrentLocation();
      } catch (_) {
        if (requestVersion == _requestVersion) {
          errorMessage = 'No se pudo obtener tu ubicación actual.';
        }
        return false;
      }
      if (requestVersion != _requestVersion) return false;
      final route = await _routeService.calculate(
        groupId: point.groupId,
        pointId: point.id,
        origin: location,
        mode: selectedMode,
      );
      if (requestVersion != _requestVersion) return false;

      destination = point;
      _requestedGroupId = null;
      _requestedPointId = null;
      mode = selectedMode;
      currentLocation = location;
      _applyRoute(route, location);
      _locationSubscription = _locationService.getLocationStream().listen(
        _onLocation,
        onError: (Object _) {
          if (!active) return;
          errorMessage = 'No se pudo actualizar tu ubicación.';
          notifyListeners();
        },
      );
      return true;
    } catch (error) {
      if (requestVersion == _requestVersion) {
        errorMessage = _message(error, 'No se pudo calcular la ruta.');
      }
      return false;
    } finally {
      if (requestVersion == _requestVersion) {
        if (destination == null) {
          _requestedGroupId = null;
          _requestedPointId = null;
        }
        loading = false;
        notifyListeners();
      }
    }
  }

  void _onLocation(LocationModel location) {
    final point = destination;
    final selectedMode = mode;
    final tracker = _tracker;
    if (point == null || selectedMode == null || tracker == null) return;

    currentLocation = location;
    final userPoint = LatLng(location.latitude, location.longitude);
    final destinationPoint = LatLng(point.latitude, point.longitude);
    if (RouteProgressTracker.distanceMeters(userPoint, destinationPoint) <=
        point.radius) {
      unawaited(_finishWithNotice('Llegaste a ${point.name}.'));
      return;
    }

    final progress = tracker.update(userPoint);
    remainingPoints = progress.remainingPoints;
    remainingDistanceMeters = progress.remainingDistanceMeters;

    final effectiveDeviation = math.max(
      0,
      progress.distanceToRouteMeters - math.max(0, location.accuracy),
    );
    if (effectiveDeviation >
        NavigationConfig.deviationThreshold(selectedMode)) {
      _offRouteReadings++;
    } else {
      _offRouteReadings = 0;
    }

    notifyListeners();

    if (_offRouteReadings >= NavigationConfig.consecutiveOffRouteReadings &&
        _canRecalculate()) {
      _offRouteReadings = 0;
      unawaited(_recalculate());
    }
  }

  bool _canRecalculate() {
    if (recalculating) return false;
    final last = _lastRecalculationAt;
    return last == null ||
        _clock().difference(last) >= NavigationConfig.recalculationCooldown;
  }

  Future<void> _recalculate() async {
    final point = destination;
    final selectedMode = mode;
    final origin = currentLocation;
    if (point == null || selectedMode == null || origin == null) return;

    final requestVersion = _requestVersion;
    recalculating = true;
    _lastRecalculationAt = _clock();
    errorMessage = null;
    notifyListeners();

    try {
      final route = await _routeService.calculate(
        groupId: point.groupId,
        pointId: point.id,
        origin: origin,
        mode: selectedMode,
      );
      if (requestVersion != _requestVersion || destination?.id != point.id) {
        return;
      }
      final latestLocation = currentLocation ?? origin;
      _applyRoute(route, latestLocation);
    } catch (error) {
      if (requestVersion == _requestVersion && active) {
        errorMessage = _message(error, 'No se pudo recalcular la ruta.');
        _notice =
            'No se pudo recalcular la ruta. Se mantiene el camino anterior.';
      }
    } finally {
      if (requestVersion == _requestVersion && active) {
        recalculating = false;
        notifyListeners();
      }
    }
  }

  void _applyRoute(RouteResponse route, LocationModel location) {
    final tracker = RouteProgressTracker(route.points);
    final progress = tracker.update(
      LatLng(location.latitude, location.longitude),
    );
    _tracker = tracker;
    remainingPoints = progress.remainingPoints;
    remainingDistanceMeters = progress.remainingDistanceMeters;
    durationSeconds = route.durationSeconds;
    errorMessage = null;
    _offRouteReadings = 0;
    _routeRevision++;
  }

  Future<void> cancel() async {
    _requestVersion++;
    await _cancelSubscription();
    _resetRouteState();
    notifyListeners();
  }

  Future<void> clear() => cancel();

  Future<void> handleActiveGroupChanged(int? groupId) async {
    final routeGroupId = targetGroupId;
    if (routeGroupId != null && routeGroupId != groupId) await cancel();
  }

  Future<void> _finishWithNotice(String message) async {
    _requestVersion++;
    await _cancelSubscription();
    _resetRouteState();
    _notice = message;
    notifyListeners();
  }

  Future<void> _cancelSubscription() async {
    final subscription = _locationSubscription;
    _locationSubscription = null;
    await subscription?.cancel();
  }

  void _resetRouteState() {
    destination = null;
    mode = null;
    currentLocation = null;
    remainingPoints = const [];
    remainingDistanceMeters = 0;
    durationSeconds = 0;
    loading = false;
    recalculating = false;
    errorMessage = null;
    _tracker = null;
    _lastRecalculationAt = null;
    _offRouteReadings = 0;
    _requestedGroupId = null;
    _requestedPointId = null;
  }

  String _permissionMessage(LocationPermissionStatus permission) =>
      switch (permission) {
        LocationPermissionStatus.serviceDisabled =>
          'Activá la ubicación del dispositivo para calcular la ruta.',
        LocationPermissionStatus.denied ||
        LocationPermissionStatus.deniedForever =>
          'Bond necesita permiso de ubicación mientras usás la app.',
        _ => 'No se pudo obtener permiso para usar tu ubicación.',
      };

  String _message(Object error, String fallback) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? fallback : message;
  }

  @override
  void dispose() {
    _requestVersion++;
    unawaited(_locationSubscription?.cancel());
    super.dispose();
  }
}
