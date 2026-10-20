import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Temporary, opt-in diagnostic channel. Coordinates are sensitive test data.
class BondMapDiagnostics {
  /// Synchronous output sink; replace only in diagnostic tests.
  static DebugPrintCallback output = debugPrintSynchronously;

  /// Compile-time opt-in; false for normal builds.
  static const enabled = bool.fromEnvironment('BOND_MAP_DIAGNOSTICS');
  static final Queue<String> _history = Queue<String>();
  static final Map<String, int> _lastSamples = <String, int>{};
  static int _dumps = 0;
  static int _lines = 0;
  static final Map<String, int> _lastDump = <String, int>{};
  static final Stopwatch _clock = Stopwatch();

  /// Number of retained samples, capped at 24.
  static int get historyLength => _history.length;

  /// Process-wide number of anomaly dumps, capped at six.
  static int get dumpCount => _dumps;

  /// Throttle a fixed diagnostic channel using monotonic time.
  static bool due(String channel, int milliseconds) {
    if (!enabled) return false;
    if (!_clock.isRunning) _clock.start();
    final now = _clock.elapsedMilliseconds;
    final previous = _lastSamples[channel];
    if (previous != null && now - previous < milliseconds) return false;
    _lastSamples[channel] = now;
    return true;
  }

  /// Forget a disposed owner's throttle state.
  static void release(String channel) => _lastSamples.remove(channel);

  /// Append a bounded numeric sample, never backend payloads or URLs.
  static void record(String message) {
    if (!enabled) return;
    if (_history.length == 24) _history.removeFirst();
    _history.add('${DateTime.now().toUtc().toIso8601String()} $message');
  }

  /// Emit at most 2400 diagnostic lines per process.
  static void emit(String message) {
    if (!enabled || _lines >= 2400) return;
    _lines++;
    // Synchronous, bounded lines: don't enqueue unbounded debugPrint output.
    output('[BOND_DIAG sensitive_coordinates] '
        '${DateTime.now().toUtc().toIso8601String()} $message');
  }

  /// At most six dumps; each fixed stage is throttled to ten seconds.
  /// Separate stages preserve tile operands after a camera anomaly.
  static void anomaly(String message) {
    if (!enabled || _dumps >= 6) return;
    if (!_clock.isRunning) _clock.start();
    final now = _clock.elapsedMilliseconds;
    final stage = message.split(' ').first;
    final previous = _lastDump[stage];
    if (previous != null && now - previous < 10000) return;
    _lastDump[stage] = now;
    _dumps++;
    emit('ANOMALY dump=$_dumps $message');
    for (final sample in _history) {
      emit('HISTORY $sample');
    }
  }
}
