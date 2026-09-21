import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../formatters/invitation_code_formatter.dart';
import '../services/group_invitation_share_service.dart';

class InvitationCodeModal extends StatelessWidget {
  final String invitationCode;
  final String groupName;

  const InvitationCodeModal({
    super.key,
    required this.invitationCode,
    required this.groupName,
  });

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: invitationCode));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    try {
      await context.read<GroupInvitationShareService>().shareViaWhatsApp(
        groupName: groupName,
        invitationCode: invitationCode,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo compartir. Podés copiar el código manualmente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Código de invitación',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              formatInvitationCode(invitationCode),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            text: 'Invitar por WhatsApp',
            onPressed: () => _shareViaWhatsApp(context),
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            text: 'Copiar código',
            onPressed: () => _copyCode(context),
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            text: 'Listo',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
