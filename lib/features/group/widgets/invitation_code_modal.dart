import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';

class InvitationCodeModal extends StatelessWidget {
  final String invitationCode;

  const InvitationCodeModal({super.key, required this.invitationCode});

  void _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: invitationCode));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código copiado')));
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
              invitationCode,

              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ),

          const SizedBox(height: 24),

          AppPrimaryButton(
            text: 'Copiar código',

            onPressed: () {
              _copyCode(context);
            },
          ),
        ],
      ),
    );
  }
}
