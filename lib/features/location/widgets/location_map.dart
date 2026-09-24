import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../point_of_interest/models/point_of_interest.dart';
import '../../point_of_interest/models/point_of_interest_color.dart';
import '../constants/default_location.dart';
import '../constants/location_tracking_config.dart';
import '../models/member_location_model.dart';
import '../providers/location_provider.dart';
import '../utils/marker_colors.dart';

class LocationMap extends ConsumerStatefulWidget {
  final int? groupId;
  final bool showMembers;
  final VoidCallback? onMapTap;
  final void Function(int memberId)? onMemberTap;
  final List<PointOfInterest> points;
  final LatLng? previewPoint;
  final double? previewRadius;
  final PointOfInterestColor previewColor;
  final ValueChanged<LatLng>? onTap;
  final MapController? controller;
  final String? ownProfilePhoto;
  final String? ownProfileName;
  final double indicatorBottomFraction;
  final bool showOffscreenPoints;

  const LocationMap({
    super.key,
    required this.groupId,
    this.showMembers = true,
    this.onMapTap,
    this.onMemberTap,
    this.points = const [],
    this.previewPoint,
    this.previewRadius,
    this.previewColor = PointOfInterestColor.blue,
    this.onTap,
    this.controller,
    this.ownProfilePhoto,
    this.ownProfileName,
    this.indicatorBottomFraction = 0,
    this.showOffscreenPoints = false,
  });

  @override
  ConsumerState<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends ConsumerState<LocationMap>
    with SingleTickerProviderStateMixin<LocationMap> {
  static const _memberClusterDistanceMeters = 50.0;
  static const _memberClusterPhotoGap = 5.0;
  static const _memberMovementDuration = Duration(milliseconds: 700);
  static const Distance _distanceCalculator = Distance(roundResult: false);

  late final MapController _mapController =
      widget.controller ?? MapController();

  bool _mapReady = false;
  bool _hasCenteredOnUser = false;
  LatLng? _ownLocationToCenter;

  Timer? _freshnessTimer;
  late final AnimationController _memberMovementController;
  final Map<int, LatLng> _memberMovementStarts = {};
  final Map<int, LatLng> _memberMovementTargets = {};
  double _memberMovementProgress = 0;
  bool _memberMovementStartScheduled = false;

  @override
  void initState() {
    super.initState();

    _memberMovementController = AnimationController(
      vsync: this,
      duration: _memberMovementDuration,
    )..addListener(_handleMemberMovementTick);

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
    _memberMovementController.dispose();

    super.dispose();
  }

  void _handleMemberMovementTick() {
    _memberMovementProgress = _memberMovementController.value;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldPreviewPoint = oldWidget.previewPoint;
    final newPreviewPoint = widget.previewPoint;

    if (!_samePoint(oldPreviewPoint, newPreviewPoint) &&
        newPreviewPoint != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) {
          _mapController.move(newPreviewPoint, defaultZoom);
        }
      });
    }
  }

  void _handleMapReady() {
    _mapReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });

    final previewPoint = widget.previewPoint;
    if (previewPoint != null) {
      _mapController.move(previewPoint, defaultZoom);
      _hasCenteredOnUser = true;
      return;
    }

    final ownLocation = _ownLocationToCenter;
    if (!_hasCenteredOnUser && ownLocation != null) {
      _mapController.move(ownLocation, defaultZoom);
      _hasCenteredOnUser = true;
    }
  }

  bool _samePoint(LatLng? first, LatLng? second) {
    return first?.latitude == second?.latitude &&
        first?.longitude == second?.longitude;
  }

  void _updateMemberMovement(Map<int, LatLng> targetLocations) {
    var movementStarted = false;

    for (final entry in targetLocations.entries) {
      final previousTarget = _memberMovementTargets[entry.key];

      if (previousTarget == null) {
        _memberMovementStarts[entry.key] = entry.value;
      } else if (!_samePoint(previousTarget, entry.value)) {
        _memberMovementStarts[entry.key] = _animatedPoint(
          entry.key,
          previousTarget,
        );
        movementStarted = true;
      }

      _memberMovementTargets[entry.key] = entry.value;
    }

    final removedIds = _memberMovementTargets.keys
        .where((memberId) => !targetLocations.containsKey(memberId))
        .toList();
    for (final memberId in removedIds) {
      _memberMovementStarts.remove(memberId);
      _memberMovementTargets.remove(memberId);
    }

    if (!movementStarted || _memberMovementStartScheduled) {
      return;
    }

    _memberMovementController.stop();
    _memberMovementProgress = 0;
    _memberMovementStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _memberMovementStartScheduled = false;
      _memberMovementController.forward(from: 0);
    });
  }

  LatLng _animatedPoint(int memberId, LatLng fallback) {
    final start = _memberMovementStarts[memberId];
    final target = _memberMovementTargets[memberId];

    if (start == null || target == null) {
      return fallback;
    }

    return LatLng(
      start.latitude +
          (target.latitude - start.latitude) * _memberMovementProgress,
      start.longitude +
          (target.longitude - start.longitude) * _memberMovementProgress,
    );
  }

  MemberLocationModel _animatedMember(MemberLocationModel member) {
    final point = _animatedPoint(
      member.memberId,
      LatLng(member.latitude, member.longitude),
    );

    return member.copyWith(
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationProvider);

    final now = DateTime.now();

    final ownSharing =
        widget.showMembers &&
        widget.groupId != null &&
        state.sharingForGroup(widget.groupId!)?.effectiveLocationSharing ==
            true;

    final ownLocation = ownSharing ? state.currentLocation : null;

    final allMembers = state.visibleMembers.values.toList();

    final members = widget.showMembers ? allMembers : <MemberLocationModel>[];

    if (widget.showMembers) {
      members.sort((a, b) => a.memberId.compareTo(b.memberId));
    }

    final targetLocations = <int, LatLng>{
      if (ownLocation != null)
        -1: LatLng(ownLocation.latitude, ownLocation.longitude),
      for (final member in members)
        member.memberId: LatLng(member.latitude, member.longitude),
    };
    _updateMemberMovement(targetLocations);

    final animatedOwnLocation = ownLocation == null
        ? null
        : _animatedPoint(
            -1,
            LatLng(ownLocation.latitude, ownLocation.longitude),
          );
    final animatedMembers = [
      for (final member in members) _animatedMember(member),
    ];

    final membersForClustering = [
      if (ownLocation != null && animatedOwnLocation != null)
        MemberLocationModel(
          memberId: -1,
          userId: -1,
          name: widget.ownProfileName ?? 'Vos',
          profilePhoto: widget.ownProfilePhoto,
          latitude: animatedOwnLocation.latitude,
          longitude: animatedOwnLocation.longitude,
          accuracy: ownLocation.accuracy,
          capturedAt: ownLocation.timestamp,
          lastSeenAt: ownLocation.timestamp,
        ),
      ...animatedMembers,
    ];
    final memberClusters = _buildMemberClusters(membersForClustering);

    // Usamos todos los IDs conocidos para
    // evitar cambiar colores solamente
    // porque uno quedó temporalmente oculto.
    final markerIds = widget.showMembers
        ? <int>[
            if (ownLocation != null) -1,
            ...allMembers.map((member) => member.memberId),
          ]
        : <int>[];

    final colors = buildDistinctMarkerColors(markerIds);

    if (!_hasCenteredOnUser && ownLocation != null) {
      _ownLocationToCenter = LatLng(
        ownLocation.latitude,
        ownLocation.longitude,
      );

      if (_mapReady) {
        final point = _ownLocationToCenter!;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hasCenteredOnUser) {
            return;
          }

          _mapController.move(point, defaultZoom);
          _hasCenteredOnUser = true;
        });
      }
    }

    final initialCenter =
        widget.previewPoint ??
        (ownLocation == null
            ? defaultLocation
            : LatLng(ownLocation.latitude, ownLocation.longitude));
    final String? cartoApiKey = dotenv.isInitialized
        ? dotenv.env['CARTO_API_KEY']
        : null;
    final String tileUrl = cartoApiKey == null || cartoApiKey.isEmpty
        ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=$cartoApiKey';

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: defaultZoom,
        onMapReady: _handleMapReady,
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
          urlTemplate: tileUrl,
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.bond_front',
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('CARTO'),
          ],
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
            for (final cluster in memberClusters)
              _memberClusterMarker(cluster, now),
            for (final point in widget.points)
              _pointOfInterestMarker(
                point: LatLng(point.latitude, point.longitude),
                name: point.name,
                color: point.color.visualColor,
              ),
            if (widget.previewPoint != null && widget.previewRadius != null)
              _pointOfInterestMarker(
                point: widget.previewPoint!,
                name: 'Vista previa',
                color: widget.previewColor.visualColor,
              ),
            if (widget.previewPoint != null && widget.previewRadius == null)
              _eventLocationMarker(widget.previewPoint!),
          ],
        ),
        Positioned.fill(
          child: _OffscreenLocationIndicatorLayer(
            locations: [
              if (animatedOwnLocation != null)
                _OffscreenLocation(
                  point: LatLng(ownLocation!.latitude, ownLocation.longitude),
                  color: colors[-1] ?? Colors.blue,
                  avatarName: widget.ownProfileName ?? 'Vos',
                  photoUrl: widget.ownProfilePhoto,
                ),
              for (final member in members)
                _OffscreenLocation(
                  point: LatLng(member.latitude, member.longitude),
                  color: colors[member.memberId] ?? Colors.blue,
                  avatarName: member.name,
                  photoUrl: member.profilePhoto,
                  stale: _isStale(member, now),
                ),
              if (widget.showOffscreenPoints)
                for (final point in widget.points)
                  _OffscreenLocation(
                    point: LatLng(point.latitude, point.longitude),
                    color: point.color.visualColor,
                    icon: Icons.flag_rounded,
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

  List<_MemberCluster> _buildMemberClusters(List<MemberLocationModel> members) {
    if (members.length < 2) {
      return members
          .map((member) => _MemberCluster(members: [member]))
          .toList(growable: false);
    }

    final pending = [...members];
    final clusters = <_MemberCluster>[];

    while (pending.isNotEmpty) {
      final clusterMembers = <MemberLocationModel>[pending.removeAt(0)];
      var expanded = true;

      while (expanded) {
        expanded = false;

        for (var index = pending.length - 1; index >= 0; index--) {
          final candidate = pending[index];
          final isClose = clusterMembers.any(
            (member) =>
                _geographicDistance(member, candidate) <
                _memberClusterDistanceMeters,
          );

          if (isClose) {
            clusterMembers.add(candidate);
            pending.removeAt(index);
            expanded = true;
          }
        }
      }

      clusters.add(_MemberCluster(members: clusterMembers));
    }

    return clusters;
  }

  double _geographicDistance(
    MemberLocationModel first,
    MemberLocationModel second,
  ) {
    return _distanceCalculator.as(
      LengthUnit.Meter,
      LatLng(first.latitude, first.longitude),
      LatLng(second.latitude, second.longitude),
    );
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
    String? avatarName,
    String? photoUrl,
    bool isStale = false,
    DateTime? lastSeenAt,
    DateTime? now,
    VoidCallback? onTap,
  }) {
    final markerContent = Column(
      mainAxisSize: MainAxisSize.min,

      children: [
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

        _memberAvatar(
          name: avatarName ?? name,
          photoUrl: photoUrl,
          radius: 19,
          isStale: isStale,
          borderColor: AppColors.primary,
          borderWidth: 2,
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
      height: isStale ? 94 : 76,
      child: onTap == null
          ? markerContent
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: markerContent,
            ),
    );
  }

  Widget _memberAvatar({
    required String name,
    required String? photoUrl,
    required double radius,
    required bool isStale,
    Color? borderColor,
    double borderWidth = 0,
    VoidCallback? onTap,
  }) {
    final avatar = UserAvatar(
      name: name,
      photoUrl: photoUrl,
      radius: radius,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );

    final content = isStale ? Opacity(opacity: 0.5, child: avatar) : avatar;

    return onTap == null
        ? content
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: content,
          );
  }

  Marker _memberClusterMarker(_MemberCluster cluster, DateTime now) {
    if (cluster.members.length == 1) {
      final member = cluster.members.first;

      return _memberMarker(
        point: LatLng(member.latitude, member.longitude),
        name: member.memberId == -1 ? 'Vos' : member.name,
        avatarName: member.name,
        photoUrl: member.profilePhoto,
        isStale: _isStale(member, now),
        lastSeenAt: member.lastSeenAt,
        now: now,
        onTap: widget.onMemberTap == null
            ? null
            : member.memberId == -1
            ? null
            : () => widget.onMemberTap!(member.memberId),
      );
    }

    final count = cluster.members.length;
    final avatarRadius = count > 4
        ? 11.0
        : count > 2
        ? 14.0
        : 17.0;
    final columns = math.min(2, count);
    final rows = (count + columns - 1) ~/ columns;
    final avatarDiameter = avatarRadius * 2;
    final contentWidth =
        columns * avatarDiameter + (columns - 1) * _memberClusterPhotoGap;
    final contentHeight =
        rows * avatarDiameter + (rows - 1) * _memberClusterPhotoGap;
    final width = contentWidth + 16;
    final height = contentHeight + 16;

    return Marker(
      point: cluster.center,
      rotate: true,
      width: width,
      height: height,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        padding: const EdgeInsets.all(6),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: _memberClusterPhotoGap,
          runSpacing: _memberClusterPhotoGap,
          children: [
            for (final member in cluster.members)
              _memberAvatar(
                name: member.name,
                photoUrl: member.profilePhoto,
                radius: avatarRadius,
                isStale: _isStale(member, now),
                onTap: widget.onMemberTap == null || member.memberId == -1
                    ? null
                    : () => widget.onMemberTap!(member.memberId),
              ),
          ],
        ),
      ),
    );
  }

  Marker _eventLocationMarker(LatLng point) {
    return Marker(
      point: point,
      rotate: true,
      width: 150,
      height: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_pin, size: 42, color: AppColors.error),
        ],
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

class _MemberCluster {
  final List<MemberLocationModel> members;

  const _MemberCluster({required this.members});

  LatLng get center {
    final latitude = members.fold<double>(
      0,
      (sum, member) => sum + member.latitude,
    );
    final longitude = members.fold<double>(
      0,
      (sum, member) => sum + member.longitude,
    );

    return LatLng(latitude / members.length, longitude / members.length);
  }
}

class _OffscreenLocationIndicatorLayer extends StatelessWidget {
  static const _indicatorSize = Size(54, 78);

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
                      icon: location.icon,
                      arrowColor: location.avatarName == null
                          ? location.displayColor
                          : AppColors.primary,
                      avatarName: location.avatarName,
                      photoUrl: location.photoUrl,
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
  const _OffscreenLocationIndicator({
    required this.color,
    required this.angle,
    required this.icon,
    required this.arrowColor,
    this.avatarName,
    this.photoUrl,
  });

  final Color color;
  final double angle;
  final IconData icon;
  final Color arrowColor;
  final String? avatarName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final memberContent = avatarName == null
        ? Transform.rotate(
            angle: angle,
            child: Icon(icon, size: 20, color: Colors.white),
          )
        : UserAvatar(name: avatarName!, photoUrl: photoUrl, radius: 14);
    final directionAngle = angle - math.pi / 2;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: memberContent),
        ),
        Transform.translate(
          offset: Offset(
            math.cos(directionAngle) * 29,
            math.sin(directionAngle) * 29,
          ),
          child: Transform.rotate(
            angle: angle,
            child: Icon(Icons.navigation, size: 17, color: arrowColor),
          ),
        ),
      ],
    );
  }
}

class _OffscreenLocation {
  const _OffscreenLocation({
    required this.point,
    required this.color,
    this.icon = Icons.navigation,
    this.avatarName,
    this.photoUrl,
    this.stale = false,
  });

  final LatLng point;
  final Color color;
  final IconData icon;
  final String? avatarName;
  final String? photoUrl;
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
