import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validators/form_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/password_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _allowPopAfterSave = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  bool get _isDirty {
    return _currentPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final success = await authProvider.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _allowPopAfterSave = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        Navigator.of(context).pop();

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada correctamente.'),
          ),
        );
      });
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'No se pudo modificar la contraseña.',
          ),
        ),
      );
    }
  }

  Future<void> _handlePopAttempt(bool didPop) async {
    if (didPop) {
      return;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text('Tenés cambios sin guardar. ¿Querés descartarlos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Descartar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDiscard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña actual es obligatoria.';
    }

    return null;
  }

  String? _validateNewPassword(String? value) {
    final passwordError = FormValidators.validatePassword(value);

    if (passwordError != null) {
      return passwordError;
    }

    if (value == _currentPasswordController.text) {
      return 'La nueva contraseña debe ser distinta a la actual.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirmá tu nueva contraseña.';
    }

    if (value != _newPasswordController.text) {
      return 'Las contraseñas no coinciden.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return PopScope(
      canPop: _allowPopAfterSave || !_isDirty,
      onPopInvokedWithResult: (didPop, result) {
        _handlePopAttempt(didPop);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Modificar mi contraseña',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PasswordTextField(
                          controller: _currentPasswordController,
                          label: 'Contraseña actual',
                          validator: _validateCurrentPassword,
                        ),
                        const SizedBox(height: 14),
                        PasswordTextField(
                          controller: _newPasswordController,
                          label: 'Nueva contraseña',
                          validator: _validateNewPassword,
                        ),
                        const SizedBox(height: 14),
                        PasswordTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar nueva contraseña',
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 22),
                        AuthSubmitButton(
                          text: 'Guardar cambios',
                          isLoading: authProvider.isChangingPassword,
                          onPressed: _submit,
                        ),
                      ],
                    ),
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
