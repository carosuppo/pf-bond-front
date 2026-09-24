import '../../../core/timezone/app_timezone.dart';

class EventDateFormatter {
  EventDateFormatter._();

  static const List<String> _daysShort = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

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

  static const List<String> _daysFull = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const List<String> _monthsFull = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static DateTime _toLocal(DateTime value) => AppTimezone.fromUtc(value);

  static String time(DateTime value) {
    final local = _toLocal(value);
    return '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  static String dayMonth(DateTime value) {
    final local = _toLocal(value);
    return '${_daysShort[local.weekday - 1]} ${local.day} '
        '${_monthsShort[local.month - 1]}';
  }

  static String todayDayMonth() => dayMonth(AppTimezone.now());

  static String dayMonthYear(DateTime value) {
    final local = _toLocal(value);
    return '${local.day} ${_monthsShort[local.month - 1]} ${local.year}';
  }

  static String fullDayDateTime(DateTime value) {
    final local = _toLocal(value);
    final day = _daysFull[local.weekday - 1];
    final capitalizedDay = '${day[0].toUpperCase()}${day.substring(1)}';
    return '$capitalizedDay ${local.day} de '
        '${_monthsFull[local.month - 1]}, ${time(value)}';
  }

  static String weekdayTime(DateTime value) {
    final local = _toLocal(value);
    return '${_daysFull[local.weekday - 1]} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  static String dayOfMonth(DateTime value) {
    return _pad(_toLocal(value).day);
  }

  static String month(DateTime value) {
    return _monthsShort[_toLocal(value).month - 1];
  }

  static bool isSameLocalDay(DateTime a, DateTime b) {
    final localA = _toLocal(a);
    final localB = _toLocal(b);
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }
}
