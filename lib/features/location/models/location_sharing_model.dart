class LocationSharingModel {
  final int memberId;
  final int groupId;
  final bool locationSharingEnabled;
  final bool shareLocationMandatorily;
  final bool effectiveLocationSharing;

  const LocationSharingModel({
    required this.memberId,
    required this.groupId,
    required this.locationSharingEnabled,
    required this.shareLocationMandatorily,
    required this.effectiveLocationSharing,
  });

  factory LocationSharingModel.fromJson(Map<String, dynamic> json) {
    return LocationSharingModel(
      memberId: json['memberId'] as int,
      groupId: json['groupId'] as int,
      locationSharingEnabled: json['locationSharingEnabled'] as bool,
      shareLocationMandatorily: json['shareLocationMandatorily'] as bool,
      effectiveLocationSharing: json['effectiveLocationSharing'] as bool,
    );
  }
}
