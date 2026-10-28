import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/preferences/app_preferences_service.dart';
import '../../../core/storage/session_storage_service.dart';
import '../models/location_model.dart';
import '../models/location_permission_status.dart';
import '../models/location_socket_event.dart';
import '../models/location_state.dart';
import '../services/location_backend_service.dart';
import '../services/background_location_service.dart';
import '../services/location_service.dart';
import '../services/location_socket_service.dart';
import '../utils/location_tracking_policy.dart';
import '../utils/member_location_reducer.dart';

final sessionStorageProvider = Provider<SessionStorageService>(
  (ref) => SessionStorageService(),
);

final appPreferencesProvider = Provider<AppPreferencesService>(
  (ref) => AppPreferencesService(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.read(sessionStorageProvider)),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final locationBackendServiceProvider = Provider<LocationBackendService>(
  (ref) => LocationBackendService(ref.read(apiClientProvider)),
);

final backgroundLocationServiceProvider = Provider<BackgroundLocationService>(
  (ref) => BackgroundLocationService(),
);

final locationSocketServiceProvider = Provider<LocationSocketService>((ref) {
  final service = LocationSocketService(ref.read(sessionStorageProvider));

  ref.onDispose(service.dispose);

  return service;
});

final locationProvider = NotifierProvider<LocationProvider, LocationState>(
  LocationProvider.new,
);

class LocationProvider extends Notifier<LocationState> {
  late final LocationService _locationService;

  late final LocationBackendService _backendService;

  late final LocationSocketService _socketService;

  late final AppPreferencesService _preferencesService;

  late final BackgroundLocationService _backgroundLocationService;

  StreamSubscription<LocationSocketEvent>? _socketSubscription;

  late final AppLifecycleListener _lifecycleListener;

  int? _syncingVersion;
  int _sessionVersion = 0;
  bool _sessionActive = false;
  Future<void> _operations = Future<void>.value();
  Future<void>? _restoring;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> resetSessionState() async {
    _sessionVersion++;
    _sessionActive = false;
    _restoring = null;
    _syncingVersion = null;
    final subscription = _socketSubscription;
    _socketSubscription = null;
    state = LocationState.initial();

    try {
      await _backgroundLocationService.stop();
    } catch (error) {
      debugPrint('No se pudo detener el tracking de ubicación: $error');
    }
    try {
      await subscription?.cancel();
    } catch (error) {
      debugPrint('No se pudo cancelar la suscripción de ubicación: $error');
    }
    try {
      await _socketService.disconnect();
    } catch (error) {
      debugPrint('No se pudo cerrar el socket de ubicación: $error');
    }
  }

  @override
  LocationState build() {
    _locationService = ref.read(locationServiceProvider);

    _backendService = ref.read(locationBackendServiceProvider);

    _socketService = ref.read(locationSocketServiceProvider);

    _preferencesService = ref.read(appPreferencesProvider);

    _backgroundLocationService = ref.read(backgroundLocationServiceProvider);
    _backgroundLocationService.addLocationListener(_onBackgroundLocation);

    // Cuando la app vuelve a primer plano, re-chequeamos los permisos:
    // si el usuario los habilitó en Ajustes, el tracking se reanuda solo.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_onAppResumed()),
    );

    ref.onDispose(() {
      _lifecycleListener.dispose();

      _socketSubscription?.cancel();
      _backgroundLocationService.removeLocationListener(_onBackgroundLocation);
    });

    return LocationState.initial();
  }

  Future<void> restoreSharingAndTracking() {
    _sessionActive = true;
    final version = _sessionVersion;
    return _restoring ??=
        _enqueue(() async {
          if (version != _sessionVersion) return;
          await _restoreSharingAndTracking(version);
        }).whenComplete(() {
          if (version == _sessionVersion) _restoring = null;
        });
  }

  Future<void> _restoreSharingAndTracking(int sessionVersion) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final permission = await _locationService.checkBackgroundPermission();
      if (sessionVersion != _sessionVersion) return;

      state = state.copyWith(permissionStatus: permission);
      await _persistPermission(permission);
      if (sessionVersion != _sessionVersion) return;
      if (permission != LocationPermissionStatus.always) await _stopTracking();
      if (sessionVersion != _sessionVersion) return;
      final sharing = await _backendService.getSharing();
      if (sessionVersion != _sessionVersion) return;

      state = state.copyWith(sharing: sharing);

      await _syncTracking();
    } catch (error) {
      if (sessionVersion == _sessionVersion) {
        if (error is ApiException && error.isUnauthorized) {
          await _stopTracking();
        }
        if (sessionVersion != _sessionVersion) return;
        state = state.copyWith(errorMessage: _message(error));
      }
    } finally {
      if (sessionVersion == _sessionVersion) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> setGroupSharing(int groupId, bool enabled) {
    final version = _sessionVersion;
    return _enqueue(() async {
      if (version != _sessionVersion) return false;
      return _setGroupSharing(groupId, enabled, version);
    });
  }

  Future<bool> _setGroupSharing(
    int groupId,
    bool enabled,
    int sessionVersion,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (enabled) {
        final permission = await _locationService.requestBackgroundPermission();
        if (sessionVersion != _sessionVersion) return false;

        state = state.copyWith(permissionStatus: permission);

        await _persistPermission(permission);
        if (sessionVersion != _sessionVersion) return false;

        if (permission != LocationPermissionStatus.always) {
          state = state.copyWith(errorMessage: _permissionMessage(permission));

          return false;
        }
      }

      final updated = await _backendService.updateGroupSharing(
        groupId,
        enabled,
      );
      if (sessionVersion != _sessionVersion) return false;

      final sharing = [...state.sharing];

      final index = sharing.indexWhere((item) => item.groupId == groupId);

      if (index >= 0) {
        sharing[index] = updated;
      } else {
        sharing.add(updated);
      }

      state = state.copyWith(sharing: sharing);

      await _syncTracking();

      return true;
    } catch (error) {
      if (sessionVersion == _sessionVersion) {
        state = state.copyWith(errorMessage: _message(error));
      }

      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> startViewingGroup(int groupId) async {
    final sessionVersion = _sessionVersion;
    state = state.copyWith(
      isLoading: true,
      activeGroupId: groupId,
      visibleMembers: {},
      clearError: true,
    );

    try {
      // Importante:
      // refrescar sharing al entrar al grupo.
      await _enqueue(() async {
        if (sessionVersion != _sessionVersion) return;
        final sharing = await _backendService.getSharing();
        if (sessionVersion != _sessionVersion) return;
        state = state.copyWith(sharing: sharing);
        await _syncTracking();
      });
      if (sessionVersion != _sessionVersion) return;

      final members = await _backendService.getGroupMembers(groupId);
      if (sessionVersion != _sessionVersion) return;

      state = state.copyWith(
        visibleMembers: {for (final member in members) member.memberId: member},
      );

      await _socketSubscription?.cancel();
      if (sessionVersion != _sessionVersion) return;

      _socketSubscription = _socketService.events.listen(_handleSocketEvent);

      await _socketService.connect(groupId);
    } catch (error) {
      if (sessionVersion == _sessionVersion) {
        state = state.copyWith(errorMessage: _message(error));
      }
    } finally {
      if (sessionVersion == _sessionVersion) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> stopViewingGroup() async {
    await _socketSubscription?.cancel();

    _socketSubscription = null;

    await _socketService.disconnect();

    state = state.copyWith(visibleMembers: {}, clearActiveGroup: true);
  }

  Future<bool> get mayBeBatteryRestricted =>
      _backgroundLocationService.mayBeBatteryRestricted;

  Future<void> openBatterySettings() async {
    try {
      await _backgroundLocationService.openBatterySettings();
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    }
  }

  Future<bool> openPermissionSettings() => _locationService.openAppSettings();
  Future<bool> openGpsSettings() => _locationService.openLocationSettings();

  Future<void> _onAppResumed() async {
    if (!_sessionActive) return;
    await restoreSharingAndTracking();
  }

  Future<void> _persistPermission(LocationPermissionStatus permission) async {
    // No guardamos estados transitorios: `unknown` (todavía sin determinar)
    // y `serviceDisabled` (el GPS del dispositivo puede volver a activarse).
    if (permission == LocationPermissionStatus.unknown ||
        permission == LocationPermissionStatus.serviceDisabled) {
      return;
    }

    await _preferencesService.saveLocationPermissionStatus(permission.name);
  }

  Future<void> _syncTracking() async {
    if (_syncingVersion == _sessionVersion) {
      return;
    }

    final sessionVersion = _sessionVersion;
    _syncingVersion = sessionVersion;

    try {
      if (!state.hasEffectiveSharing) {
        await _stopTracking();
        return;
      }

      final permission = await _locationService.checkBackgroundPermission();
      if (sessionVersion != _sessionVersion) return;

      if (state.permissionStatus != permission) {
        state = state.copyWith(permissionStatus: permission);

        await _persistPermission(permission);
      }

      if (sessionVersion != _sessionVersion) return;
      if (!shouldRunLocationTracking(state.sharing, permission)) {
        await _stopTracking();
        if (sessionVersion != _sessionVersion) return;

        state = state.copyWith(errorMessage: _permissionMessage(permission));

        return;
      }

      await _backgroundLocationService.ensureRunning();
      if (sessionVersion != _sessionVersion) return;
      state = state.copyWith(isTracking: true, clearError: true);
    } finally {
      if (_syncingVersion == sessionVersion) _syncingVersion = null;
    }
  }

  Future<void> _stopTracking() async {
    final version = _sessionVersion;
    await _backgroundLocationService.stop();
    if (version == _sessionVersion) state = state.copyWith(isTracking: false);
  }

  void _onBackgroundLocation(LocationModel location) {
    if (!state.hasEffectiveSharing) return;
    state = state.copyWith(currentLocation: location);
  }

  void _handleSocketEvent(LocationSocketEvent event) {
    if (event is PointOfInterestSocketEvent) {
      return;
    }

    final activeGroupId = state.activeGroupId;

    if (activeGroupId == null) {
      return;
    }

    final ownMemberId = state.sharingForGroup(activeGroupId)?.memberId;

    // Defensa extra del front:
    // jamás agregarnos como otro miembro.
    if (event is MemberLocationUpdated &&
        event.member.memberId == ownMemberId) {
      return;
    }

    if (event is MemberLocationRemoved && event.memberId == ownMemberId) {
      return;
    }

    if (event is MemberLocationHeartbeat && event.memberId == ownMemberId) {
      return;
    }

    state = state.copyWith(
      visibleMembers: reduceMemberLocations(
        state.visibleMembers,
        event,
        activeGroupId,
      ),
    );
  }

  String _permissionMessage(
    LocationPermissionStatus permission,
  ) => switch (permission) {
    LocationPermissionStatus.serviceDisabled =>
      'Activa la ubicacion del dispositivo para compartirla.',

    LocationPermissionStatus.denied =>
      'Permiso de ubicacion denegado. Habilitalo desde Ajustes para compartir.',

    LocationPermissionStatus.unknown =>
      'Se necesita permiso de ubicacion para compartirla.',

    LocationPermissionStatus.deniedForever =>
      'Habilita el permiso de ubicacion desde Ajustes.',

    LocationPermissionStatus.whileInUse =>
      'Selecciona permitir siempre en Ajustes para compartir en segundo plano.',

    _ => 'No se pudo habilitar la ubicacion en segundo plano.',
  };

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}
