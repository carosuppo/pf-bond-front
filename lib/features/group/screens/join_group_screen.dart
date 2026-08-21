import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../formatters/invitation_code_formatter.dart';
import '../providers/group_provider.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
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
      ).showSnackBar(SnackBar(content: Text(message)));

      await groupProvider.getGroups();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            groupProvider.errorMessage ?? 'No se pudo ingresar al grupo.',
          ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar a un grupo')),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const Text(
                'Unite a un grupo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Ingresá el código de invitación que te compartieron.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 15),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),

                child: Form(
                  key: _formKey,

                  child: Column(
                    children: [
                      TextFormField(
                        controller: _codeController,
                        style: const TextStyle(color: AppColors.text),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 7,
                        inputFormatters: [InvitationCodeFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Código de invitación',
                          counterText: '',
                        ),
                        validator: _validateCode,
                      ),

                      const SizedBox(height: 22),

                      AppPrimaryButton(
                        text: 'Ingresar',
                        loading: isLoading,
                        onPressed: _join,
                      ),

                      const SizedBox(height: 12),

                      AppSecondaryButton(text: 'Atrás', onPressed: _goBack),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
