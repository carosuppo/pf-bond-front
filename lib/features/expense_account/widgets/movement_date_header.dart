import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/timezone/app_timezone.dart';
import '../../event/formatters/event_date_formatter.dart';

class MovementDateHeader extends StatelessWidget {
  const MovementDateHeader({super.key, required this.date});

  final DateTime date;

  String get _label {
    final now = AppTimezone.now();
    if (EventDateFormatter.isSameLocalDay(date, now)) return 'Hoy';
    if (EventDateFormatter.isSameLocalDay(
      date,
      now.subtract(const Duration(days: 1)),
    )) {
      return 'Ayer';
    }

    return '${EventDateFormatter.dayOfMonth(date)} '
        '${EventDateFormatter.month(date)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        _label,
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
