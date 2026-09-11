import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class AppTimezone {
  static const String name = 'America/Argentina/Buenos_Aires';

  static late final tz.Location location;

  static void initialize() {
    tz_data.initializeTimeZones();
    location = tz.getLocation(name);
  }

  static tz.TZDateTime now() {
    return tz.TZDateTime.now(location);
  }

  static tz.TZDateTime fromUtc(DateTime dateTime) {
    final utcDateTime = dateTime.toUtc();

    return tz.TZDateTime.from(utcDateTime, location);
  }

  static DateTime toUtc(DateTime dateTime) {
    return dateTime.toUtc();
  }

  static DateTime argentinaToUtc(DateTime dateTime) {
    final argentinaDateTime = tz.TZDateTime(
      location,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
      dateTime.millisecond,
      dateTime.microsecond,
    );

    return argentinaDateTime.toUtc();
  }
}
