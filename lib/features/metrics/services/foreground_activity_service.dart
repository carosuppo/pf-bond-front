import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Sends only a foreground signal; no location, screen or action data.
class ForegroundActivityService with WidgetsBindingObserver {
  ForegroundActivityService(this._auth, this._api, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_sync);
    _sync();
  }

  static const interval = Duration(minutes: 5);
  final AuthProvider _auth;
  final ApiClient _api;
  final DateTime Function() _now;
  Timer? _timer;
  String? _sessionToken;
  DateTime? _lastAttempt;
  bool _inFlight = false;
  bool _disposed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (_disposed) return;
    final session = _auth.authResponse;
    final token = session?.sessionToken;
    if (token != _sessionToken) {
      _sessionToken = token;
      _lastAttempt = null;
    }
    if (session == null ||
        !session.expiresAt.isAfter(_now()) ||
        _auth.isLoading ||
        _auth.isDeletingAccount ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (_inFlight) return;
    final lastAttempt = _lastAttempt;
    final remaining = lastAttempt == null
        ? Duration.zero
        : interval - _now().difference(lastAttempt);
    if (remaining > Duration.zero) {
      _timer = Timer(remaining, _sync);
    } else {
      unawaited(_record());
    }
  }

  Future<void> _record() async {
    _inFlight = true;
    _lastAttempt = _now();
    try {
      await _api.authenticatedPostNoContent('/user/activity');
    } catch (_) {
      // Best effort. No UI, auth changes, personal logs or background retries.
    } finally {
      _inFlight = false;
      _sync();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _auth.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
  }
}
