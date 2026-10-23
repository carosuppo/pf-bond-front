import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/timezone/app_timezone.dart';
import '../../group/providers/group_provider.dart';
import '../formatters/event_date_formatter.dart';
import '../models/event_model.response.dart';
import '../providers/event_provider.dart';
import 'event_details_modal.dart';
import 'event_month_calendar.dart';

class EventCalendar extends StatefulWidget {
  const EventCalendar({super.key});

  @override
  State<EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  late DateTime _displayedMonth;
  DateTime? _selectedDay;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    final now = AppTimezone.now();
    _displayedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _ensureMonthLoaded();
  }

  void _ensureMonthLoaded() {
    final groupId = context.read<GroupProvider>().activeGroup?.id;
    if (groupId == null) return;

    context.read<EventProvider>().ensureMonthLoaded(
      groupId: groupId,
      year: _displayedMonth.year,
      month: _displayedMonth.month,
    );
  }

  void _onMonthChanged(DateTime month) {
    setState(() {
      _displayedMonth = DateTime(month.year, month.month);
    });
    _ensureMonthLoaded();
  }

  void _selectDay(DateTime day) {
    setState(() => _selectedDay = day);
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final groupId = context.watch<GroupProvider>().activeGroup?.id;

    final selectedEvents = _selectedDay == null || groupId == null
        ? const <EventResponseModel>[]
        : eventProvider.eventsForDay(_selectedDay!);

    final now = AppTimezone.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
            'Calendario',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            children: [
              EventMonthCalendar(
                displayedMonth: _displayedMonth,
                selectedDay: _selectedDay,
                onMonthChanged: _onMonthChanged,
                onDaySelected: _selectDay,
                today: now,
                dayHasEvents: (day) =>
                    eventProvider.eventsForDay(day).isNotEmpty,
                dayIsMultiDay: (day) => eventProvider
                    .eventsForDay(day)
                    .any(eventProvider.isMultiDayEvent),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(),
                  SizedBox(width: 6),
                  Text(
                    'Tiene eventos',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                  SizedBox(width: 16),
                  _LegendMultiDay(),
                  SizedBox(width: 6),
                  Text(
                    'Varios días',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: _SelectedDayEvents(
            selectedDay: _selectedDay,
            events: selectedEvents,
            groupId: groupId,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(28),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _LegendMultiDay extends StatelessWidget {
  const _LegendMultiDay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(28),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SelectedDayEvents extends StatelessWidget {
  static const List<String> _shortMonths = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static String _monthsShort(int month) => _shortMonths[month - 1];

  final DateTime? selectedDay;
  final List<EventResponseModel> events;
  final int? groupId;

  const _SelectedDayEvents({
    required this.selectedDay,
    required this.events,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return const SizedBox.shrink();
    }

    final title =
        '${selectedDay!.day} ${_monthsShort(selectedDay!.month)} ${selectedDay!.year} · ${events.length} evento${events.length == 1 ? '' : 's'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: const Text(
              'No hay eventos para este día.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < events.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                  _SelectedEventRow(
                    event: events[i],
                    onTap: groupId == null
                        ? null
                        : () => showEventDetailsModal(
                            context,
                            events[i],
                            groupId!,
                          ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SelectedEventRow extends StatelessWidget {
  final EventResponseModel event;
  final VoidCallback? onTap;

  const _SelectedEventRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasEnd = event.endAt != null;
    final sameDay =
        hasEnd &&
        EventDateFormatter.isSameLocalDay(event.startAt, event.endAt!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Inicia: ${EventDateFormatter.time(event.startAt)}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                    if (hasEnd) ...[
                      const SizedBox(height: 2),
                      Text(
                        sameDay
                            ? 'Finaliza: ${EventDateFormatter.time(event.endAt!)}'
                            : 'Finaliza: ${EventDateFormatter.dayMonth(event.endAt!)} · '
                                  '${EventDateFormatter.time(event.endAt!)}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
