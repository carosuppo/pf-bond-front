import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/global_text_field.dart';
import '../formatters/invitation_code_formatter.dart';
import '../providers/group_provider.dart';

class JoinGroupForm extends StatefulWidget {
  const JoinGroupForm({super.key});

  @override
  State<JoinGroupForm> createState() => _JoinGroupFormState();
}

class _JoinGroupFormState extends State<JoinGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();

    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final groupProvider = context.read<GroupProvider>();

    final invitationCode = _codeController.text.replaceAll('-', '').trim();

    final success = await groupProvider.joinGroup(
      invitationCode: invitationCode,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      final message =
          groupProvider.joinResponse?.message ??
          'Ingresaste al grupo correctamente.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );

      await groupProvider.getGroups();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } else {
      final errorMessage = groupProvider.errorMessage;

      final message = errorMessage == 'Ya eres miembro de este grupo.'
          ? 'Ya perteneces a este grupo'
          : errorMessage ?? 'No se pudo ingresar al grupo.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  String? _validateCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código de invitación es obligatorio.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<GroupProvider>().isLoading;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final maxContentWidth = screenWidth > 600 ? 480.0 : double.infinity;
    final horizontalPadding = screenWidth > 600 ? 32.0 : 24.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth,
            ),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  Text(
                    'Unite a un grupo',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Ingresá el código de invitación que te compartieron',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.15,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GlobalTextField(
                            controller: _codeController,
                            label: 'Código de invitación',
                            textCapitalization:
                                TextCapitalization.characters,
                            maxLength: 7,
                            inputFormatters: [
                              InvitationCodeFormatter(),
                            ],
                            validator: _validateCode,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24),

                          AppPrimaryButton(
                            text: 'Ingresar',
                            loading: isLoading,
                            onPressed: _join,
                          ),

                          const SizedBox(height: 12),

                          AppSecondaryButton(
                            text: 'Atrás',
                            onPressed: _goBack,
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
