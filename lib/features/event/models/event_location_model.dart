class EventLocationModel {
  final double latitude;
  final double longitude;

  const EventLocationModel({required this.latitude, required this.longitude});

  factory EventLocationModel.fromJson(Map<String, dynamic> json) {
    return EventLocationModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
