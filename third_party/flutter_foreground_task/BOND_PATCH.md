# Bond patch: flutter_foreground_task 11.0.2

Source: installed local Pub cache, version 11.0.2. No download or Git operation.
Original MIT license retained in LICENSE. Dart API and dependencies unchanged.
Copied lib, Android and iOS source plus package metadata; examples omitted.

Only behavioral patch: android/src/main/kotlin/com/pravera/flutter_foreground_task/service/RestartReceiver.kt
uses AlarmManager.set(RTC_WAKEUP, ...) for all restart alarms, never setAlarmClock.
Android may allow exact alarms to battery-exempt apps even without declaring
SCHEDULE_EXACT_ALARM. Therefore simply omitting that permission is insufficient.
Both onDestroy and onTaskRemoved use this receiver. Inexact alarms remain subject
to Doze and platform restrictions. START_STICKY and BOOT_COMPLETED are unchanged.

Do not edit the global Pub cache. When upgrading this dependency, re-check both
restart paths, retain this policy, and run the Bond restart-alarm regression test.
