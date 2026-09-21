import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_link_config.dart';
import '../formatters/invitation_code_formatter.dart';
import '../utils/invitation_code.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);
typedef SystemTextSharer = Future<void> Function(String text);

enum InvitationShareResult { whatsappOpened, systemShareOpened }

class GroupInvitationShareService {
  GroupInvitationShareService({
    ExternalUriLauncher? launchExternalUri,
    SystemTextSharer? shareText,
  }) : _launchExternalUri = launchExternalUri ?? _defaultLaunchExternalUri,
       _shareText = shareText ?? _defaultShareText;

  final ExternalUriLauncher _launchExternalUri;
  final SystemTextSharer _shareText;

  static String buildMessage({
    required String groupName,
    required String invitationCode,
  }) {
    final normalizedCode = InvitationCode.normalize(invitationCode);
    final invitationLink = AppLinkConfig.invitationUri(normalizedCode);
    final displayedCode = formatInvitationCode(normalizedCode);

    return 'Te invito a unirte a mi grupo "$groupName" en Bond.\n\n'
        'Tocá el enlace para unirte directamente:\n'
        '$invitationLink\n\n'
        'Código de invitación: $displayedCode';
  }

  Future<InvitationShareResult> shareViaWhatsApp({
    required String groupName,
    required String invitationCode,
  }) async {
    final message = buildMessage(
      groupName: groupName,
      invitationCode: invitationCode,
    );
    final whatsappUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {'text': message},
    );

    try {
      final opened = await _launchExternalUri(whatsappUri);
      if (opened) {
        return InvitationShareResult.whatsappOpened;
      }
    } catch (_) {
      // The system share sheet below is the supported fallback.
    }

    await _shareText(message);
    return InvitationShareResult.systemShareOpened;
  }

  static Future<bool> _defaultLaunchExternalUri(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _defaultShareText(String text) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: 'Invitación a un grupo de Bond',
        subject: 'Invitación a Bond',
      ),
    );
  }
}
