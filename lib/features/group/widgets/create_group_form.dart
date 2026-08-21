import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
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
      name: _nameController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      shareLocationMandatorily: _shareLocationMandatorily,

      // Temporal hasta integrar autenticación
      userId: 1,
    );

    if (!mounted) return;

    if (success) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) {
          return InvitationCodeModal(
            invitationCode: provider.group!.invitationCode,
          );
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
          content: Text(provider.errorMessage ?? 'Error al crear grupo'),
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
          TextField(
            controller: _nameController,

            decoration: const InputDecoration(labelText: 'Nombre del grupo'),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _descriptionController,

            decoration: const InputDecoration(labelText: 'Descripción'),
          ),

          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Compartir ubicación obligatoriamente'),

            value: _shareLocationMandatorily,

            onChanged: (value) {
              setState(() {
                _shareLocationMandatorily = value;
              });
            },
          ),

          const SizedBox(height: 16),

          AppPrimaryButton(
            text: 'Crear grupo',
            loading: isLoading,
            onPressed: _createGroup,
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
