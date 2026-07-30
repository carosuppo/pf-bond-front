import 'location_model.dart';
import 'location_permission_status.dart';

class LocationState {
  final bool isLoading;
  final LocationPermissionStatus permissionStatus;
  final LocationModel? currentLocation;

  const LocationState({
    required this.isLoading,
    required this.permissionStatus,
    this.currentLocation,
  });

  factory LocationState.initial() {
    return const LocationState(
      isLoading: false,
      permissionStatus: LocationPermissionStatus.unknown,
      currentLocation: null,
    );
  }

  LocationState copyWith({
    bool? isLoading,
    LocationPermissionStatus? permissionStatus,
    LocationModel? currentLocation,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }

  @override
  String toString() {
    return 'LocationState('
        'isLoading: $isLoading, '
        'permissionStatus: $permissionStatus, '
        'currentLocation: $currentLocation'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationState &&
        other.isLoading == isLoading &&
        other.permissionStatus == permissionStatus &&
        other.currentLocation == currentLocation;
  }

  @override
  int get hashCode {
    return Object.hash(isLoading, permissionStatus, currentLocation);
  }
}
