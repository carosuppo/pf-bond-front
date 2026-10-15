import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _resolvedPlugin() {
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = (config['packages'] as List<Object?>)
      .cast<Map<String, dynamic>>();
  final plugin = packages.singleWhere(
    (item) => item['name'] == 'flutter_foreground_task',
  );
  return Directory.fromUri(configFile.uri.resolve(plugin['rootUri'] as String));
}

void main() {
  test('foreground plugin is hosted and pinned; Gradle installs the patch', () {
    final spec = File('pubspec.yaml').readAsStringSync();
    expect(spec, contains('flutter_foreground_task: 11.0.2'));
    expect(_resolvedPlugin().path, isNot(contains('third_party')));
    expect(
      File('pubspec.lock').readAsStringSync(),
      matches(
        RegExp(
          r'flutter_foreground_task:[\s\S]*?source: hosted\s+version: "11\.0\.2"',
        ),
      ),
    );
    expect(
      File('android/settings.gradle.kts').readAsStringSync(),
      contains('apply(from = "gradle/foreground-task-inexact.gradle")'),
    );
  });

  test(
    'minimal patch applies once to hosted source and removes exact scheduling',
    () {
      final script = File(
        'android/gradle/foreground-task-inexact.gradle',
      ).readAsStringSync();
      String block(String name) => RegExp(
        "def $name = '''([\\s\\S]*?)'''",
      ).firstMatch(script)!.group(1)!.replaceAll(r'\t', '\t');
      final original = File(
        '${_resolvedPlugin().path}/android/src/main/kotlin/com/pravera/flutter_foreground_task/service/RestartReceiver.kt',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final before = block('before');
      final after = block('after');
      expect(before.allMatches(original).length, 1);
      final patched = original.replaceFirst(before, after);
      expect(
        patched,
        contains(
          'alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, operation)',
        ),
      );
      expect(
        RegExp(
          r'\.\s*set(?:AlarmClock|Exact|ExactAndAllowWhileIdle|AndAllowWhileIdle)\s*\(',
        ).hasMatch(patched),
        isFalse,
      );
      // The hosted input must remain untouched; Gradle only writes generated files.
      expect(original, contains('alarmManager.setAlarmClock(info, operation)'));
      expect(script, contains('unexpected'));
      expect(script, contains('SHA-256'));
      expect(script, contains('descriptor.projectDir = generated'));
    },
  );
}
