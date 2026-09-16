import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validators/form_validators.dart';
import '../../auth/widgets/auth_submit_button.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _initialName;
  String? _initialEmail;

  bool _hasLoaded = false;
  bool _allowPopAfterSave = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadProfile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();

    super.dispose();
  }

  bool get _isDirty {
    if (!_hasLoaded) {
      return false;
    }

    return _nameController.text.trim() != _initialName ||
        _emailController.text.trim() != _initialEmail;
  }

  Future<void> _loadProfile() async {
    final profileProvider = context.read<ProfileProvider>();

    final success = await profileProvider.loadProfile();

    if (!mounted) {
      return;
    }

    if (success) {
      final user = profileProvider.user;

      _initialName = user?.name;
      _initialEmail = user?.email;

      _nameController.text = user?.name ?? '';
      _emailController.text = user?.email ?? '';
    }

    setState(() {
      _hasLoaded = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_isDirty) {
      return;
    }

    final profileProvider = context.read<ProfileProvider>();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    final success = await profileProvider.updateProfile(
      name: name != _initialName ? name : null,
      email: email != _initialEmail ? email : null,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      setState(() {
        _initialName = name;
        _initialEmail = email;
        _allowPopAfterSave = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        Navigator.of(context).pop();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileProvider.errorMessage ?? 'No se pudo actualizar el perfil.',
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

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

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
                        'Modificar mi perfil',
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
              Expanded(child: _buildBody(profileProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ProfileProvider profileProvider) {
    if (!_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profileProvider.user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                profileProvider.errorMessage ?? 'No se pudo cargar tu perfil.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadProfile,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 22),
            AuthSubmitButton(
              text: 'Guardar cambios',
              isLoading: profileProvider.isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
