import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../constants/default_location.dart';
import '../providers/location_provider.dart';
import '../utils/marker_colors.dart';

class LocationMap extends ConsumerStatefulWidget {
  final int groupId;

  const LocationMap({super.key, required this.groupId});

  @override
  ConsumerState<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends ConsumerState<LocationMap> {
  final MapController _mapController = MapController();
  bool _hasCenteredOnUser = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(locationProvider);
    final ownSharing =
        state.sharingForGroup(widget.groupId)?.effectiveLocationSharing ??
        false;
    final ownLocation = ownSharing ? state.currentLocation : null;
    final members = state.visibleMembers.values.toList()
      ..sort((a, b) => a.memberId.compareTo(b.memberId));
    final markerIds = <int>[
      if (ownLocation != null) -1,
      ...members.map((member) => member.memberId),
    ];
    final colors = buildDistinctMarkerColors(markerIds);

    if (!_hasCenteredOnUser && ownLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasCenteredOnUser) return;
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
                color: colors[-1]!,
              ),
            for (final member in members)
              _marker(
                point: LatLng(member.latitude, member.longitude),
                name: member.name,
                color: colors[member.memberId]!,
              ),
          ],
        ),
      ],
    );
  }

  Marker _marker({
    required LatLng point,
    required String name,
    required Color color,
  }) {
    return Marker(
      point: point,
      width: 110,
      height: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_pin, size: 42, color: color),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            color: Colors.black87,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
