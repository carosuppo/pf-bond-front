import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../constants/default_location.dart';
import '../providers/location_provider.dart';

class LocationMap extends ConsumerStatefulWidget {
  const LocationMap({super.key});

  @override
  ConsumerState<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends ConsumerState<LocationMap> {
  final MapController _mapController = MapController();

  bool _hasCenteredOnUser = false;

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    if (!_hasCenteredOnUser && locationState.currentLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasCenteredOnUser) {
          return;
        }

        _mapController.move(
          LatLng(
            locationState.currentLocation!.latitude,
            locationState.currentLocation!.longitude,
          ),
          defaultZoom,
        );

        _hasCenteredOnUser = true;
      });
    }

    final initialCenter = locationState.currentLocation != null
        ? LatLng(
            locationState.currentLocation!.latitude,
            locationState.currentLocation!.longitude,
          )
        : defaultLocation;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: defaultZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.bond_front',
        ),

        if (locationState.currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(
                  locationState.currentLocation!.latitude,
                  locationState.currentLocation!.longitude,
                ),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
