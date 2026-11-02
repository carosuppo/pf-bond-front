import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../../features/group/utils/invitation_code.dart';
import '../config/app_link_config.dart';
import '../preferences/app_preferences_service.dart';

abstract interface class AppLinkSource {
  Future<Uri?> getInitialLink();

  Stream<Uri> get uriLinkStream;
}

class PlatformAppLinkSource implements AppLinkSource {
  PlatformAppLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

class AppLinkService {
  AppLinkService(this._preferences, {AppLinkSource? source})
    : _source = source ?? PlatformAppLinkSource();

  final AppPreferencesService _preferences;
  final AppLinkSource _source;
  final StreamController<String> _invitationController =
      StreamController<String>.broadcast();
  final StreamController<String> _emailVerificationController =
      StreamController<String>.broadcast();
  final Set<String> _receivedInvitationCodes = <String>{};
  final Set<String> _receivedEmailVerificationTokens = <String>{};
  final Set<String> _claimedEmailVerificationTokens = <String>{};

  StreamSubscription<Uri>? _subscription;
  Future<void> _pendingHandling = Future<void>.value();
  bool _initialized = false;

  Stream<String> get invitationCodes => _invitationController.stream;
  Stream<String> get emailVerificationTokens =>
      _emailVerificationController.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _subscription = _source.uriLinkStream.listen(
      _enqueue,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('No se pudo recibir un enlace de la aplicación: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    try {
      final initialLink = await _source.getInitialLink();
      if (initialLink != null) {
        _enqueue(initialLink);
        await _pendingHandling;
      }
    } catch (error, stackTrace) {
      debugPrint('No se pudo leer el enlace inicial: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _enqueue(Uri uri) {
    _pendingHandling = _pendingHandling
        .then((_) => processUri(uri))
        .then<void>((_) {})
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('No se pudo procesar el enlace de Bond: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Future<bool> processUri(Uri uri) async {
    final emailVerificationToken = parseEmailVerificationToken(uri);
    if (emailVerificationToken != null) {
      if (_receivedEmailVerificationTokens.contains(emailVerificationToken)) {
        return false;
      }

      await _preferences.savePendingEmailVerificationToken(
        emailVerificationToken,
      );
      if (!_receivedEmailVerificationTokens.add(emailVerificationToken)) {
        return false;
      }
      _emailVerificationController.add(emailVerificationToken);
      return true;
    }

    final invitationCode = parseInvitationCode(uri);
    if (invitationCode == null ||
        _receivedInvitationCodes.contains(invitationCode)) {
      return false;
    }

    await _preferences.savePendingInvitationCode(invitationCode);
    if (!_receivedInvitationCodes.add(invitationCode)) {
      return false;
    }
    _invitationController.add(invitationCode);
    return true;
  }

  static String? parseInvitationCode(Uri uri) {
    if (uri.scheme.toLowerCase() != AppLinkConfig.scheme ||
        uri.host.toLowerCase() != AppLinkConfig.host ||
        uri.pathSegments.length != 1) {
      return null;
    }

    final invitationCode = InvitationCode.normalize(uri.pathSegments.single);
    return InvitationCode.isValid(invitationCode) ? invitationCode : null;
  }

  static String? parseEmailVerificationToken(Uri uri) {
    if (uri.scheme.toLowerCase() != AppLinkConfig.scheme ||
        uri.host.toLowerCase() != AppLinkConfig.emailVerificationHost ||
        uri.path.isNotEmpty) {
      return null;
    }

    final token = uri.queryParameters['token'];
    if (token == null || !RegExp(r'^[A-Za-z0-9_-]{64}$').hasMatch(token)) {
      return null;
    }

    return token;
  }

  Future<String?> takePendingEmailVerificationToken() {
    return _takePendingEmailVerificationToken();
  }

  Future<bool> claimEmailVerificationToken(String token) async {
    if (!_claimedEmailVerificationTokens.add(token)) return false;
    await _preferences.clearPendingEmailVerificationToken(expectedToken: token);
    return true;
  }

  void releaseEmailVerificationToken(String token) {
    _claimedEmailVerificationTokens.remove(token);
    _receivedEmailVerificationTokens.remove(token);
  }

  Future<String?> _takePendingEmailVerificationToken() async {
    final token = await _preferences.takePendingEmailVerificationToken();
    if (token == null || !_claimedEmailVerificationTokens.add(token)) {
      return null;
    }
    return token;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _invitationController.close();
    await _emailVerificationController.close();
  }
}
