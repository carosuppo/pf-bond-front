import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolved foreground plugin uses only inexact restart alarms', () {
    final config =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final packages = (config['packages'] as List<Object?>)
        .cast<Map<String, dynamic>>();
    final plugin = packages.singleWhere(
      (item) => item['name'] == 'flutter_foreground_task',
    );
    expect(plugin['rootUri'], contains('third_party/flutter_foreground_task'));
    final source = File(
      'third_party/flutter_foreground_task/android/src/main/kotlin/com/pravera/flutter_foreground_task/service/RestartReceiver.kt',
    ).readAsStringSync();
    expect(
      source,
      contains(
        'alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, operation)',
      ),
    );
    expect(
      RegExp(
        r'\.\s*set(?:AlarmClock|Exact|ExactAndAllowWhileIdle|AndAllowWhileIdle)\s*\(',
      ).hasMatch(source),
      isFalse,
    );
  });
}
