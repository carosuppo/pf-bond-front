import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_navigator.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/routes/navigation/pending_navigation.dart';
import '../../group/providers/group_provider.dart';
import '../services/event_service.dart';
import '../widgets/event_details_modal.dart';

Future<void> handleEventReminderTap({
  required int groupId,
  required int eventId,
}) async {
  if (!isAppReady) {
    stashPendingEventReminder(groupId: groupId, eventId: eventId);
    return;
  }

  await openEventFromReminder(groupId: groupId, eventId: eventId);
}

Future<void> openPendingEventReminder() async {
  final pending = takePendingEventReminder();
  if (pending == null) return;

  await openEventFromReminder(
    groupId: pending.groupId,
    eventId: pending.eventId,
  );
}

Future<void> openEventFromReminder({
  required int groupId,
  required int eventId,
}) async {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;

  try {
    var context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final groupProvider = context.read<GroupProvider>();
    await groupProvider.initialize();

    context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final groups = context.read<GroupProvider>().groups;
    for (final group in groups) {
      if (group.id == groupId) {
        await context.read<GroupProvider>().selectGroup(group);
        break;
      }
    }

    context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final event = await context.read<EventService>().getEventById(
      groupId: groupId,
      eventId: eventId,
    );

    navigator.pushNamed(AppRoutes.events);

    final modalContext = appNavigatorKey.currentContext;
    if (modalContext == null || !modalContext.mounted) return;
    await showEventDetailsModal(modalContext, event, groupId);
  } catch (_) {
    final errorContext = appNavigatorKey.currentContext;
    if (errorContext == null || !errorContext.mounted) return;
    ScaffoldMessenger.of(errorContext).showSnackBar(
      const SnackBar(content: Text('El evento ya no está disponible.')),
    );
  }
}
