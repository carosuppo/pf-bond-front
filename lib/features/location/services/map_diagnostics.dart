import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/bond_map_diagnostics.dart';

/// One owner per mounted map; no timer or listener when disabled.
class MapDiagnostics {
  static int _nextId = 0;
  final int _id = _nextId++;
  Timer? _timer;
  int members = 0;
  int clusters = 0;
  int points = 0;
  int routePoints = 0;
  String? _latestCamera;

  MapDiagnostics() {
    if (!BondMapDiagnostics.enabled) return;
    BondMapDiagnostics.emit(
      'START map=$_id flutter_map=8.3.1 '
      'frontend=${const String.fromEnvironment('BOND_FRONTEND_COMMIT', defaultValue: 'unspecified')}',
    );
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final ImageCache cache = PaintingBinding.instance.imageCache;
      BondMapDiagnostics.emit(
        'MEMORY map=$_id imageCacheBytes=${cache.currentSizeBytes} '
        'entries=${cache.currentSize} live=${cache.liveImageCount} '
        'pending=${cache.pendingImageCount} '
        'members=$members clusters=$clusters poi=$points routePoints=$routePoints '
        'latestCamera=$_latestCamera',
      );
    });
  }

  void onEvent(MapEvent event) {
    if (!BondMapDiagnostics.enabled) return;
    final MapCamera camera = event.camera;
    final bool invalid =
        !camera.zoom.isFinite ||
        !camera.center.latitude.isFinite ||
        !camera.center.longitude.isFinite ||
        !camera.nonRotatedSize.width.isFinite ||
        !camera.nonRotatedSize.height.isFinite;
    if (!invalid && !BondMapDiagnostics.due('camera-$_id', 250)) return;
    final String sample =
        'CAMERA map=$_id event=${event.runtimeType} '
        'source=${event.source} zoom=${camera.zoom} '
        'lat=${camera.center.latitude} lon=${camera.center.longitude} '
        'viewportWidth=${camera.nonRotatedSize.width} viewportHeight=${camera.nonRotatedSize.height} '
        'sizeWidth=${camera.size.width} sizeHeight=${camera.size.height} rotation=${camera.rotation} '
        'members=$members clusters=$clusters poi=$points routePoints=$routePoints';
    _latestCamera = '${DateTime.now().toUtc().toIso8601String()} $sample';
    BondMapDiagnostics.record(sample);
    if (invalid) BondMapDiagnostics.anomaly(sample);
  }

  void dispose() {
    _timer?.cancel();
    BondMapDiagnostics.release('camera-$_id');
  }
}
