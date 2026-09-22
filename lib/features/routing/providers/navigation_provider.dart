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
  int _routeRequestVersion = 0;
  int _routeRevision = 0;
  String? _notice;
  PointOfInterest? _requestedDestination;
  RouteMode? _requestedMode;
  LocationModel? _requestedOrigin;
  Completer<bool>? _startCompleter;

  bool get active => destination != null;
  int get routeRevision => _routeRevision;
  int? get targetGroupId =>
      destination?.groupId ?? _requestedDestination?.groupId;
  int? get targetPointId => destination?.id ?? _requestedDestination?.id;

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
    _completePendingStart(false);
    await _cancelSubscription();
    if (requestVersion != _requestVersion) return false;
    _resetRouteState();
    _requestedDestination = point;
    _requestedMode = selectedMode;
    final completion = Completer<bool>();
    _startCompleter = completion;
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final permission = await _locationService.requestForegroundPermission();
      if (requestVersion != _requestVersion) return false;
      if (permission != LocationPermissionStatus.whileInUse &&
          permission != LocationPermissionStatus.always) {
        _failInitialStart(requestVersion, _permissionMessage(permission));
        return completion.future;
      }

      late final LocationModel location;
      try {
        location = await _locationService.getCurrentLocation();
      } catch (_) {
        _failInitialStart(
          requestVersion,
          'No se pudo obtener tu ubicación actual.',
        );
        return completion.future;
      }
      if (requestVersion != _requestVersion) return false;
      _requestedOrigin = location;
      unawaited(_calculateInitialRoute(requestVersion));
      return completion.future;
    } catch (error) {
      _failInitialStart(
        requestVersion,
        _message(error, 'No se pudo calcular la ruta.'),
      );
      return completion.future;
    }
  }

  Future<void> _calculateInitialRoute(int requestVersion) async {
    final point = _requestedDestination;
    final selectedMode = _requestedMode;
    final origin = _requestedOrigin;
    if (requestVersion != _requestVersion ||
        point == null ||
        selectedMode == null ||
        origin == null) {
      return;
    }

    final routeRequestVersion = ++_routeRequestVersion;
    try {
      final route = await _routeService.calculate(
        groupId: point.groupId,
        pointId: point.id,
        origin: origin,
        mode: selectedMode,
      );
      if (!_isCurrentInitialRouteRequest(
        requestVersion: requestVersion,
        routeRequestVersion: routeRequestVersion,
        point: point,
      )) {
        return;
      }

      destination = _requestedDestination;
      mode = selectedMode;
      currentLocation = origin;
      _applyRoute(route, origin);
      _locationSubscription = _locationService.getLocationStream().listen(
        _onLocation,
        onError: (Object _) {
          if (!active) return;
          errorMessage = 'No se pudo actualizar tu ubicación.';
          notifyListeners();
        },
      );
      _requestedDestination = null;
      _requestedMode = null;
      _requestedOrigin = null;
      loading = false;
      _completePendingStart(true);
      notifyListeners();
    } catch (error) {
      if (_isCurrentInitialRouteRequest(
        requestVersion: requestVersion,
        routeRequestVersion: routeRequestVersion,
        point: point,
      )) {
        _failInitialStart(
          requestVersion,
          _message(error, 'No se pudo calcular la ruta.'),
        );
      }
    }
  }

  bool _isCurrentInitialRouteRequest({
    required int requestVersion,
    required int routeRequestVersion,
    required PointOfInterest point,
  }) {
    final requestedDestination = _requestedDestination;
    return requestVersion == _requestVersion &&
        routeRequestVersion == _routeRequestVersion &&
        requestedDestination != null &&
        requestedDestination.id == point.id &&
        requestedDestination.groupId == point.groupId;
  }

  void _failInitialStart(int requestVersion, String message) {
    if (requestVersion != _requestVersion) return;
    errorMessage = message;
    loading = false;
    _requestedDestination = null;
    _requestedMode = null;
    _requestedOrigin = null;
    _completePendingStart(false);
    notifyListeners();
  }

  void _completePendingStart(bool success) {
    final completion = _startCompleter;
    _startCompleter = null;
    if (completion != null && !completion.isCompleted) {
      completion.complete(success);
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
    final routeRequestVersion = ++_routeRequestVersion;
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
      if (!_isCurrentRouteRequest(
        requestVersion: requestVersion,
        routeRequestVersion: routeRequestVersion,
        point: point,
      )) {
        return;
      }
      final latestLocation = currentLocation ?? origin;
      _applyRoute(route, latestLocation);
    } catch (error) {
      if (_isCurrentRouteRequest(
        requestVersion: requestVersion,
        routeRequestVersion: routeRequestVersion,
        point: point,
      )) {
        errorMessage = _message(error, 'No se pudo recalcular la ruta.');
        _notice =
            'No se pudo recalcular la ruta. Se mantiene el camino anterior.';
      }
    } finally {
      if (_isCurrentRouteRequest(
        requestVersion: requestVersion,
        routeRequestVersion: routeRequestVersion,
        point: point,
      )) {
        recalculating = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentRouteRequest({
    required int requestVersion,
    required int routeRequestVersion,
    required PointOfInterest point,
  }) {
    final currentDestination = destination;
    return requestVersion == _requestVersion &&
        routeRequestVersion == _routeRequestVersion &&
        currentDestination != null &&
        currentDestination.id == point.id &&
        currentDestination.groupId == point.groupId;
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
    final requestVersion = ++_requestVersion;
    _completePendingStart(false);
    await _cancelSubscription();
    if (requestVersion != _requestVersion) return;
    _resetRouteState();
    notifyListeners();
  }

  Future<void> clear() => cancel();

  Future<void> handleActiveGroupChanged(int? groupId) async {
    final routeGroupId = targetGroupId;
    if (routeGroupId != null && routeGroupId != groupId) await cancel();
  }

  Future<void> handleDestinationUpdated(PointOfInterest updatedPoint) async {
    final currentDestination = destination;
    if (currentDestination == null) {
      final requestedDestination = _requestedDestination;
      if (requestedDestination == null ||
          requestedDestination.id != updatedPoint.id ||
          requestedDestination.groupId != updatedPoint.groupId) {
        return;
      }

      final coordinatesChanged =
          requestedDestination.latitude != updatedPoint.latitude ||
          requestedDestination.longitude != updatedPoint.longitude;
      _requestedDestination = updatedPoint;
      notifyListeners();

      if (coordinatesChanged &&
          _requestedOrigin != null &&
          _requestedMode != null) {
        await _calculateInitialRoute(_requestVersion);
      }
      return;
    }

    if (currentDestination.id != updatedPoint.id ||
        currentDestination.groupId != updatedPoint.groupId) {
      return;
    }

    final coordinatesChanged =
        currentDestination.latitude != updatedPoint.latitude ||
        currentDestination.longitude != updatedPoint.longitude;
    destination = updatedPoint;

    if (!coordinatesChanged) {
      notifyListeners();
      return;
    }

    await _recalculate();
  }

  Future<void> handleDestinationUnavailable() async {
    if (targetPointId == null || targetGroupId == null) return;
    await _finishWithNotice('El destino ya no está disponible.');
  }

  Future<void> _finishWithNotice(String message) async {
    _requestVersion++;
    _completePendingStart(false);
    final subscription = _locationSubscription;
    _locationSubscription = null;
    final cancellation = subscription?.cancel();
    _resetRouteState();
    _notice = message;
    notifyListeners();
    await cancellation;
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
    _requestedDestination = null;
    _requestedMode = null;
    _requestedOrigin = null;
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
    _completePendingStart(false);
    unawaited(_locationSubscription?.cancel());
    super.dispose();
  }
}
