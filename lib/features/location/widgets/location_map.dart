import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../constants/default_location.dart';
import '../../point_of_interest/models/point_of_interest_color.dart';
import '../constants/location_tracking_config.dart';
import '../models/member_location_model.dart';
import '../providers/location_provider.dart';
import '../utils/marker_colors.dart';
import '../../point_of_interest/models/point_of_interest.dart';

class LocationMap extends ConsumerStatefulWidget {
  final int? groupId;
  final VoidCallback? onMapTap;
  final void Function(int memberId)? onMemberTap;
  final List<PointOfInterest> points;
  final LatLng? previewPoint;
  final double? previewRadius;
  final PointOfInterestColor previewColor;
  final ValueChanged<LatLng>? onTap;
  final MapController? controller;
  final double indicatorBottomFraction;

  const LocationMap({
    super.key,
    required this.groupId,
    this.onMapTap,
    this.onMemberTap,
    this.points = const [],
    this.previewPoint,
    this.previewRadius,
    this.previewColor = PointOfInterestColor.blue,
    this.onTap,
    this.controller,
    this.indicatorBottomFraction = 0,
  });

  @override
  ConsumerState<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends ConsumerState<LocationMap> {
  late final MapController _mapController =
      widget.controller ?? MapController();

  bool _hasCenteredOnUser = false;

  Timer? _freshnessTimer;

  @override
  void initState() {
    super.initState();

    _freshnessTimer = Timer.periodic(
      LocationTrackingConfig.freshnessRefreshInterval,
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationProvider);

    final now = DateTime.now();

    final ownSharing = widget.groupId == null
        ? false
        : state.sharingForGroup(widget.groupId!)?.effectiveLocationSharing ??
              false;

    final ownLocation = ownSharing ? state.currentLocation : null;

    final allMembers = state.visibleMembers.values.toList();

    final members =
        allMembers.where((member) => _shouldShowMember(member, now)).toList()
          ..sort((a, b) => a.memberId.compareTo(b.memberId));

    // Usamos todos los IDs conocidos para
    // evitar cambiar colores solamente
    // porque uno quedó temporalmente oculto.
    final markerIds = <int>[
      if (ownLocation != null) -1,
      ...allMembers.map((member) => member.memberId),
    ];

    final colors = buildDistinctMarkerColors(markerIds);

    if (!_hasCenteredOnUser && ownLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasCenteredOnUser) {
          return;
        }

        _mapController.move(
          LatLng(ownLocation.latitude, ownLocation.longitude),
          defaultZoom,
        );

        _hasCenteredOnUser = true;
      });
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: ownLocation == null
            ? defaultLocation
            : LatLng(ownLocation.latitude, ownLocation.longitude),
        initialZoom: defaultZoom,
        onTap: (_, point) {
          if (widget.onTap != null) {
            widget.onTap!(point);
            return;
          }

          widget.onMapTap?.call();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.bond_front',
        ),
        CircleLayer(
          circles: [
            for (final point in widget.points)
              CircleMarker(
                point: LatLng(point.latitude, point.longitude),
                radius: point.radius,
                useRadiusInMeter: true,
                color: point.color.visualColor.withAlpha(45),
                borderColor: point.color.visualColor,
                borderStrokeWidth: 2,
              ),
            if (widget.previewPoint != null && widget.previewRadius != null)
              CircleMarker(
                point: widget.previewPoint!,
                radius: widget.previewRadius!,
                useRadiusInMeter: true,
                color: widget.previewColor.visualColor.withAlpha(55),
                borderColor: widget.previewColor.visualColor,
                borderStrokeWidth: 2,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (ownLocation != null)
              _memberMarker(
                point: LatLng(ownLocation.latitude, ownLocation.longitude),
                name: 'Vos',
                color: colors[-1] ?? Colors.blue,
              ),
            for (final member in members)
              _memberMarker(
                point: LatLng(member.latitude, member.longitude),
                name: member.name,
                color: colors[member.memberId] ?? Colors.blue,
                isStale: _isStale(member, now),
                lastSeenAt: member.lastSeenAt,
                now: now,

                onTap: widget.onMemberTap == null
                    ? null
                    : () => widget.onMemberTap!(member.memberId),
              ),
            for (final point in widget.points)
              _pointOfInterestMarker(
                point: LatLng(point.latitude, point.longitude),
                name: point.name,
                color: point.color.visualColor,
              ),
            if (widget.previewPoint != null)
              _pointOfInterestMarker(
                point: widget.previewPoint!,
                name: 'Vista previa',
                color: widget.previewColor.visualColor,
              ),
          ],
        ),
        Positioned.fill(
          child: _OffscreenLocationIndicatorLayer(
            locations: [
              if (ownLocation != null)
                _OffscreenLocation(
                  point: LatLng(ownLocation.latitude, ownLocation.longitude),
                  color: colors[-1] ?? Colors.blue,
                ),
              for (final member in members)
                _OffscreenLocation(
                  point: LatLng(member.latitude, member.longitude),
                  color: colors[member.memberId] ?? Colors.blue,
                  stale: _isStale(member, now),
                ),
            ],
            bottomFraction: widget.indicatorBottomFraction,
            onLocationTap: (point) =>
                _mapController.move(point, _mapController.camera.zoom),
          ),
        ),
      ],
    );
  }

  bool _shouldShowMember(MemberLocationModel member, DateTime now) {
    final lastSeenAt = member.lastSeenAt;

    // Una Location anterior a esta feature
    // no tiene heartbeat válido.
    if (lastSeenAt == null) {
      return false;
    }

    return _age(lastSeenAt, now) < LocationTrackingConfig.hideAfter;
  }

  bool _isStale(MemberLocationModel member, DateTime now) {
    final lastSeenAt = member.lastSeenAt;

    if (lastSeenAt == null) {
      return true;
    }

    return _age(lastSeenAt, now) >= LocationTrackingConfig.staleAfter;
  }

  Duration _age(DateTime lastSeenAt, DateTime now) {
    final difference = now.difference(lastSeenAt);

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  Marker _pointOfInterestMarker({
    required LatLng point,
    required String name,
    required Color color,
  }) {
    return Marker(
      point: point,
      rotate: true,
      width: 150,
      height: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 42, color: color),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Marker _memberMarker({
    required LatLng point,
    required String name,
    required Color color,
    bool isStale = false,
    DateTime? lastSeenAt,
    DateTime? now,
    VoidCallback? onTap,
  }) {
    final markerColor = isStale ? color.withAlpha(110) : color;
    final markerContent = Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        Icon(Icons.location_pin, size: 42, color: markerColor),

        Text(
          name,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

          textAlign: TextAlign.center,

          style: TextStyle(
            color: isStale ? Colors.black54 : Colors.black87,

            fontSize: 13,

            fontWeight: FontWeight.w600,
          ),
        ),

        if (isStale && lastSeenAt != null && now != null)
          Text(
            _formatLastSeen(lastSeenAt, now),

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: Colors.black54,

              fontSize: 10,

              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );

    return Marker(
      point: point,
      rotate: true,
      width: 150,
      height: isStale ? 84 : 66,
      child: onTap == null
          ? markerContent
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: markerContent,
            ),
    );
  }

  String _formatLastSeen(DateTime lastSeenAt, DateTime now) {
    final age = _age(lastSeenAt, now);

    if (age.inMinutes < 1) {
      return 'Actualizado hace menos de 1 min';
    }

    if (age.inHours < 1) {
      return 'Actualizado hace ${age.inMinutes} min';
    }

    if (age.inDays < 1) {
      return 'Actualizado hace ${age.inHours} h';
    }

    return 'Actualizado hace ${age.inDays} d';
  }
}

class _OffscreenLocationIndicatorLayer extends StatelessWidget {
  static const _indicatorSize = Size(36, 36);

  static const _edgePadding = EdgeInsets.fromLTRB(12, 72, 12, 12);

  const _OffscreenLocationIndicatorLayer({
    required this.locations,
    required this.bottomFraction,
    required this.onLocationTap,
  });

  final List<_OffscreenLocation> locations;
  final double bottomFraction;
  final ValueChanged<LatLng> onLocationTap;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        if (!size.width.isFinite || !size.height.isFinite || size.isEmpty) {
          return const SizedBox.shrink();
        }

        final viewport = Offset.zero & size;

        final safeBounds = Rect.fromLTRB(
          _edgePadding.left + _indicatorSize.width / 2,
          _edgePadding.top + _indicatorSize.height / 2,
          size.width - _edgePadding.right - _indicatorSize.width / 2,
          size.height * (1 - bottomFraction) -
              _edgePadding.bottom -
              _indicatorSize.height / 2,
        );

        if (safeBounds.width <= 0 || safeBounds.height <= 0) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            for (final location in locations)
              if (_indicatorPosition(
                    camera: camera,
                    viewport: viewport,
                    safeBounds: safeBounds,
                    point: location.point,
                  )
                  case final indicator?)
                Positioned(
                  left: indicator.position.dx - _indicatorSize.width / 2,
                  top: indicator.position.dy - _indicatorSize.height / 2,
                  width: _indicatorSize.width,
                  height: _indicatorSize.height,
                  child: GestureDetector(
                    onTap: () => onLocationTap(location.point),
                    child: _OffscreenLocationIndicator(
                      color: location.displayColor,
                      angle: indicator.angle,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  _IndicatorPlacement? _indicatorPosition({
    required MapCamera camera,
    required Rect viewport,
    required Rect safeBounds,
    required LatLng point,
  }) {
    final projected = camera.latLngToScreenOffset(point);

    if (!projected.dx.isFinite ||
        !projected.dy.isFinite ||
        viewport.contains(projected)) {
      return null;
    }

    final direction = projected - viewport.center;

    if (direction.distanceSquared == 0) {
      return null;
    }

    final origin = safeBounds.center;

    final horizontalScale = direction.dx == 0
        ? double.infinity
        : (direction.dx > 0
                  ? safeBounds.right - origin.dx
                  : safeBounds.left - origin.dx) /
              direction.dx;

    final verticalScale = direction.dy == 0
        ? double.infinity
        : (direction.dy > 0
                  ? safeBounds.bottom - origin.dy
                  : safeBounds.top - origin.dy) /
              direction.dy;

    final scale = math.min(horizontalScale, verticalScale);

    if (!scale.isFinite || scale < 0) {
      return null;
    }

    return _IndicatorPlacement(
      position: origin + direction * scale,
      angle: math.atan2(direction.dy, direction.dx) + math.pi / 2,
    );
  }
}

class _OffscreenLocationIndicator extends StatelessWidget {
  const _OffscreenLocationIndicator({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: angle,
          child: const Icon(Icons.navigation, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _OffscreenLocation {
  const _OffscreenLocation({
    required this.point,
    required this.color,
    this.stale = false,
  });

  final LatLng point;
  final Color color;
  final bool stale;

  Color get displayColor {
    return stale ? color.withAlpha(110) : color;
  }
}

class _IndicatorPlacement {
  const _IndicatorPlacement({required this.position, required this.angle});

  final Offset position;
  final double angle;
}
