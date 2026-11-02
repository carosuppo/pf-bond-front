import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/routes/navigation/post_auth_navigator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../group/providers/group_provider.dart';
import '../../group/services/group_invitation_coordinator.dart';
import '../../location/providers/location_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/minimum_account_age.dart';
import '../utils/terms_of_use.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageFormKey = GlobalKey<FormState>();
  final _termsFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthDateController = TextEditingController();
  late final TapGestureRecognizer _privacyPolicyRecognizer;
  late final TapGestureRecognizer _termsOfUseRecognizer;
  DateTime? _birthDate;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _privacyPolicyRecognizer = TapGestureRecognizer()
      ..onTap = _openPrivacyPolicy;
    _termsOfUseRecognizer = TapGestureRecognizer()..onTap = _openTermsOfUse;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _privacyPolicyRecognizer.dispose();
    _termsOfUseRecognizer.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    final authProvider = context.read<AuthProvider>();
    final ageStep = authProvider.ageVerificationRequired;
    final termsStep = authProvider.termsAcceptanceRequired;
    final formKey = ageStep
        ? _ageFormKey
        : termsStep
        ? _termsFormKey
        : _formKey;
    if (!formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    final success = await authProvider.login(
      email: email,
      password: _passwordController.text,
      birthDate: authProvider.ageVerificationRequired
          ? serializeBirthDate(_birthDate!)
          : null,
      termsVersion: authProvider.termsAcceptanceRequired
          ? termsOfUseVersion
          : null,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      if (authProvider.emailVerificationRequired) {
        Navigator.of(
          context,
        ).pushNamed(AppRoutes.emailVerificationRequired, arguments: email);
        return;
      }

      if (authProvider.ageVerificationRequired) return;
      if (authProvider.termsAcceptanceRequired) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'No se pudo iniciar sesión.',
          ),
        ),
      );
      return;
    }

    await const PostAuthNavigator().navigate(
      context: context,
      groupProvider: context.read<GroupProvider>(),
      locationNotifier: ref.read(locationProvider.notifier),
      invitationCoordinator: context.read<GroupInvitationCoordinator>(),
      authProvider: authProvider,
    );
  }

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? today,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Ingrese su fecha de nacimiento',
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      _birthDate = selectedDate;
      _birthDateController.text = formatBirthDate(selectedDate);
    });
  }

  void _goToRegister() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.register);
  }

  void _cancelAgeStep() {
    _birthDate = null;
    _birthDateController.clear();
    context.read<AuthProvider>().cancelAgeVerification();
  }

  void _cancelTermsStep() {
    _termsAccepted = false;
    context.read<AuthProvider>().cancelTermsAcceptance();
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      ApiConfig.privacyPolicyUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la política de privacidad.'),
        ),
      );
    }
  }

  Future<void> _openTermsOfUse() async {
    final opened = await launchUrl(
      ApiConfig.termsOfUseUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron abrir los Términos de uso.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (authProvider.ageVerificationRequired) {
      return _buildAgeStep(context, authProvider);
    }
    if (authProvider.termsAcceptanceRequired) {
      return _buildTermsStep(context, authProvider);
    }
    return _buildLoginForm(context, authProvider);
  }

  Widget _buildLoginForm(BuildContext context, AuthProvider authProvider) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),

                      const SizedBox(height: 14),

                      PasswordTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        validator: _validatePassword,
                      ),

                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: AppPrimaryButton(
                          text: 'Ingresar',
                          loading: authProvider.isLoading,
                          onPressed: _submit,
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextButton(
                        onPressed: _goToRegister,
                        child: const Text(
                          '¿No tenés cuenta? Registrate',
                          style: TextStyle(color: AppColors.primary),
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

  Widget _buildAgeStep(BuildContext context, AuthProvider authProvider) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                'Verificar edad',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
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
                  key: _ageFormKey,
                  child: Column(
                    children: [
                      AuthTextField(
                        controller: _birthDateController,
                        label: 'Ingrese su fecha de nacimiento',
                        readOnly: true,
                        onTap: _selectBirthDate,
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                        validator: (_) => validateBirthDateRequired(_birthDate),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Esta fecha se usa solo para verificar la edad y no se guarda en tu perfil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: AppPrimaryButton(
                          text: 'Continuar',
                          loading: authProvider.isLoading,
                          onPressed: _submit,
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelAgeStep,
                        child: const Text('Volver'),
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

  Widget _buildTermsStep(BuildContext context, AuthProvider authProvider) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                'Términos de uso',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
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
                  key: _termsFormKey,
                  child: Column(
                    children: [
                      FormField<bool>(
                        initialValue: _termsAccepted,
                        validator: (value) => value == true
                            ? null
                            : 'Aceptá los Términos de uso y la Política de privacidad para continuar.',
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: field.value ?? false,
                                  onChanged: (value) {
                                    final accepted = value ?? false;
                                    setState(() => _termsAccepted = accepted);
                                    field.didChange(accepted);
                                  },
                                  activeColor: AppColors.primary,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 13),
                                    child: Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                          color: AppColors.mutedText,
                                          fontSize: 13,
                                        ),
                                        children: [
                                          const TextSpan(text: 'Acepto los '),
                                          TextSpan(
                                            text: 'Términos de uso',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer: _termsOfUseRecognizer,
                                          ),
                                          const TextSpan(text: ' y la '),
                                          TextSpan(
                                            text: 'Política de privacidad',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer:
                                                _privacyPolicyRecognizer,
                                          ),
                                          const TextSpan(text: ' de Bond.'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (field.hasError)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  field.errorText!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: AppPrimaryButton(
                          text: 'Continuar',
                          loading: authProvider.isLoading,
                          onPressed: _submit,
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelTermsStep,
                        child: const Text('Volver'),
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

    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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

    if (password.length < 8 || password.length > 16) {
      return 'La contraseña debe tener entre 8 y 16 caracteres.';
    }

    return null;
  }
}
