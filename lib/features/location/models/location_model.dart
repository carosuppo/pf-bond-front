class LocationModel {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  LocationModel copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'LocationModel('
        'latitude: $latitude, '
        'longitude: $longitude, '
        'accuracy: $accuracy, '
        'timestamp: $timestamp'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationModel &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracy == accuracy &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(latitude, longitude, accuracy, timestamp);
  }
}
