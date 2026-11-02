import 'dart:async';

import 'package:bond_front/core/deep_links/app_link_service.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPreferences extends AppPreferencesService {
  String? pendingInvitationCode;
  String? pendingEmailVerificationToken;

  @override
  Future<void> savePendingInvitationCode(String invitationCode) async {
    pendingInvitationCode = invitationCode;
  }

  @override
  Future<String?> getPendingInvitationCode() async => pendingInvitationCode;

  @override
  Future<bool> clearPendingInvitationCode({String? expectedCode}) async {
    if (expectedCode != null && expectedCode != pendingInvitationCode) {
      return false;
    }
    pendingInvitationCode = null;
    return true;
  }

  @override
  Future<void> savePendingEmailVerificationToken(String token) async {
    pendingEmailVerificationToken = token;
  }

  @override
  Future<String?> takePendingEmailVerificationToken() async {
    final token = pendingEmailVerificationToken;
    pendingEmailVerificationToken = null;
    return token;
  }

  @override
  Future<bool> clearPendingEmailVerificationToken({
    String? expectedToken,
  }) async {
    if (expectedToken != null &&
        expectedToken != pendingEmailVerificationToken) {
      return false;
    }
    pendingEmailVerificationToken = null;
    return true;
  }
}

class _FakeAppLinkSource implements AppLinkSource {
  _FakeAppLinkSource({this.initialLink});

  final Uri? initialLink;
  final StreamController<Uri> controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get uriLinkStream => controller.stream;
}

void main() {
  test('parses a valid Bond invitation link', () {
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('bond://invite/ABCDEF')),
      'ABCDEF',
    );
  });

  test('parses a valid email verification app link', () {
    final token = List.filled(64, 'a').join();

    expect(
      AppLinkService.parseEmailVerificationToken(
        Uri.parse('bond://verify-email?token=$token'),
      ),
      token,
    );
  });

  test('rejects malformed email verification app links', () {
    expect(
      AppLinkService.parseEmailVerificationToken(
        Uri.parse('bond://verify-email?token=invalid'),
      ),
      isNull,
    );
    expect(
      AppLinkService.parseEmailVerificationToken(
        Uri.parse('bond://invite/${List.filled(64, 'a').join()}'),
      ),
      isNull,
    );
  });

  test('normalizes a displayed invitation code from a link', () {
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('bond://invite/abc-def')),
      'ABCDEF',
    );
  });

  test('rejects links without a valid invitation code', () {
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('bond://invite/')),
      isNull,
    );
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('bond://invite/ABC')),
      isNull,
    );
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('bond://group/ABCDEF')),
      isNull,
    );
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('http://invite/ABCDEF')),
      isNull,
    );
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('bond://invite/ABCDEFG')),
      isNull,
    );
    expect(
      AppLinkService.parseInvitationCode(
        Uri.parse('bond://invite/ABCDEF/EXTRA'),
      ),
      isNull,
    );
  });

  test('stores the cold-start invitation before authentication', () async {
    final preferences = _MemoryPreferences();
    final source = _FakeAppLinkSource(
      initialLink: Uri.parse('bond://invite/ABCDEF'),
    );
    final service = AppLinkService(preferences, source: source);

    await service.initialize();

    expect(preferences.pendingInvitationCode, 'ABCDEF');
    await service.dispose();
    await source.controller.close();
  });

  test(
    'stores a cold-start email verification token for the splash screen',
    () async {
      final token = List.filled(64, 'b').join();
      final preferences = _MemoryPreferences();
      final source = _FakeAppLinkSource(
        initialLink: Uri.parse('bond://verify-email?token=$token'),
      );
      final service = AppLinkService(preferences, source: source);

      await service.initialize();

      expect(await service.takePendingEmailVerificationToken(), token);
      expect(await service.takePendingEmailVerificationToken(), isNull);
      await service.dispose();
      await source.controller.close();
    },
  );

  test('publishes a running email verification link once', () async {
    final token = List.filled(64, 'c').join();
    final preferences = _MemoryPreferences();
    final source = _FakeAppLinkSource();
    final service = AppLinkService(preferences, source: source);
    final received = <String>[];
    final subscription = service.emailVerificationTokens.listen(received.add);

    expect(
      await service.processUri(Uri.parse('bond://verify-email?token=$token')),
      isTrue,
    );
    expect(
      await service.processUri(Uri.parse('bond://verify-email?token=$token')),
      isFalse,
    );

    await Future<void>.delayed(Duration.zero);
    expect(received, [token]);
    expect(preferences.pendingEmailVerificationToken, token);
    expect(await service.claimEmailVerificationToken(token), isTrue);
    expect(await service.claimEmailVerificationToken(token), isFalse);
    expect(preferences.pendingEmailVerificationToken, isNull);
    await subscription.cancel();
    await service.dispose();
    await source.controller.close();
  });

  test('does not publish or persist a duplicated link twice', () async {
    final preferences = _MemoryPreferences();
    final source = _FakeAppLinkSource();
    final service = AppLinkService(preferences, source: source);
    var received = 0;
    final subscription = service.invitationCodes.listen((_) => received++);

    expect(await service.processUri(Uri.parse('bond://invite/ABCDEF')), isTrue);
    expect(
      await service.processUri(Uri.parse('bond://invite/ABCDEF')),
      isFalse,
    );

    await Future<void>.delayed(Duration.zero);
    expect(received, 1);
    expect(preferences.pendingInvitationCode, 'ABCDEF');
    await subscription.cancel();
    await service.dispose();
    await source.controller.close();
  });
}
