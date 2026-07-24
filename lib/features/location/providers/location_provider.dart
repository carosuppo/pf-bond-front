import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_model.dart';
import '../models/location_permission_status.dart';
import '../models/location_state.dart';
import '../services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final locationProvider = NotifierProvider<LocationProvider, LocationState>(
  LocationProvider.new,
);

class LocationProvider extends Notifier<LocationState> {
  late final LocationService _locationService;

  StreamSubscription<LocationModel>? _locationSubscription;

  @override
  LocationState build() {
    _locationService = ref.read(locationServiceProvider);

    ref.onDispose(() {
      _locationSubscription?.cancel();
    });

    return LocationState.initial();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      final permissionStatus = await _locationService.requestPermission();

      state = state.copyWith(permissionStatus: permissionStatus);

      if (permissionStatus != LocationPermissionStatus.granted) {
        return;
      }

      final currentLocation = await _locationService.getCurrentLocation();

      state = state.copyWith(currentLocation: currentLocation);

      _locationSubscription = _locationService.getLocationStream().listen((
        location,
      ) {
        state = state.copyWith(currentLocation: location);
      });
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
