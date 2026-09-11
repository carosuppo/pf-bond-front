import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../constants/default_location.dart';
import '../constants/location_tracking_config.dart';
import '../models/member_location_model.dart';
import '../providers/location_provider.dart';
import '../utils/marker_colors.dart';

class LocationMap extends ConsumerStatefulWidget {
  final int? groupId;
  final LatLng? previewPoint;
  final ValueChanged<LatLng>? onTap;
  final MapController? controller;
  final bool showMembers;

  const LocationMap({
    super.key,
    required this.groupId,
    this.previewPoint,
    this.onTap,
    this.controller,
    this.showMembers = true,
  });

  @override
  ConsumerState<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends ConsumerState<LocationMap> {
  late final MapController _mapController =
      widget.controller ?? MapController();

  bool _mapReady = false;
  bool _hasCenteredOnUser = false;
  LatLng? _ownLocationToCenter;

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

    final previewPoint = widget.previewPoint;
    if (previewPoint != null) {
      _mapController.move(previewPoint, defaultZoom);
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

    final members = widget.showMembers
        ? allMembers.where((member) => _shouldShowMember(member, now)).toList()
        : <MemberLocationModel>[];

    if (widget.showMembers) {
      members.sort((a, b) => a.memberId.compareTo(b.memberId));
    }

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

    return FlutterMap(
      mapController: _mapController,

      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: defaultZoom,
        onMapReady: _handleMapReady,
        onTap: widget.onTap == null ? null : (_, point) => widget.onTap!(point),
      ),

      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

          userAgentPackageName: 'com.example.bond_front',
        ),

        MarkerLayer(
          markers: [
            if (ownLocation != null)
              _marker(
                point: LatLng(ownLocation.latitude, ownLocation.longitude),

                name: 'Vos',

                color: colors[-1] ?? Colors.blue,
              ),

            for (final member in members)
              _marker(
                point: LatLng(member.latitude, member.longitude),

                name: member.name,

                color: colors[member.memberId] ?? Colors.blue,

                isStale: _isStale(member, now),

                lastSeenAt: member.lastSeenAt,

                now: now,
              ),
            if (widget.previewPoint != null)
              _eventLocationMarker(widget.previewPoint!),
          ],
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

  Marker _marker({
    required LatLng point,
    required String name,
    required Color color,
    bool isStale = false,
    DateTime? lastSeenAt,
    DateTime? now,
  }) {
    final markerColor = isStale ? color.withAlpha(110) : color;

    return Marker(
      point: point,

      width: 150,

      height: isStale ? 84 : 66,

      child: Column(
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

  Marker _eventLocationMarker(LatLng point) {
    return Marker(
      point: point,
      width: 150,
      height: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_pin,
            size: 42,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}
