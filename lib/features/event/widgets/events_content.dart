import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../group/providers/group_provider.dart';
import '../formatters/event_date_formatter.dart';
import '../models/event_model.response.dart';
import '../providers/event_provider.dart';
import 'event_details_modal.dart';

class EventsContent extends StatefulWidget {
  const EventsContent({super.key});

  @override
  State<EventsContent> createState() => _EventsContentState();
}

class _EventsContentState extends State<EventsContent> {
  static const int _maxVisibleEvents = 5;
  static const double _dividerHeight = 1;

  late final EventProvider _eventProvider;
  late final GroupProvider _groupProvider;

  int? _loadedGroupId;

  final GlobalKey _measureKey = GlobalKey();

  double? _rowHeight;

  @override
  void initState() {
    super.initState();

    _eventProvider = context.read<EventProvider>();
    _groupProvider = context.read<GroupProvider>();
    _groupProvider.addListener(_onGroupChanged);

    _syncActiveGroup();
  }

  void _measureRowHeight() {
    if (!mounted) {
      return;
    }

    final renderBox =
        _measureKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return;
    }

    final measured = renderBox.size.height;

    if (_rowHeight != null && (_rowHeight! - measured).abs() < 0.5) {
      return;
    }

    setState(() => _rowHeight = measured);
  }

  void _onGroupChanged() {
    if (!mounted) {
      return;
    }

    _syncActiveGroup();
  }

  void _syncActiveGroup() {
    final groupId = _groupProvider.activeGroup?.id;

    if (groupId == _loadedGroupId) {
      return;
    }

    _loadedGroupId = groupId;

    if (groupId == null) {
      _eventProvider.clearEvents();
      return;
    }

    _eventProvider.loadEvents(groupId: groupId);
  }

  void _retry() {
    final groupId = _groupProvider.activeGroup?.id;

    if (groupId != null) {
      _eventProvider.loadEvents(groupId: groupId);
    }
  }

  Future<void> _refreshEvents() async {
    final groupId = _groupProvider.activeGroup?.id;

    if (groupId != null && !_eventProvider.isEventsLoading) {
      await _eventProvider.loadEvents(groupId: groupId);
    }
  }

  Widget _buildRefreshable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _refreshEvents,
          color: AppColors.primary,
          backgroundColor: AppColors.cardColor,
          notificationPredicate: (notification) => notification.depth <= 1,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _groupProvider.removeListener(_onGroupChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final eventProvider = context.watch<EventProvider>();

    if (groupProvider.activeGroup == null) {
      return _buildRefreshable(const Center(child: _NoGroupState()));
    }

    if (eventProvider.isEventsLoading) {
      return _buildRefreshable(const Center(child: _LoadingState()));
    }

    if (eventProvider.errorMessage != null) {
      return _buildRefreshable(
        Center(
          child: _ErrorState(
            message: eventProvider.errorMessage!,
            onRetry: _retry,
          ),
        ),
      );
    }

    final todayEvents = eventProvider.todayEvents;

    if (todayEvents.isEmpty) {
      return _buildRefreshable(const Center(child: _EmptyState()));
    }

    final rowHeight = _rowHeight;
    final shouldCap = todayEvents.length > _maxVisibleEvents;

    if (rowHeight == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureRowHeight());
    }

    final double? maxContainerHeight = (shouldCap && rowHeight != null)
        ? rowHeight * _maxVisibleEvents +
              (_maxVisibleEvents - 1) * _dividerHeight
        : null;

    return _buildRefreshable(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _TodayHeader(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              constraints: maxContainerHeight != null
                  ? BoxConstraints(maxHeight: maxContainerHeight)
                  : null,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < todayEvents.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Divider(height: 1, color: AppColors.divider),
                      ),
                    _EventCard(
                      event: todayEvents[i],
                      onTap: () {
                        final groupId = groupProvider.activeGroup!.id;

                        showEventDetailsModal(context, todayEvents[i], groupId);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (rowHeight == null)
            Offstage(
              offstage: true,
              child: _EventCard(
                key: _measureKey,
                event: todayEvents.first,
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hoy · ${EventDateFormatter.todayDayMonth()}',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventResponseModel event;
  final VoidCallback onTap;

  const _EventCard({super.key, required this.event, required this.onTap});

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
                  color: AppColors.fieldColor,
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
                        fontSize: 17,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 16),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.event_rounded,
      title: 'No hay eventos para hoy',
      subtitle: 'Los eventos programados para hoy\nvan a aparecer acá.',
    );
  }
}

class _NoGroupState extends StatelessWidget {
  const _NoGroupState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.groups_outlined,
      title: 'Sin grupo activo',
      subtitle:
          'Elegí un grupo con el selector\nde arriba para ver sus eventos.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 48,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: AppColors.fieldColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
