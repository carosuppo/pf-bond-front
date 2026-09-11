import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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

  bool _syncing = false;

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

  Future<void> restoreSharingAndTracking() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _restoreSavedPermissionStatus();

      final sharing = await _backendService.getSharing();

      state = state.copyWith(sharing: sharing);

      await _syncTracking(requestPermission: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> setGroupSharing(int groupId, bool enabled) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (enabled) {
        final permission = await _locationService.requestBackgroundPermission();

        state = state.copyWith(permissionStatus: permission);

        await _persistPermission(permission);

        if (permission != LocationPermissionStatus.always) {
          state = state.copyWith(errorMessage: _permissionMessage(permission));

          if (permission == LocationPermissionStatus.whileInUse ||
              permission == LocationPermissionStatus.deniedForever) {
            await _locationService.openAppSettings();
          } else if (permission == LocationPermissionStatus.serviceDisabled) {
            await _locationService.openLocationSettings();
          }

          return false;
        }
      }

      final updated = await _backendService.updateGroupSharing(
        groupId,
        enabled,
      );

      final sharing = [...state.sharing];

      final index = sharing.indexWhere((item) => item.groupId == groupId);

      if (index >= 0) {
        sharing[index] = updated;
      } else {
        sharing.add(updated);
      }

      state = state.copyWith(sharing: sharing);

      await _syncTracking(requestPermission: false);

      return true;
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));

      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> startViewingGroup(int groupId) async {
    state = state.copyWith(
      isLoading: true,
      activeGroupId: groupId,
      visibleMembers: {},
      clearError: true,
    );

    try {
      // Importante:
      // refrescar sharing al entrar al grupo.
      final sharing = await _backendService.getSharing();

      state = state.copyWith(sharing: sharing);

      final members = await _backendService.getGroupMembers(groupId);

      state = state.copyWith(
        visibleMembers: {for (final member in members) member.memberId: member},
      );

      await _socketSubscription?.cancel();

      _socketSubscription = _socketService.events.listen(_handleSocketEvent);

      await _socketService.connect(groupId);
    } catch (error) {
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> stopViewingGroup() async {
    await _socketSubscription?.cancel();

    _socketSubscription = null;

    await _socketService.disconnect();

    state = state.copyWith(visibleMembers: {}, clearActiveGroup: true);
  }

  Future<void> _onAppResumed() async {
    if (!state.hasEffectiveSharing) {
      return;
    }

    await _syncTracking(requestPermission: true);
  }

  Future<LocationPermissionStatus> _resolvePermission({
    required bool requestIfNeeded,
  }) async {
    final permission = await _locationService.checkPermission();

    final shouldRequest =
        requestIfNeeded &&
        (state.permissionStatus == LocationPermissionStatus.unknown ||
            permission == LocationPermissionStatus.unknown);

    return shouldRequest
        ? _locationService.requestBackgroundPermission()
        : permission;
  }

  Future<void> _restoreSavedPermissionStatus() async {
    final saved = await _preferencesService.getLocationPermissionStatus();

    if (saved == null) {
      return;
    }

    final status = LocationPermissionStatus.values.asNameMap()[saved];

    if (status != null) {
      state = state.copyWith(permissionStatus: status);
    }
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

  Future<void> _syncTracking({required bool requestPermission}) async {
    if (_syncing) {
      return;
    }

    _syncing = true;

    try {
      if (!state.hasEffectiveSharing) {
        await _stopTracking();
        return;
      }

      final permission = await _resolvePermission(
        requestIfNeeded: requestPermission,
      );

      if (state.permissionStatus != permission) {
        state = state.copyWith(permissionStatus: permission);

        await _persistPermission(permission);
      }

      if (!shouldRunLocationTracking(state.sharing, permission)) {
        await _stopTracking();

        state = state.copyWith(errorMessage: _permissionMessage(permission));

        return;
      }

      await _backgroundLocationService.ensureRunning();
      state = state.copyWith(isTracking: true, clearError: true);
      try {
        state = state.copyWith(
          currentLocation: await _locationService.getCurrentLocation(),
        );
      } catch (_) {
        // El TaskHandler enviará la próxima posición disponible a la UI.
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _stopTracking() async {
    await _backgroundLocationService.stop();
    state = state.copyWith(isTracking: false);
  }

  void _onBackgroundLocation(LocationModel location) {
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
