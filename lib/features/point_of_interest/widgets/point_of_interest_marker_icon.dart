import 'package:flutter/material.dart';

class PointOfInterestMarkerIcon extends StatelessWidget {
  const PointOfInterestMarkerIcon({
    super.key,
    required this.color,
    this.size = 24,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, size: size, color: color);
  }
}
