import 'package:flutter/material.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/event/utils/event_reminder_navigation.dart';
import '../../../features/group/providers/group_provider.dart';
import '../../../features/group/services/group_invitation_coordinator.dart';
import '../../../features/location/providers/location_provider.dart';
import '../app_navigation.dart';
import '../app_routes.dart';
import 'pending_navigation.dart';

class PostAuthNavigator {
  const PostAuthNavigator();

  Future<void> navigate({
    required BuildContext context,
    required GroupProvider groupProvider,
    required LocationProvider locationNotifier,
    GroupInvitationCoordinator? invitationCoordinator,
    AuthProvider? authProvider,
    NavigatorState? navigator,
  }) async {
    final navigation = navigator ?? Navigator.of(context);
    String? deferredMessage;

    if (invitationCoordinator != null) {
      final invitationResult = await invitationCoordinator
          .processPendingInvitation(groupProvider);

      if (!context.mounted) return;

      if (invitationResult.status ==
          GroupInvitationProcessingStatus.authenticationRequired) {
        await authProvider?.invalidateExpiredSession();
        if (!context.mounted) return;
        navigation.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
        _showMessage(invitationResult.message);
        return;
      }

      if (invitationResult.openedGroup) {
        await locationNotifier.restoreSharingAndTracking();
        if (!context.mounted) return;
        navigation.pushNamedAndRemoveUntil(AppRoutes.map, (_) => false);
        _showMessage(invitationResult.message);
        return;
      }

      if (invitationResult.status !=
          GroupInvitationProcessingStatus.noPendingInvitation) {
        deferredMessage = invitationResult.message;
      }
    }

    await groupProvider.initialize();

    if (!context.mounted) return;

    if (groupProvider.errorMessage != null || groupProvider.groups.isEmpty) {
      navigation.pushReplacementNamed(AppRoutes.groups);
      markAppReady();
      await openPendingEventReminder();
      _showMessage(deferredMessage);
      return;
    }

    await locationNotifier.restoreSharingAndTracking();

    if (!context.mounted) return;

    navigation.pushReplacementNamed(AppRoutes.map);
    markAppReady();
    await openPendingEventReminder();
    _showMessage(deferredMessage);
  }

  void _showMessage(String? message) {
    if (message == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigation.showMessage(message);
    });
  }
}
