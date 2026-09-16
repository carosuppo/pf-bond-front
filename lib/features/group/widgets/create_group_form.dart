import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/global_text_field.dart';
import '../providers/group_provider.dart';
import 'invitation_code_modal.dart';

class CreateGroupForm extends StatefulWidget {
  const CreateGroupForm({super.key});

  @override
  State<CreateGroupForm> createState() => _CreateGroupFormState();
}

class _CreateGroupFormState extends State<CreateGroupForm> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _shareLocationMandatorily = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del grupo es obligatorio')),
      );

      return;
    }

    final provider = context.read<GroupProvider>();

    final success = await provider.createGroup(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      shareLocationMandatorily: _shareLocationMandatorily,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al crear grupo'),
        ),
      );

      return;
    }

    final invitationCode = provider.group?.invitationCode;

    if (invitationCode != null) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) {
          return InvitationCodeModal(invitationCode: invitationCode);
        },
      );

      if (!mounted) {
        return;
      }

      await provider.getGroups();

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Error al generar código de invitación',
          ),
        ),
      );
    }
  }

  bool get _hasChanges {
    return _nameController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _shareLocationMandatorily;
  }

  Future<void> _handleBack() async {
    if (!_hasChanges) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      return;
    }

    final shouldDiscard = await showDiscardChangesDialog(context);

    if (!mounted || !shouldDiscard) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<GroupProvider>().isLoading;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final maxContentWidth = screenWidth > 600 ? 480.0 : double.infinity;
    final horizontalPadding = screenWidth > 600 ? 32.0 : 24.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _handleBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    Text(
                      'Crear grupo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    GlobalTextField(
                      controller: _nameController,
                      label: 'Nombre del grupo',
                    ),

                    const SizedBox(height: 16),

                    GlobalTextField(
                      controller: _descriptionController,
                      label: 'Descripción (opcional)',
                    ),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.fieldColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SwitchListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        title: const Text(
                          'Compartir ubicación obligatoriamente',
                          style: TextStyle(color: AppColors.text),
                        ),
                        activeThumbColor: AppColors.primary,
                        value: _shareLocationMandatorily,
                        onChanged: isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _shareLocationMandatorily = value;
                                });
                              },
                      ),
                    ),

                    const SizedBox(height: 24),

                    AppPrimaryButton(
                      text: 'Crear grupo',
                      loading: isLoading,
                      onPressed: _createGroup,
                    ),

                    const SizedBox(height: 12),

                    AppSecondaryButton(
                      text: 'Cancelar',
                      onPressed: isLoading ? null : _handleBack,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
