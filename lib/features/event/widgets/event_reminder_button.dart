import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../models/event_model.response.dart';
import '../providers/event_reminder_provider.dart';
import '../services/event_reminder_service.dart';
import '../utils/event_reminder_options.dart';
import 'event_reminder_sheet.dart';

class EventReminderButton extends StatefulWidget {
  final EventResponseModel event;
  final int groupId;

  const EventReminderButton({
    super.key,
    required this.event,
    required this.groupId,
  });

  @override
  State<EventReminderButton> createState() => _EventReminderButtonState();
}

class _EventReminderButtonState extends State<EventReminderButton> {
  late final EventReminderProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = EventReminderProvider(context.read<EventReminderService>());
    _provider.load(groupId: widget.groupId, eventId: widget.event.id);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: _provider,
        child: EventReminderSheet(
          groupId: widget.groupId,
          eventId: widget.event.id,
          eventName: widget.event.name,
          eventStartAt: widget.event.startAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<EventReminderProvider>(
        builder: (context, provider, _) {
          final label = _label(provider);

          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: provider.isLoading ? null : _openSheet,
              icon: provider.isLoading
                  ? const AppLoadingIndicator(size: 18)
                  : Icon(
                      provider.hasReminders
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                    ),
              label: Text(label),
            ),
          );
        },
      ),
    );
  }

  String _label(EventReminderProvider provider) {
    if (provider.isLoading) return 'Cargando recordatorio...';
    if (provider.reminders.isEmpty) return 'Agregar recordatorio';
    if (provider.reminders.length == 1) {
      return 'Recordatorio: '
          '${EventReminderOptions.formatLeadMinutes(provider.reminders.first.leadMinutes)}';
    }
    return '${provider.reminders.length} recordatorios';
  }
}
