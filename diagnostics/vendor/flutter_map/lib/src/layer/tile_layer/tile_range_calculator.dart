import 'dart:ui';
import 'package:flutter_map/bond_map_diagnostics.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/layer/tile_layer/tile_range.dart';
import 'package:flutter_map/src/misc/extensions.dart';
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

/// The [TileRangeCalculator] helps to calculate the bounds in pixel.
@immutable
class TileRangeCalculator {
  /// The tile size in pixels.
  final int tileDimension;

  /// Create a new [TileRangeCalculator] instance.
  const TileRangeCalculator({required this.tileDimension});

  /// Calculates the visible pixel bounds at the [tileZoom] zoom level when
  /// viewing the map from the [viewingZoom] centered at the [center]. The
  /// resulting tile range is expanded by panBuffer.
  DiscreteTileRange calculate({
    // The map camera used to calculate the bounds.
    required MapCamera camera,
    // The zoom level at which the bounds should be calculated.
    required int tileZoom,
    // The center from which the map is viewed, defaults to [camera.center].
    LatLng? center,
    // The zoom from which the map is viewed, defaults to [camera.zoom].
    double? viewingZoom,
  }) {
    return DiscreteTileRange.fromPixelBounds(
      zoom: tileZoom,
      tileDimension: tileDimension,
      pixelBounds: _calculatePixelBounds(
        camera,
        center ?? camera.center,
        viewingZoom ?? camera.zoom,
        tileZoom,
      ),
    );
  }

  Rect _calculatePixelBounds(
    MapCamera camera,
    LatLng center,
    double viewingZoom,
    int tileZoom,
  ) {
    final tileZoomDouble = tileZoom.toDouble();
    final scale = camera.getZoomScale(viewingZoom, tileZoomDouble);
    final projectedCenter = camera.projectAtZoom(center, tileZoomDouble);
    String context() => 'cameraZoom=${camera.zoom} viewingZoom=$viewingZoom '
        'tileZoom=$tileZoom lat=${center.latitude} lon=${center.longitude} '
        'cameraLat=${camera.center.latitude} cameraLon=${camera.center.longitude} '
        'projectedX=${projectedCenter.dx} projectedY=${projectedCenter.dy} '
        'sizeWidth=${camera.size.width} sizeHeight=${camera.size.height} '
        'viewportWidth=${camera.nonRotatedSize.width} viewportHeight=${camera.nonRotatedSize.height} scale=$scale '
        'tileDimension=$tileDimension';
    if (BondMapDiagnostics.enabled &&
        (!projectedCenter.dx.isFinite || !projectedCenter.dy.isFinite)) {
      BondMapDiagnostics.anomaly('PRE_PROJECTED_FLOOR ${context()} '
          'pixelBounds=not_computed rowColumn=not_computed');
    }
    final pixelCenter = projectedCenter.floor();
    final halfSize = camera.size / (scale * 2);

    final bounds = Rect.fromPoints(
      pixelCenter - halfSize.bottomRight(Offset.zero),
      pixelCenter + halfSize.bottomRight(Offset.zero),
    );
    if (BondMapDiagnostics.enabled) {
      final values = <double>[
        bounds.left / tileDimension,
        bounds.top / tileDimension,
        bounds.right / tileDimension,
        bounds.bottom / tileDimension,
      ];
      final invalid = values.any((value) => !value.isFinite) ||
          !scale.isFinite ||
          scale == 0 ||
          !viewingZoom.isFinite;
      if (invalid || BondMapDiagnostics.due('tiles', 250)) {
        final sample = 'TILES ${context()} '
            'pixelLeft=${bounds.left} pixelTop=${bounds.top} '
            'pixelRight=${bounds.right} pixelBottom=${bounds.bottom} '
            'columnXMinFloor=${values[0]} rowYMinFloor=${values[1]} '
            'columnXMaxCeil=${values[2]} rowYMaxCeil=${values[3]} '
            'empty=${bounds.isEmpty}';
        BondMapDiagnostics.record(sample);
        if (invalid) BondMapDiagnostics.anomaly(sample);
      }
    }
    return bounds;
  }
}
