import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/preferences/app_preferences_service.dart';
import '../../../core/storage/session_storage_service.dart';
import '../models/location_model.dart';
import '../models/location_permission_status.dart';
import '../models/mandatory_group_location_action.dart';
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
  StreamSubscription<LocationModel>? _foregroundLocationSubscription;

  late final AppLifecycleListener _lifecycleListener;
  Future<bool> Function(int groupId)? _leaveMandatoryGroup;
  Future<MandatoryGroupLocationAction?> Function(int groupId)?
  _promptMandatoryGroupLocationAction;

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

  void setMandatoryGroupExitHandler(
    Future<bool> Function(int groupId) handler,
  ) {
    _leaveMandatoryGroup = handler;
  }

  void setMandatoryGroupLocationPrompt(
    Future<MandatoryGroupLocationAction?> Function(int groupId) handler,
  ) {
    _promptMandatoryGroupLocationAction = handler;
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
    await _stopForegroundLocationStream();
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
      onPause: () => unawaited(_stopForegroundLocationStream()),
      onResume: () => unawaited(_onAppResumed()),
    );

    ref.onDispose(() {
      _lifecycleListener.dispose();

      _socketSubscription?.cancel();
      _foregroundLocationSubscription?.cancel();
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
      await _restoreSavedPermissionStatus();
      if (sessionVersion != _sessionVersion) return;

      final sharing = await _backendService.getSharing();
      if (sessionVersion != _sessionVersion) return;

      state = state.copyWith(sharing: sharing);

      await _syncTracking(requestPermission: true);
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
        await _syncTracking(requestPermission: true);
      });
      if (sessionVersion != _sessionVersion ||
          state.sharingForGroup(groupId) == null) {
        return;
      }
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
    await refreshAfterAppResume();
  }

  Future<void> refreshAfterAppResume() {
    final sessionVersion = _sessionVersion;

    return _enqueue(() async {
      if (sessionVersion != _sessionVersion) return;

      try {
        final sharing = await _backendService.getSharing();
        if (sessionVersion != _sessionVersion) return;
        state = state.copyWith(sharing: sharing);
      } catch (error) {
        if (sessionVersion == _sessionVersion) {
          state = state.copyWith(errorMessage: _message(error));
        }
      }

      if (sessionVersion == _sessionVersion) {
        await _syncTracking(requestPermission: false);
      }
    });
  }

  Future<LocationPermissionStatus> _resolvePermission({
    required bool requestIfNeeded,
  }) async {
    final permission = await _locationService.checkPermission();

    final shouldRequest =
        requestIfNeeded &&
        (state.permissionStatus == LocationPermissionStatus.unknown ||
            permission == LocationPermissionStatus.unknown ||
            (state.hasEffectiveSharing &&
                permission == LocationPermissionStatus.whileInUse));

    if (!shouldRequest) return permission;

    return state.hasEffectiveSharing
        ? _locationService.requestBackgroundPermission()
        : _locationService.requestForegroundPermission();
  }

  Future<void> _restoreSavedPermissionStatus() async {
    final sessionVersion = _sessionVersion;
    final saved = await _preferencesService.getLocationPermissionStatus();
    if (sessionVersion != _sessionVersion) return;

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

  Future<void> _syncTracking({bool requestPermission = false}) async {
    if (_syncingVersion == _sessionVersion) {
      return;
    }

    final sessionVersion = _sessionVersion;
    _syncingVersion = sessionVersion;

    try {
      final permission = await _resolvePermission(
        requestIfNeeded: requestPermission,
      );
      if (sessionVersion != _sessionVersion) return;

      if (state.permissionStatus != permission) {
        state = state.copyWith(permissionStatus: permission);

        await _persistPermission(permission);
        if (sessionVersion != _sessionVersion) return;
      }

      final shouldTrack = shouldRunLocationTracking(state.sharing, permission);

      if (!shouldTrack) {
        await _stopTracking();
        if (sessionVersion != _sessionVersion) return;

        if (state.hasEffectiveSharing) {
          state = state.copyWith(errorMessage: _permissionMessage(permission));
        } else {
          state = state.copyWith(clearError: true);
        }

        if (permission != LocationPermissionStatus.always) {
          await _handleMandatoryGroupsWithoutPermission(
            sessionVersion,
            permission,
          );
        }

        if (sessionVersion != _sessionVersion) return;

        if (permission != LocationPermissionStatus.whileInUse &&
            permission != LocationPermissionStatus.always) {
          await _stopForegroundLocationStream();
          state = state.copyWith(clearCurrentLocation: true);
          return;
        }

        _startForegroundLocationStream();
      } else {
        await _stopForegroundLocationStream();
        await _backgroundLocationService.ensureRunning();
        if (sessionVersion != _sessionVersion) return;
        state = state.copyWith(isTracking: true, clearError: true);
      }

      if (permission != LocationPermissionStatus.whileInUse &&
          permission != LocationPermissionStatus.always) {
        state = state.copyWith(clearCurrentLocation: true);
        return;
      }

      try {
        final location = await _locationService.getCurrentLocation();
        if (sessionVersion == _sessionVersion) {
          state = state.copyWith(currentLocation: location);
        }
      } catch (_) {}
    } finally {
      if (_syncingVersion == sessionVersion) _syncingVersion = null;
    }
  }

  Future<void> _handleMandatoryGroupsWithoutPermission(
    int sessionVersion,
    LocationPermissionStatus permission,
  ) async {
    final prompt = _promptMandatoryGroupLocationAction;
    if (prompt == null) return;

    final mandatoryGroups = state.sharing
        .where((item) => item.shareLocationMandatorily)
        .toList(growable: false);

    for (final group in mandatoryGroups) {
      if (sessionVersion != _sessionVersion) return;
      if (state.sharingForGroup(group.groupId) == null) continue;

      final action = await prompt(group.groupId);
      if (sessionVersion != _sessionVersion) return;

      if (action == MandatoryGroupLocationAction.activateLocation) {
        try {
          if (permission == LocationPermissionStatus.serviceDisabled) {
            await _locationService.openLocationSettings();
          } else {
            await _locationService.openAppSettings();
          }
        } catch (error) {
          state = state.copyWith(errorMessage: _message(error));
        }
        return;
      }

      if (action != MandatoryGroupLocationAction.leaveGroup) return;

      final leaveHandler = _leaveMandatoryGroup;
      if (leaveHandler == null) return;

      final left = await leaveHandler(group.groupId);
      if (sessionVersion != _sessionVersion) return;
      if (!left) return;

      state = state.copyWith(
        sharing: state.sharing
            .where((item) => item.groupId != group.groupId)
            .toList(growable: false),
      );
    }
  }

  Future<void> _stopTracking() async {
    final version = _sessionVersion;
    await _backgroundLocationService.stop();
    if (version == _sessionVersion) state = state.copyWith(isTracking: false);
  }

  void _startForegroundLocationStream() {
    if (_foregroundLocationSubscription != null) return;

    _foregroundLocationSubscription = _locationService
        .getLocationStream()
        .listen(_onForegroundLocation, onError: (_) {});
  }

  Future<void> _stopForegroundLocationStream() async {
    final subscription = _foregroundLocationSubscription;
    _foregroundLocationSubscription = null;
    await subscription?.cancel();
  }

  void _onForegroundLocation(LocationModel location) {
    if (state.isTracking ||
        (state.permissionStatus != LocationPermissionStatus.whileInUse &&
            state.permissionStatus != LocationPermissionStatus.always)) {
      return;
    }
    state = state.copyWith(currentLocation: location);
  }

  void _onBackgroundLocation(LocationModel location) {
    if (!state.hasEffectiveSharing ||
        (state.permissionStatus != LocationPermissionStatus.whileInUse &&
            state.permissionStatus != LocationPermissionStatus.always)) {
      return;
    }
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
