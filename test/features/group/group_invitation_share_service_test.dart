import 'package:bond_front/features/group/services/group_invitation_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the invitation message with group, link, and fallback code', () {
    final message = GroupInvitationShareService.buildMessage(
      groupName: 'Familia',
      invitationCode: 'abc-def',
    );

    expect(message, contains('"Familia"'));
    expect(message, contains('https://bond.app/invite/ABCDEF'));
    expect(message, contains('Código de invitación: ABC-DEF'));
  });

  test('opens WhatsApp without invoking the system fallback', () async {
    Uri? launchedUri;
    var systemShareCalls = 0;
    final service = GroupInvitationShareService(
      launchExternalUri: (uri) async {
        launchedUri = uri;
        return true;
      },
      shareText: (_) async => systemShareCalls++,
    );

    final result = await service.shareViaWhatsApp(
      groupName: 'Familia',
      invitationCode: 'ABCDEF',
    );

    expect(result, InvitationShareResult.whatsappOpened);
    expect(launchedUri?.scheme, 'whatsapp');
    expect(launchedUri?.host, 'send');
    expect(launchedUri?.queryParameters['text'], contains('Familia'));
    expect(systemShareCalls, 0);
  });

  test('uses the system share sheet when WhatsApp cannot open', () async {
    String? sharedText;
    final service = GroupInvitationShareService(
      launchExternalUri: (_) async => false,
      shareText: (text) async => sharedText = text,
    );

    final result = await service.shareViaWhatsApp(
      groupName: 'Familia',
      invitationCode: 'ABCDEF',
    );

    expect(result, InvitationShareResult.systemShareOpened);
    expect(sharedText, contains('https://bond.app/invite/ABCDEF'));
  });

  test('uses the system share sheet when launching WhatsApp throws', () async {
    var systemShareCalls = 0;
    final service = GroupInvitationShareService(
      launchExternalUri: (_) async => throw Exception('not installed'),
      shareText: (_) async => systemShareCalls++,
    );

    await service.shareViaWhatsApp(
      groupName: 'Familia',
      invitationCode: 'ABCDEF',
    );

    expect(systemShareCalls, 1);
  });
}
