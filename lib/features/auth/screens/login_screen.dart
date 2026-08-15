import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';

import '../../location/providers/location_provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider =
        context.read<AuthProvider>();

    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      await ref
          .read(locationProvider.notifier)
          .restoreSharingAndTracking();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.groups,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ??
                'No se pudo iniciar sesión.',
          ),
        ),
      );
    }
  }

  void _showGooglePendingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ingreso con Google disponible próximamente.',
        ),
      ),
    );
  }

  void _goToRegister() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.register,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider =
        context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              const Text(
                'Bond',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Iniciar sesión',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Ingresá para continuar con tus grupos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AuthTextField(
                        controller:
                            _emailController,
                        label: 'Email',
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        validator:
                            _validateEmail,
                      ),

                      const SizedBox(height: 14),

                      AuthTextField(
                        controller:
                            _passwordController,
                        label: 'Contraseña',
                        obscureText: true,
                        validator:
                            _validatePassword,
                      ),

                      const SizedBox(height: 22),

                      AuthSubmitButton(
                        text: 'Ingresar',
                        isLoading:
                            authProvider.isLoading,
                        onPressed: _submit,
                      ),

                      const SizedBox(height: 18),

                      const Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color:
                                  AppColors.divider,
                            ),
                          ),
                          Padding(
                            padding:
                                EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            child: Text(
                              'o',
                              style: TextStyle(
                                color:
                                    AppColors
                                        .mutedText,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color:
                                  AppColors.divider,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed:
                              _showGooglePendingMessage,
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              color:
                                  AppColors.primary,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          label: const Text(
                            'Ingresar con Google',
                          ),
                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                AppColors.text,
                            side: const BorderSide(
                              color:
                                  AppColors.primary,
                              width: 1.4,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                    14,
                                  ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextButton(
                        onPressed: _goToRegister,
                        child: const Text(
                          '¿No tenés cuenta? Registrate',
                          style: TextStyle(
                            color:
                                AppColors.primary,
                          ),
                        ),
                      ),
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

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'El email es obligatorio.';
    }

    final emailRegex = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Ingresá un email válido.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'La contraseña es obligatoria.';
    }

    if (password.length < 8 ||
        password.length > 16) {
      return 'La contraseña debe tener entre 8 y 16 caracteres.';
    }

    return null;
  }
}
