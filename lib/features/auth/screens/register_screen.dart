import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/validators/form_validators.dart';
import '../providers/auth_provider.dart';
import '../utils/minimum_account_age.dart';
import '../utils/terms_of_use.dart';
import '../widgets/auth_submit_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final TapGestureRecognizer _privacyPolicyRecognizer;
  late final TapGestureRecognizer _termsOfUseRecognizer;
  DateTime? _birthDate;
  bool _showAgeStep = false;
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
    _nameController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _privacyPolicyRecognizer.dispose();
    _termsOfUseRecognizer.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_showAgeStep) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _showAgeStep = true);
      return;
    }
    if (!_ageFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();

    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: email,
      password: _passwordController.text,
      birthDate: serializeBirthDate(_birthDate!),
      termsVersion: termsOfUseVersion,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.emailVerificationRequired,
        arguments: email,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'No se pudo registrar el usuario.',
          ),
        ),
      );
    }
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

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
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
    return _showAgeStep
        ? _buildAgeStep(context, authProvider)
        : _buildRegistrationForm(context, authProvider);
  }

  Widget _buildRegistrationForm(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
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
                'Crear cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Registrate para empezar a organizar tus grupos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'Necesitás verificar tu correo antes de poder usar la aplicación.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 14),
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
                        controller: _nameController,
                        label: 'Nombre',
                        validator: FormValidators.validateName,
                      ),
                      const SizedBox(height: 14),
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: FormValidators.validateEmail,
                      ),
                      const SizedBox(height: 14),
                      PasswordTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        validator: FormValidators.validatePassword,
                      ),
                      const SizedBox(height: 14),
                      PasswordTextField(
                        controller: _confirmPasswordController,
                        label: 'Repetir contraseña',
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 22),
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
                      AuthSubmitButton(
                        text: 'Registrarse',
                        isLoading: authProvider.isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: _goToLogin,
                        child: const Text(
                          '¿Ya tenés cuenta? Iniciá sesión',
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
              const SizedBox(height: 20),
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
                        validator: (_) => validateMinimumAccountAge(_birthDate),
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
                      AuthSubmitButton(
                        text: 'Registrar',
                        isLoading: authProvider.isLoading,
                        onPressed: _submit,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _showAgeStep = false),
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

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Repetí la contraseña.';
    }

    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }

    return null;
  }
}
