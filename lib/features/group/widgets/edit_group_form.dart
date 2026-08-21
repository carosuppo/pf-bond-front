import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!widget.isCurrentUserAdmin)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Text('No tenés permisos para modificar este grupo.'),
            ),

          TextField(
            controller: _nameController,
            enabled: widget.isCurrentUserAdmin,
            decoration: const InputDecoration(labelText: 'Nombre del grupo'),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _descriptionController,
            enabled: widget.isCurrentUserAdmin,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),

          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Compartir ubicación obligatoriamente'),
            value: _shareLocationMandatorily,
            onChanged: widget.isCurrentUserAdmin
                ? (value) {
                    setState(() {
                      _shareLocationMandatorily = value;
                    });
                  }
                : null,
          ),

          const SizedBox(height: 16),

          AppPrimaryButton(
            text: 'Guardar cambios',
            loading: isLoading,
            onPressed: widget.isCurrentUserAdmin ? _updateGroup : null,
          ),

          const SizedBox(height: 12),

          AppSecondaryButton(
            text: 'Cancelar',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
