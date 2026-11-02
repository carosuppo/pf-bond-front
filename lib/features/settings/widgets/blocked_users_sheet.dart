import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../group/models/blocked_user_model.dart';
import '../../group/services/group_service.dart';

class BlockedUsersSheet extends StatefulWidget {
  const BlockedUsersSheet({super.key});

  @override
  State<BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<BlockedUsersSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<BlockedUserModel> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final blockedUsers = await context.read<GroupService>().getBlockedUsers();
      if (!mounted) return;
      setState(() => _blockedUsers = blockedUsers);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(BlockedUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desbloquear usuario'),
        content: Text(
          '¿Querés desbloquear a ${user.name}? Si ambos comparten un grupo, volverán a ver sus perfiles y ubicaciones, salvo que esa persona también te haya bloqueado. No se modifican las membresías ni el contenido de los grupos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<GroupService>().unblockUser(userId: user.userId);
      if (!mounted) return;
      await _loadBlockedUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.name} fue desbloqueado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Usuarios bloqueados',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loadBlockedUsers,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_blockedUsers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No hay usuarios bloqueados.',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return ListTile(
                      leading: UserAvatar(
                        name: user.name,
                        photoUrl: user.profilePhoto,
                        radius: 22,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(color: AppColors.text),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unblock(user),
                        child: const Text('Desbloquear'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
