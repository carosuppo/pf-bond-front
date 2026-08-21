import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/get_group_model.response.dart';
import '../models/get_member_model.response.dart';

class GroupInfoBottomSheet extends StatelessWidget {
  final GetGroupResponseModel group;
  final ScrollController scrollController;

  const GroupInfoBottomSheet({
    super.key,
    required this.group,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isCurrentUserAdmin = group.members.any(
      (member) =>
          member.idUser == authProvider.authResponse?.user.id &&
          member.role == RoleEnum.admin,
    );

    return SafeArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedText,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              group.name,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (group.description != null &&
                group.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                group.description!,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 24),
            _GroupSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Código de invitación',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.invitationCode,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: group.invitationCode),
                          );

                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código de invitación copiado'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        color: AppColors.primary,
                        tooltip: 'Copiar código',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _GroupSectionCard(
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.fieldColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compartición de ubicación',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          group.shareLocationMandatorily
                              ? 'Obligatoria'
                              : 'No obligatoria',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    group.shareLocationMandatorily
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ],
              ),
            ),

            if (isCurrentUserAdmin) ...[
              const SizedBox(height: 16),
              Center(
                child: AppPrimaryButton(
                  text: 'Modificar grupo',
                  loading: false,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.updateGroup,
                      arguments: {'group': group, 'isCurrentUserAdmin': true},
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Miembros',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fieldColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.members.length}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _GroupSectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < group.members.length; i++) ...[
                    _MemberListItem(member: group.members[i]),
                    if (i < group.members.length - 1)
                      const Divider(height: 1, color: AppColors.divider),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GroupSectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _MemberListItem extends StatelessWidget {
  final GetMemberResponseModel member;

  const _MemberListItem({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.fieldColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.name,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _RoleBadge(
            label: _roleLabel(member.role),
            isAdmin: member.role == RoleEnum.admin,
          ),
        ],
      ),
    );
  }

  String _roleLabel(RoleEnum role) {
    switch (role) {
      case RoleEnum.admin:
        return 'Administrador';
      case RoleEnum.member:
        return 'Miembro';
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool isAdmin;

  const _RoleBadge({required this.label, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isAdmin ? AppColors.primary : AppColors.mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
