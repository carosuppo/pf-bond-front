import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../group/models/get_member_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../../location/widgets/location_map.dart';
import '../formatters/event_date_formatter.dart';
import '../models/event_model.response.dart';
import '../models/geocoding_result.dart';
import '../providers/event_provider.dart';
import '../services/geocoding_service.dart';
import 'event_location_editor.dart';

Future<void> showEventDetailsModal(
  BuildContext context,
  EventResponseModel event,
  int groupId,
) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) =>
          EventDetailsModal(event: event, groupId: groupId),
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
  final int groupId;

  const EventDetailsModal({
    super.key,
    required this.event,
    required this.groupId,
  });

  List<String> _memberNames(
    BuildContext context,
    EventResponseModel currentEvent,
  ) {
    final members =
        context.watch<GroupProvider>().groupDetails?.members ??
        const <GetMemberResponseModel>[];

    final nameById = {for (final member in members) member.id: member.name};

    return currentEvent.memberIds
        .map((memberId) => nameById[memberId] ?? 'Miembro #$memberId')
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final currentEvent = _currentEvent(context);
    final memberNames = _memberNames(context, currentEvent);
    final hasEnd = currentEvent.endAt != null;
    final sameDay =
        hasEnd &&
        EventDateFormatter.isSameLocalDay(
          currentEvent.startAt,
          currentEvent.endAt!,
        );

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Dialog(
          backgroundColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                        currentEvent.name,
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
                  text: EventDateFormatter.dayMonthYear(currentEvent.startAt),
                ),

                const SizedBox(height: 10),

                _InfoRow(
                  icon: Icons.schedule_rounded,
                  text:
                      'Inicio: ${EventDateFormatter.time(currentEvent.startAt)}',
                ),

                if (hasEnd) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    text: sameDay
                        ? 'Finaliza: ${EventDateFormatter.time(currentEvent.endAt!)}'
                        : 'Finaliza: ${EventDateFormatter.dayMonth(currentEvent.endAt!)} '
                              '${EventDateFormatter.time(currentEvent.endAt!)}',
                  ),
                ],

                if (currentEvent.description != null &&
                    currentEvent.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Descripción'),
                  const SizedBox(height: 8),
                  Text(
                    currentEvent.description!,
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

                const SizedBox(height: 20),

                const _SectionTitle('Ubicación'),

                const SizedBox(height: 10),

                if (currentEvent.location == null)
                  const Text(
                    'Este evento no tiene una ubicaci\u00f3n asociada.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 14),
                  )
                else
                  _EventLocationDetails(
                    point: LatLng(
                      currentEvent.location!.latitude,
                      currentEvent.location!.longitude,
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final updatedEvent = await navigator
                          .push<EventResponseModel>(
                            MaterialPageRoute<EventResponseModel>(
                              builder: (_) => EventLocationEditor(
                                event: currentEvent,
                                groupId: groupId,
                              ),
                            ),
                          );

                      if (!messenger.mounted || updatedEvent == null) {
                        return;
                      }

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Ubicación del evento guardada.'),
                        ),
                      );
                    },
                    icon: Icon(
                      currentEvent.location == null
                          ? Icons.add_location_alt_rounded
                          : Icons.edit_location_alt_rounded,
                    ),
                    label: Text(
                      currentEvent.location == null
                          ? 'Agregar ubicación'
                          : 'Modificar ubicación',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  EventResponseModel _currentEvent(BuildContext context) {
    final events = context.watch<EventProvider>().events;

    for (final candidate in events) {
      if (candidate.id == event.id) {
        return candidate;
      }
    }

    return event;
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

class _EventLocationDetails extends StatefulWidget {
  final LatLng point;

  const _EventLocationDetails({required this.point});

  @override
  State<_EventLocationDetails> createState() => _EventLocationDetailsState();
}

class _EventLocationDetailsState extends State<_EventLocationDetails> {
  final _geocodingService = GeocodingService();
  late Future<GeocodingResult> _addressFuture;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void didUpdateWidget(covariant _EventLocationDetails oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.point != widget.point) {
      _loadAddress();
    }
  }

  void _loadAddress() {
    _addressFuture = _geocodingService.reverse(widget.point);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<GeocodingResult>(
          future: _addressFuture,
          builder: (context, snapshot) {
            final address = snapshot.hasData
                ? snapshot.data!.displayName
                : snapshot.hasError
                ? 'No se pudo obtener la dirección.'
                : 'Buscando dirección...';

            return Text(
              address,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.35,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Container(
          height: 180,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: LocationMap(
            groupId: null,
            showMembers: false,
            previewPoint: widget.point,
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
