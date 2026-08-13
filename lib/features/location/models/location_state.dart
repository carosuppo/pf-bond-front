import 'location_model.dart';
import 'location_permission_status.dart';
import 'location_sharing_model.dart';
import 'member_location_model.dart';

class LocationState {
  final bool isLoading;
  final bool isTracking;
  final LocationPermissionStatus permissionStatus;
  final LocationModel? currentLocation;
  final List<LocationSharingModel> sharing;
  final Map<int, MemberLocationModel> visibleMembers;
  final int? activeGroupId;
  final String? errorMessage;

  const LocationState({
    required this.isLoading,
    required this.isTracking,
    required this.permissionStatus,
    required this.sharing,
    required this.visibleMembers,
    this.currentLocation,
    this.activeGroupId,
    this.errorMessage,
  });

  factory LocationState.initial() => const LocationState(
    isLoading: false,
    isTracking: false,
    permissionStatus: LocationPermissionStatus.unknown,
    sharing: <LocationSharingModel>[],
    visibleMembers: <int, MemberLocationModel>{},
  );

  bool get hasEffectiveSharing =>
      sharing.any((item) => item.effectiveLocationSharing);

  LocationSharingModel? sharingForGroup(int groupId) {
    for (final item in sharing) {
      if (item.groupId == groupId) return item;
    }
    return null;
  }

  LocationState copyWith({
    bool? isLoading,
    bool? isTracking,
    LocationPermissionStatus? permissionStatus,
    LocationModel? currentLocation,
    List<LocationSharingModel>? sharing,
    Map<int, MemberLocationModel>? visibleMembers,
    int? activeGroupId,
    String? errorMessage,
    bool clearError = false,
    bool clearActiveGroup = false,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      isTracking: isTracking ?? this.isTracking,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      currentLocation: currentLocation ?? this.currentLocation,
      sharing: sharing ?? this.sharing,
      visibleMembers: visibleMembers ?? this.visibleMembers,
      activeGroupId: clearActiveGroup
          ? null
          : activeGroupId ?? this.activeGroupId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
