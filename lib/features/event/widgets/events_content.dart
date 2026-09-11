import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../group/providers/group_provider.dart';
import '../models/create_event_model.response.dart';
import '../providers/event_provider.dart';

class EventsContent extends StatefulWidget {
  const EventsContent({super.key});

  @override
  State<EventsContent> createState() => _EventsContentState();
}

class _EventsContentState extends State<EventsContent> {
  int? _requestedGroupId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final groupId = context.watch<GroupProvider>().activeGroup?.id;

    if (_requestedGroupId == groupId) {
      return;
    }

    _requestedGroupId = groupId;
    final eventProvider = context.read<EventProvider>();

    if (groupId == null) {
      eventProvider.clearEvents();
    } else {
      eventProvider.loadEvents(groupId: groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();

    if (eventProvider.isEventsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (eventProvider.errorMessage != null) {
      return _MessageContent(
        icon: Icons.error_outline_rounded,
        title: 'No se pudieron cargar los eventos',
        subtitle: eventProvider.errorMessage!,
        action: TextButton(onPressed: _retry, child: const Text('Reintentar')),
      );
    }

    if (eventProvider.events.isEmpty) {
      return const _MessageContent(
        icon: Icons.event_rounded,
        title: 'Todavía no hay eventos',
        subtitle: 'Usá el botón + para crear el primer\nevento de este grupo.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: eventProvider.events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _EventCard(event: eventProvider.events[index]),
    );
  }

  void _retry() {
    final groupId = context.read<GroupProvider>().activeGroup?.id;

    if (groupId != null) {
      context.read<EventProvider>().loadEvents(groupId: groupId);
    }
  }
}

class _MessageContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _MessageContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 500;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 88 : 112,
                      height: compact ? 88 : 112,
                      decoration: const BoxDecoration(
                        color: AppColors.fieldColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: compact ? 44 : 56,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 28),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (action != null) ...[const SizedBox(height: 8), action!],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final CreateEventResponseModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.name,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.description!,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDateTime(event.startAt),
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                ),
              ),
            ],
          ),
          if (event.endAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 26),
                Expanded(
                  child: Text(
                    'Hasta ${_formatDateTime(event.endAt!)}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }
}
