import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../group/models/get_member_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../formatters/event_date_formatter.dart';
import '../models/event_model.response.dart';

Future<void> showEventDetailsModal(
  BuildContext context,
  EventResponseModel event,
) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => EventDetailsModal(event: event),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class EventDetailsModal extends StatelessWidget {
  final EventResponseModel event;

  const EventDetailsModal({super.key, required this.event});

  List<String> _memberNames(BuildContext context) {
    final members =
        context.watch<GroupProvider>().groupDetails?.members ??
        const <GetMemberResponseModel>[];

    final nameById = {for (final member in members) member.id: member.name};

    return event.memberIds
        .map((memberId) => nameById[memberId] ?? 'Miembro #$memberId')
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final memberNames = _memberNames(context);
    final hasEnd = event.endAt != null;
    final sameDay =
        hasEnd &&
        EventDateFormatter.isSameLocalDay(event.startAt, event.endAt!);

    return Dialog(
      backgroundColor: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.mutedText,
                    size: 26,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _InfoRow(
              icon: Icons.event_rounded,
              text: EventDateFormatter.dayMonthYear(event.startAt),
            ),

            const SizedBox(height: 10),

            _InfoRow(
              icon: Icons.schedule_rounded,
              text: 'Inicio: ${EventDateFormatter.time(event.startAt)}',
            ),

            if (hasEnd) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.schedule_rounded,
                text: sameDay
                    ? 'Finaliza: ${EventDateFormatter.time(event.endAt!)}'
                    : 'Finaliza: ${EventDateFormatter.dayMonth(event.endAt!)} '
                          '${EventDateFormatter.time(event.endAt!)}',
              ),
            ],

            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionTitle('Descripción'),
              const SizedBox(height: 8),
              Text(
                event.description!,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],

            if (memberNames.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionTitle('Miembros'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in memberNames) _MemberChip(name: name),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String name;

  const _MemberChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
