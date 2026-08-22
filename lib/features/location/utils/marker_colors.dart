import 'package:flutter/material.dart';

Map<int, Color> buildDistinctMarkerColors(Iterable<int> memberIds) {
  final ids = memberIds.toList()..sort();
  if (ids.isEmpty) return const <int, Color>{};
  return <int, Color>{
    for (var index = 0; index < ids.length; index++)
      ids[index]: HSLColor.fromAHSL(
        1,
        index * 360 / ids.length,
        0.75,
        0.5,
      ).toColor(),
  };
}
