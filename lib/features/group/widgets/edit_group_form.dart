import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/global_text_field.dart';
import '../models/get_group_model.response.dart';
import '../providers/group_provider.dart';

class EditGroupForm extends StatefulWidget {
  final GetGroupResponseModel group;
  final bool isCurrentUserAdmin;

  const EditGroupForm({
    super.key,
    required this.group,
    required this.isCurrentUserAdmin,
  });

  @override
  State<EditGroupForm> createState() => _EditGroupFormState();
}

class _EditGroupFormState extends State<EditGroupForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late bool _shareLocationMandatorily;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(
      text: widget.group.description ?? '',
    );

    _shareLocationMandatorily = widget.group.shareLocationMandatorily;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  bool get _hasChanges {
    return _nameController.text.trim() != widget.group.name.trim() ||
        _descriptionController.text.trim() !=
            (widget.group.description?.trim() ?? '') ||
        _shareLocationMandatorily != widget.group.shareLocationMandatorily;
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

  Future<void> _updateGroup() async {
    if (!widget.isCurrentUserAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo los administradores pueden modificar el grupo.'),
        ),
      );

      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del grupo es obligatorio')),
      );

      return;
    }

    final provider = context.read<GroupProvider>();

    final success = await provider.updateGroup(
      groupId: widget.group.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      shareLocationMandatorily: _shareLocationMandatorily,
      isCurrentUserAdmin: widget.isCurrentUserAdmin,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo modificado correctamente')),
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
          content: Text(provider.errorMessage ?? 'Error al modificar grupo'),
        ),
      );
    }
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
                      'Editar grupo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),
                    if (!widget.isCurrentUserAdmin)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Text(
                          'No tenés permisos para modificar este grupo.',
                          style: TextStyle(color: AppColors.text),
                        ),
                      ),

                    GlobalTextField(
                      controller: _nameController,
                      label: 'Nombre del grupo',
                      enabled: widget.isCurrentUserAdmin,
                    ),

                    const SizedBox(height: 16),

                    GlobalTextField(
                      controller: _descriptionController,
                      label: 'Descripción',
                      enabled: widget.isCurrentUserAdmin,
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
                        onChanged: widget.isCurrentUserAdmin
                            ? (value) {
                                setState(() {
                                  _shareLocationMandatorily = value;
                                });
                              }
                            : null,
                      ),
                    ),

                    const SizedBox(height: 24),

                    AppPrimaryButton(
                      text: 'Guardar cambios',
                      loading: isLoading,
                      onPressed: widget.isCurrentUserAdmin
                          ? _updateGroup
                          : null,
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
