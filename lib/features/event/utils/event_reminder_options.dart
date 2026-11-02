enum ReminderUnit {
  minute('Minutos', 1),
  hour('Horas', 60),
  day('Días', 1440),
  week('Semanas', 10080);

  const ReminderUnit(this.label, this.minutes);

  final String label;
  final int minutes;
}

class EventReminderOptions {
  const EventReminderOptions._();

  static const List<int> presets = [15, 30, 60, 1440, 10080];

  static const int minLeadMinutes = 1;
  static const int maxLeadMinutes = 40320;

  static String presetLabel(int leadMinutes) {
    return switch (leadMinutes) {
      15 => '15 minutos antes',
      30 => '30 minutos antes',
      60 => '1 hora antes',
      1440 => '1 día antes',
      10080 => '1 semana antes',
      _ => formatLeadMinutes(leadMinutes),
    };
  }

  static String formatLeadMinutes(int leadMinutes) {
    if (leadMinutes % 10080 == 0) {
      final value = leadMinutes ~/ 10080;
      return value == 1 ? '1 semana antes' : '$value semanas antes';
    }
    if (leadMinutes % 1440 == 0) {
      final value = leadMinutes ~/ 1440;
      return value == 1 ? '1 día antes' : '$value días antes';
    }
    if (leadMinutes % 60 == 0) {
      final value = leadMinutes ~/ 60;
      return value == 1 ? '1 hora antes' : '$value horas antes';
    }
    return leadMinutes == 1 ? '1 minuto antes' : '$leadMinutes minutos antes';
  }

  static int? customToLeadMinutes(String rawValue, ReminderUnit unit) {
    final value = int.tryParse(rawValue.trim());
    if (value == null || value < 1) return null;
    final total = value * unit.minutes;
    if (total < minLeadMinutes || total > maxLeadMinutes) return null;
    return total;
  }

  static ({int value, ReminderUnit unit}) decompose(int leadMinutes) {
    if (leadMinutes % 10080 == 0) {
      return (value: leadMinutes ~/ 10080, unit: ReminderUnit.week);
    }
    if (leadMinutes % 1440 == 0) {
      return (value: leadMinutes ~/ 1440, unit: ReminderUnit.day);
    }
    if (leadMinutes % 60 == 0) {
      return (value: leadMinutes ~/ 60, unit: ReminderUnit.hour);
    }
    return (value: leadMinutes, unit: ReminderUnit.minute);
  }
}
