import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class EventMonthCalendar extends StatelessWidget {
  const EventMonthCalendar({
    super.key,
    required this.displayedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
    this.firstDate,
    this.lastDate,
    this.dayHasEvents,
    this.dayIsMultiDay,
    this.today,
  });

  static const List<String> weekdaysShort = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  static const List<String> monthsFull = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static String monthLabel(DateTime month) {
    return '${monthsFull[month.month - 1]} ${month.year}';
  }

  final DateTime displayedMonth;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool Function(DateTime day)? dayHasEvents;
  final bool Function(DateTime day)? dayIsMultiDay;
  final DateTime? today;

  bool get _canGoPrev {
    if (firstDate == null) return true;
    final firstMonth = DateTime(firstDate!.year, firstDate!.month);
    final current = DateTime(displayedMonth.year, displayedMonth.month);
    return current.isAfter(firstMonth);
  }

  bool get _canGoNext {
    if (lastDate == null) return true;
    final lastMonth = DateTime(lastDate!.year, lastDate!.month);
    final current = DateTime(displayedMonth.year, displayedMonth.month);
    return current.isBefore(lastMonth);
  }

  bool _isMonthAllowed(DateTime month) {
    final current = DateTime(month.year, month.month);
    if (firstDate != null) {
      final firstMonth = DateTime(firstDate!.year, firstDate!.month);
      if (current.isBefore(firstMonth)) return false;
    }
    if (lastDate != null) {
      final lastMonth = DateTime(lastDate!.year, lastDate!.month);
      if (current.isAfter(lastMonth)) return false;
    }
    return true;
  }

  void _showMonthYearPicker(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MonthYearPickerDialog(
        initialMonth: displayedMonth,
        firstDate: firstDate,
        lastDate: lastDate,
        onSelected: (month) {
          if (_isMonthAllowed(month)) {
            onMonthChanged(DateTime(month.year, month.month));
          }
        },
      ),
    );
  }

  bool _isDisabled(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    if (firstDate != null) {
      final first = DateTime(firstDate!.year, firstDate!.month, firstDate!.day);
      if (dateOnly.isBefore(first)) return true;
    }
    if (lastDate != null) {
      final last = DateTime(lastDate!.year, lastDate!.month, lastDate!.day);
      if (dateOnly.isAfter(last)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    ).day;
    final firstWeekday = DateTime(
      displayedMonth.year,
      displayedMonth.month,
      1,
    ).weekday;
    const totalCells = 42;
    final leadingBlanks = firstWeekday - 1;

    final resolvedToday = today ?? DateTime.now();
    final todayOnly = DateTime(
      resolvedToday.year,
      resolvedToday.month,
      resolvedToday.day,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _canGoPrev
                    ? () => onMonthChanged(
                        DateTime(displayedMonth.year, displayedMonth.month - 1),
                      )
                    : null,
                tooltip: 'Mes anterior',
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: _canGoPrev
                      ? AppColors.text
                      : AppColors.mutedText.withValues(alpha: 0.4),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showMonthYearPicker(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthLabel(displayedMonth),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: AppColors.mutedText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _canGoNext
                    ? () => onMonthChanged(
                        DateTime(displayedMonth.year, displayedMonth.month + 1),
                      )
                    : null,
                tooltip: 'Mes siguiente',
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: _canGoNext
                      ? AppColors.text
                      : AppColors.mutedText.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final weekday in weekdaysShort)
                Expanded(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayNumber = index - leadingBlanks + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final day = DateTime(
                displayedMonth.year,
                displayedMonth.month,
                dayNumber,
              );
              final hasEvents = dayHasEvents?.call(day) ?? false;
              final hasMultiDay = dayIsMultiDay?.call(day) ?? false;
              final isSelected =
                  selectedDay != null &&
                  selectedDay!.year == day.year &&
                  selectedDay!.month == day.month &&
                  selectedDay!.day == day.day;
              final isToday =
                  todayOnly.year == day.year &&
                  todayOnly.month == day.month &&
                  todayOnly.day == day.day;
              final disabled = _isDisabled(day);

              return EventMonthDayCell(
                dayNumber: dayNumber,
                hasEvents: hasEvents,
                hasMultiDay: hasMultiDay,
                isSelected: isSelected,
                isToday: isToday,
                enabled: !disabled,
                onTap: () => onDaySelected(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class EventMonthDayCell extends StatelessWidget {
  final int dayNumber;
  final bool hasEvents;
  final bool hasMultiDay;
  final bool isSelected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  const EventMonthDayCell({
    super.key,
    required this.dayNumber,
    required this.hasEvents,
    required this.hasMultiDay,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = isSelected
        ? AppColors.primary
        : hasEvents
        ? AppColors.primary.withAlpha(28)
        : Colors.transparent;
    final border = isSelected
        ? null
        : isToday
        ? Border.all(color: AppColors.primary, width: 1.5)
        : hasEvents
        ? Border.all(color: AppColors.primary, width: 1.5)
        : null;
    final textColor = isSelected ? AppColors.onPrimary : AppColors.text;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: hasEvents || isToday || isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (hasMultiDay)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 14,
                      height: 3,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({
    required this.initialMonth,
    required this.onSelected,
    this.firstDate,
    this.lastDate,
  });

  final DateTime initialMonth;
  final ValueChanged<DateTime> onSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  static const List<String> _monthsShort = [
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

  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
  }

  int get _minYear {
    if (widget.firstDate != null) return widget.firstDate!.year;
    return widget.initialMonth.year - 20;
  }

  int get _maxYear {
    if (widget.lastDate != null) return widget.lastDate!.year;
    if (widget.firstDate != null) return widget.firstDate!.year + 20;
    return widget.initialMonth.year + 20;
  }

  bool _isMonthEnabled(int month) {
    final candidate = DateTime(_year, month);
    if (widget.firstDate != null) {
      final firstMonth = DateTime(
        widget.firstDate!.year,
        widget.firstDate!.month,
      );
      if (candidate.isBefore(firstMonth)) return false;
    }
    if (widget.lastDate != null) {
      final lastMonth = DateTime(widget.lastDate!.year, widget.lastDate!.month);
      if (candidate.isAfter(lastMonth)) return false;
    }
    return true;
  }

  void _changeYear(int offset) {
    final next = (_year + offset).clamp(_minYear, _maxYear);
    if (next != _year) {
      setState(() => _year = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoPrevYear = _year > _minYear;
    final canGoNextYear = _year < _maxYear;

    return Dialog(
      backgroundColor: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: canGoPrevYear ? () => _changeYear(-1) : null,
                  tooltip: 'Año anterior',
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: canGoPrevYear
                        ? AppColors.text
                        : AppColors.mutedText.withValues(alpha: 0.4),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canGoNextYear ? () => _changeYear(1) : null,
                  tooltip: 'Año siguiente',
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: canGoNextYear
                        ? AppColors.text
                        : AppColors.mutedText.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final enabled = _isMonthEnabled(month);
                final isCurrent =
                    widget.initialMonth.year == _year &&
                    widget.initialMonth.month == month;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: enabled
                        ? () {
                            widget.onSelected(DateTime(_year, month));
                            Navigator.of(context).pop();
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary
                            : AppColors.fieldColor,
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrent
                            ? null
                            : Border.all(
                                color: enabled
                                    ? AppColors.border
                                    : AppColors.surface,
                                width: 1,
                              ),
                      ),
                      child: Opacity(
                        opacity: enabled ? 1.0 : 0.35,
                        child: Center(
                          child: Text(
                            _monthsShort[index],
                            style: TextStyle(
                              color: isCurrent
                                  ? AppColors.onPrimary
                                  : enabled
                                  ? AppColors.text
                                  : AppColors.placeholder,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
