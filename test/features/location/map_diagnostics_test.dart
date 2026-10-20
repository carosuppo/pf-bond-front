import 'dart:ui';

import 'package:bond_front/features/location/services/map_diagnostics.dart';

import 'package:flutter_map/bond_map_diagnostics.dart';
import 'package:flutter_map/flutter_map.dart';
// Deliberately exercise the patched conversion boundary, not the network.
// ignore: implementation_imports
import 'package:flutter_map/src/layer/tile_layer/tile_range.dart';
// ignore: implementation_imports
import 'package:flutter_map/src/layer/tile_layer/tile_range_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('finite tile calculation retains the original range', () {
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(0, 0),
      zoom: 2,
      rotation: 0,
      nonRotatedSize: const Size(256, 256),
    );
    final range = const TileRangeCalculator(
      tileDimension: 256,
    ).calculate(camera: camera, tileZoom: 2);
    expect(range.min.x, 1);
    expect(range.min.y, 1);
    expect(range.max.x, 2);
    expect(range.max.y, 2);
  });

  test('invalid range is logged when enabled and still throws', () {
    final messages = <String>[];
    final previous = BondMapDiagnostics.output;
    BondMapDiagnostics.output = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      for (int i = 0; i < 100; i++) {
        BondMapDiagnostics.record('camera sample $i');
      }
      expect(
        BondMapDiagnostics.historyLength,
        BondMapDiagnostics.enabled ? 24 : 0,
      );
      for (int i = 0; i < 100; i++) {
        expect(
          () => DiscreteTileRange.fromPixelBounds(
            zoom: 2,
            tileDimension: 256,
            pixelBounds: const Rect.fromLTRB(double.nan, 0, double.infinity, 1),
          ),
          throwsUnsupportedError,
        );
      }
      expect(BondMapDiagnostics.dumpCount, BondMapDiagnostics.enabled ? 1 : 0);
      expect(messages.length, BondMapDiagnostics.enabled ? 25 : 0);
      if (BondMapDiagnostics.enabled) {
        expect(messages.first, contains('columnXMinFloor=NaN'));
        expect(messages.first, contains('columnXMaxCeil=Infinity'));
      }
      final camera = MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(0, 0),
        zoom: 2,
        rotation: 0,
        nonRotatedSize: const Size(256, 256),
      );
      expect(
        () => const TileRangeCalculator(
          tileDimension: 256,
        ).calculate(camera: camera, tileZoom: 2, viewingZoom: -2000),
        throwsUnsupportedError,
      );
      if (BondMapDiagnostics.enabled) {
        expect(
          messages.any(
            (line) =>
                line.contains('ANOMALY') &&
                line.contains('TILES') &&
                line.contains('scale=0.0') &&
                line.contains('projectedX=512.0') &&
                line.contains('columnXMinFloor=-Infinity'),
          ),
          isTrue,
        );
      } else {
        expect(messages, isEmpty);
      }
    } finally {
      BondMapDiagnostics.output = previous;
    }
  });

  testWidgets('owner disposes periodic sampling; disabled owner has no timer', (
    tester,
  ) async {
    final messages = <String>[];
    final previous = BondMapDiagnostics.output;
    BondMapDiagnostics.output = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      final diagnostics = MapDiagnostics();
      await tester.pump(const Duration(seconds: 5));
      expect(
        messages.any((line) => line.contains('MEMORY')),
        BondMapDiagnostics.enabled,
      );
      diagnostics.dispose();
      final count = messages.length;
      await tester.pump(const Duration(seconds: 10));
      expect(messages.length, count);
    } finally {
      BondMapDiagnostics.output = previous;
    }
  });
}
