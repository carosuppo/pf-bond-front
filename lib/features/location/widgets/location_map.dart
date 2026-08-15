import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:latlong2/latlong.dart';

import '../constants/default_location.dart';
import '../constants/location_tracking_config.dart';

import '../models/member_location_model.dart';

import '../providers/location_provider.dart';

import '../utils/marker_colors.dart';

class LocationMap
    extends ConsumerStatefulWidget {
  final int groupId;

  const LocationMap({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<LocationMap>
  createState() =>
      _LocationMapState();
}

class _LocationMapState
    extends ConsumerState<LocationMap> {
  final MapController
      _mapController =
      MapController();

  bool _hasCenteredOnUser =
      false;

  Timer? _freshnessTimer;

  @override
  void initState() {
    super.initState();

    _freshnessTimer =
        Timer.periodic(
      LocationTrackingConfig
          .freshnessRefreshInterval,

      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _freshnessTimer
        ?.cancel();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final state =
        ref.watch(
      locationProvider,
    );

    final now =
        DateTime.now();

    final ownSharing =
        state
                .sharingForGroup(
                  widget.groupId,
                )
                ?.effectiveLocationSharing ??
            false;

    final ownLocation =
        ownSharing
            ? state.currentLocation
            : null;

    final allMembers =
        state.visibleMembers
            .values
            .toList();

    final members =
        allMembers
            .where(
              (member) =>
                  _shouldShowMember(
                member,
                now,
              ),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.memberId
                    .compareTo(
              b.memberId,
            ),
          );

    // Usamos todos los IDs conocidos para
    // evitar cambiar colores solamente
    // porque uno quedó temporalmente oculto.
    final markerIds =
        <int>[
      if (ownLocation != null)
        -1,

      ...allMembers.map(
        (member) =>
            member.memberId,
      ),
    ];

    final colors =
        buildDistinctMarkerColors(
      markerIds,
    );

    if (
        !_hasCenteredOnUser &&
        ownLocation != null) {
      WidgetsBinding
          .instance
          .addPostFrameCallback(
        (_) {
          if (
              !mounted ||
              _hasCenteredOnUser) {
            return;
          }

          _mapController.move(
            LatLng(
              ownLocation.latitude,
              ownLocation.longitude,
            ),
            defaultZoom,
          );

          _hasCenteredOnUser =
              true;
        },
      );
    }

    return FlutterMap(
      mapController:
          _mapController,

      options:
          MapOptions(
        initialCenter:
            ownLocation == null
                ? defaultLocation
                : LatLng(
                    ownLocation.latitude,
                    ownLocation.longitude,
                  ),

        initialZoom:
            defaultZoom,
      ),

      children: [
        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

          userAgentPackageName:
              'com.example.bond_front',
        ),

        MarkerLayer(
          markers: [
            if (ownLocation != null)
              _marker(
                point:
                    LatLng(
                  ownLocation.latitude,
                  ownLocation.longitude,
                ),

                name:
                    'Vos',

                color:
                    colors[-1] ??
                    Colors.blue,
              ),

            for (
              final member
              in members
            )
              _marker(
                point:
                    LatLng(
                  member.latitude,
                  member.longitude,
                ),

                name:
                    member.name,

                color:
                    colors[
                          member.memberId
                        ] ??
                        Colors.blue,

                isStale:
                    _isStale(
                  member,
                  now,
                ),

                lastSeenAt:
                    member.lastSeenAt,

                now:
                    now,
              ),
          ],
        ),
      ],
    );
  }

  bool _shouldShowMember(
    MemberLocationModel member,
    DateTime now,
  ) {
    final lastSeenAt =
        member.lastSeenAt;

    // Una Location anterior a esta feature
    // no tiene heartbeat válido.
    if (lastSeenAt == null) {
      return false;
    }

    return _age(
          lastSeenAt,
          now,
        ) <
        LocationTrackingConfig
            .hideAfter;
  }

  bool _isStale(
    MemberLocationModel member,
    DateTime now,
  ) {
    final lastSeenAt =
        member.lastSeenAt;

    if (lastSeenAt == null) {
      return true;
    }

    return _age(
          lastSeenAt,
          now,
        ) >=
        LocationTrackingConfig
            .staleAfter;
  }

  Duration _age(
    DateTime lastSeenAt,
    DateTime now,
  ) {
    final difference =
        now.difference(
      lastSeenAt,
    );

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
    final markerColor =
        isStale
            ? color.withAlpha(110)
            : color;

    return Marker(
      point:
          point,

      width:
          150,

      height:
          isStale
              ? 84
              : 66,

      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            Icons.location_pin,

            size:
                42,

            color:
                markerColor,
          ),

          Text(
            name,

            maxLines:
                1,

            overflow:
                TextOverflow.ellipsis,

            textAlign:
                TextAlign.center,

            style:
                TextStyle(
              color:
                  isStale
                      ? Colors.black54
                      : Colors.black87,

              fontSize:
                  13,

              fontWeight:
                  FontWeight.w600,
            ),
          ),

          if (
              isStale &&
              lastSeenAt != null &&
              now != null)
            Text(
              _formatLastSeen(
                lastSeenAt,
                now,
              ),

              maxLines:
                  1,

              overflow:
                  TextOverflow.ellipsis,

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color:
                    Colors.black54,

                fontSize:
                    10,

                fontWeight:
                    FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  String _formatLastSeen(
    DateTime lastSeenAt,
    DateTime now,
  ) {
    final age =
        _age(
      lastSeenAt,
      now,
    );

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
