import 'dart:async';

import 'package:bond_front/core/deep_links/app_link_service.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPreferences extends AppPreferencesService {
  String? pendingInvitationCode;

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
      AppLinkService.parseInvitationCode(
        Uri.parse('https://bond.app/invite/ABCDEF'),
      ),
      'ABCDEF',
    );
  });

  test('normalizes a displayed invitation code from a link', () {
    expect(
      AppLinkService.parseInvitationCode(
        Uri.parse('https://bond.app/invite/abc-def'),
      ),
      'ABCDEF',
    );
  });

  test('rejects links without a valid invitation code', () {
    expect(
      AppLinkService.parseInvitationCode(Uri.parse('https://bond.app/invite')),
      isNull,
    );
    expect(
      AppLinkService.parseInvitationCode(
        Uri.parse('https://bond.app/invite/ABC'),
      ),
      isNull,
    );
    expect(
      AppLinkService.parseInvitationCode(
        Uri.parse('https://other.app/invite/ABCDEF'),
      ),
      isNull,
    );
  });

  test('stores the cold-start invitation before authentication', () async {
    final preferences = _MemoryPreferences();
    final source = _FakeAppLinkSource(
      initialLink: Uri.parse('https://bond.app/invite/ABCDEF'),
    );
    final service = AppLinkService(preferences, source: source);

    await service.initialize();

    expect(preferences.pendingInvitationCode, 'ABCDEF');
    await service.dispose();
    await source.controller.close();
  });

  test('does not publish or persist a duplicated link twice', () async {
    final preferences = _MemoryPreferences();
    final source = _FakeAppLinkSource();
    final service = AppLinkService(preferences, source: source);
    var received = 0;
    final subscription = service.invitationCodes.listen((_) => received++);

    expect(
      await service.processUri(Uri.parse('https://bond.app/invite/ABCDEF')),
      isTrue,
    );
    expect(
      await service.processUri(Uri.parse('https://bond.app/invite/ABCDEF')),
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
