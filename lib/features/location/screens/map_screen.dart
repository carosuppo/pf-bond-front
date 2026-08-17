import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/location_provider.dart';
import '../widgets/join_group_button.dart';
import '../widgets/location_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(locationProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,

      body: SafeArea(
        child: Stack(
          children: [
            const LocationMap(),

            const Positioned(top: 12, right: 12, child: JoinGroupButton()),
          ],
        ),
      ),
    );
  }
}
