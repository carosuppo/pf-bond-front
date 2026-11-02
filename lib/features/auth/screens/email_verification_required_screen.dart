import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../providers/auth_provider.dart';

class EmailVerificationRequiredScreen extends StatefulWidget {
  const EmailVerificationRequiredScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailVerificationRequiredScreen> createState() =>
      _EmailVerificationRequiredScreenState();
}

class _EmailVerificationRequiredScreenState
    extends State<EmailVerificationRequiredScreen> {
  bool _emailSent = false;

  void _goToLogin() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _emailSent = false);
    final sent = await context.read<AuthProvider>().resendVerificationEmail(
      email: widget.email,
    );
    if (!mounted) return;
    setState(() => _emailSent = sent);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(title: 'Verificar correo', onBack: _goToLogin),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppColors.primary,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tu cuenta necesita estar verificada',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Para poder usar Bond, verificá tu correo. Enviamos un enlace al registrarte. Si no lo recibiste o el enlace expiró, podés reenviarlo a:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_emailSent) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Si tu cuenta continúa sin verificar, se envió un nuevo enlace. Revisá también la carpeta de spam.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.success),
                      ),
                    ],
                    if (authProvider.resendVerificationErrorMessage !=
                        null) ...[
                      const SizedBox(height: 20),
                      Text(
                        authProvider.resendVerificationErrorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 28),
                    AppPrimaryButton(
                      text: 'Reenviar correo',
                      loading: authProvider.isResendingVerificationEmail,
                      onPressed: _resendVerificationEmail,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _goToLogin,
                      child: const Text('Volver al inicio de sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
