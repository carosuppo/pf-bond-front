import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/group_provider.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _isProcessing = false;

  Future<void> _createGroup() async {
    await Navigator.of(context).pushNamed(AppRoutes.createGroup);

    if (!mounted) return;

    await _refreshAndContinueIfHasGroups();
  }

  Future<void> _joinGroup() async {
    await Navigator.of(context).pushNamed(AppRoutes.joinGroup);

    if (!mounted) return;

    await _refreshAndContinueIfHasGroups();
  }

  Future<void> _refreshAndContinueIfHasGroups() async {
    setState(() => _isProcessing = true);

    final groupProvider = context.read<GroupProvider>();
    await groupProvider.loadGroups();

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (groupProvider.groups.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Mis grupos',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Center(
                    child: _isProcessing
                        ? const _LoadingState()
                        : _EmptyGroupsContent(
                            compact: screenHeight < 700,
                            onCreateGroup: _createGroup,
                            onJoinGroup: _joinGroup,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 16),
        Text(
          'Un momento...',
          style: TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
      ],
    );
  }
}

class _EmptyGroupsContent extends StatelessWidget {
  final bool compact;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  const _EmptyGroupsContent({
    required this.compact,
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 88 : 112,
            height: compact ? 88 : 112,
            decoration: const BoxDecoration(
              color: AppColors.fieldColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_rounded,
              size: compact ? 44 : 56,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: compact ? 20 : 28),
          const Text(
            '¡Bienvenido!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Todavía no formás parte de ningún grupo.\n'
            'Creá uno nuevo o unite con un código de invitación.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          SizedBox(height: compact ? 24 : 32),
          _ActionCard(
            icon: Icons.add_rounded,
            title: 'Crear un grupo',
            subtitle: 'Empezá uno nuevo e invitá a otras personas',
            onTap: onCreateGroup,
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.group_add_rounded,
            title: 'Unirme a un grupo',
            subtitle: 'Ingresá el código que te compartieron',
            onTap: onJoinGroup,
          ),
        ],
      ),
    );
  }
}

/// Tarjeta grande y táctil para cada acción principal.
/// El tamaño generoso y el texto de apoyo (subtitle) buscan que
/// la opción sea clara sin depender solo del ícono.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.fieldColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
