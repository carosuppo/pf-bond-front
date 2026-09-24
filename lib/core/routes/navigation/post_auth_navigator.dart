import 'package:flutter/material.dart';

import '../../../features/event/utils/event_reminder_navigation.dart';
import '../../../features/group/providers/group_provider.dart';
import '../../../features/location/providers/location_provider.dart';
import '../app_routes.dart';
import 'pending_navigation.dart';

class PostAuthNavigator {
  const PostAuthNavigator();

  Future<void> navigate({
    required BuildContext context,
    required GroupProvider groupProvider,
    required LocationProvider locationNotifier,
  }) async {
    await groupProvider.initialize();

    if (!context.mounted) return;

    if (groupProvider.errorMessage != null || groupProvider.groups.isEmpty) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.groups);
      markAppReady();
      await openPendingEventReminder();
      return;
    }

    await locationNotifier.restoreSharingAndTracking();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacementNamed(AppRoutes.map);
    markAppReady();
    await openPendingEventReminder();
  }
}
