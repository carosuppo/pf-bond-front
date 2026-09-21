import 'package:bond_front/features/group/services/group_invitation_share_service.dart';
import 'package:bond_front/features/group/widgets/invitation_code_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<void> _pumpModal(
  WidgetTester tester,
  GroupInvitationShareService shareService,
) async {
  await tester.pumpWidget(
    Provider<GroupInvitationShareService>.value(
      value: shareService,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvitationCodeModal(
              invitationCode: 'ABCDEF',
              groupName: 'Familia',
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows code, WhatsApp, copy, and done actions', (tester) async {
    final service = GroupInvitationShareService(
      launchExternalUri: (_) async => true,
      shareText: (_) async {},
    );

    await _pumpModal(tester, service);

    expect(find.text('ABC-DEF'), findsOneWidget);
    expect(find.text('Invitar por WhatsApp'), findsOneWidget);
    expect(find.text('Copiar código'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('opens the WhatsApp sharing service with group and code', (
    tester,
  ) async {
    Uri? launchedUri;
    final service = GroupInvitationShareService(
      launchExternalUri: (uri) async {
        launchedUri = uri;
        return true;
      },
      shareText: (_) async {},
    );
    await _pumpModal(tester, service);

    await tester.tap(find.text('Invitar por WhatsApp'));
    await tester.pump();

    expect(launchedUri?.scheme, 'whatsapp');
    expect(launchedUri?.queryParameters['text'], contains('"Familia"'));
    expect(launchedUri?.queryParameters['text'], contains('ABC-DEF'));
  });

  testWidgets('copy action keeps the manual invitation code available', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copiedText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final service = GroupInvitationShareService(
      launchExternalUri: (_) async => true,
      shareText: (_) async {},
    );
    await _pumpModal(tester, service);

    await tester.tap(find.text('Copiar código'));
    await tester.pump();

    expect(copiedText, 'ABCDEF');
    expect(find.text('Código copiado'), findsOneWidget);
  });
}
