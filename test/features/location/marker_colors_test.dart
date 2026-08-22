import 'package:bond_front/features/location/utils/marker_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns no colors when nobody is visible', () {
    expect(buildDistinctMarkerColors(const <int>[]), isEmpty);
  });

  test('assigns a distinct stable color to every visible marker', () {
    final first = buildDistinctMarkerColors(const <int>[5, 1, 3]);
    final second = buildDistinctMarkerColors(const <int>[3, 5, 1]);
    expect(first, second);
    expect(first.values.toSet(), hasLength(3));
  });
}
