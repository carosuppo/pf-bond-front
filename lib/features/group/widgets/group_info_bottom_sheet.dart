import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../formatters/invitation_code_formatter.dart';
import '../models/get_group_model.response.dart';
import '../models/get_member_model.response.dart';
import '../providers/group_provider.dart';

class GroupInfoBottomSheet extends StatelessWidget {
  final GetGroupResponseModel group;
  final ScrollController scrollController;
  final Widget? bottomContent;

  const GroupInfoBottomSheet({
    super.key,
    required this.group,
    required this.scrollController,
    this.bottomContent,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final displayedGroup = groupProvider.groupDetails?.id == group.id
        ? groupProvider.groupDetails!
        : group;
    final isCurrentUserAdmin = displayedGroup.members.any(
      (member) =>
          member.idUser == authProvider.authResponse?.user.id &&
          member.role == RoleEnum.admin,
    );
    final adminCount = displayedGroup.members
        .where((member) => member.role == RoleEnum.admin)
        .length;

    return SafeArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Text(
                displayedGroup.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (displayedGroup.description != null &&
                displayedGroup.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                displayedGroup.description!,
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
                          formatInvitationCode(displayedGroup.invitationCode),
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
                            ClipboardData(text: displayedGroup.invitationCode),
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
                      Icons.location_on,
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
                          displayedGroup.shareLocationMandatorily
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
                      arguments: {
                        'group': displayedGroup,
                        'isCurrentUserAdmin': true,
                      },
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(
                  Icons.group_rounded,
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
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${displayedGroup.members.length}',
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
                  for (int i = 0; i < displayedGroup.members.length; i++) ...[
                    _MemberListItem(
                      member: displayedGroup.members[i],
                      isCurrentUser:
                          displayedGroup.members[i].idUser ==
                          authProvider.authResponse?.user.id,
                      isCurrentUserAdmin: isCurrentUserAdmin,
                      isOnlyAdmin: adminCount == 1,
                      isLoading: groupProvider.isLoading,
                    ),
                    if (i < displayedGroup.members.length - 1)
                      const Divider(height: 1, color: AppColors.fieldColor),
                  ],
                ],
              ),
            ),
            if (bottomContent != null) ...[
              const SizedBox(height: 24),
              bottomContent!,
            ],
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
  final bool isCurrentUser;
  final bool isCurrentUserAdmin;
  final bool isOnlyAdmin;
  final bool isLoading;

  const _MemberListItem({
    required this.member,
    required this.isCurrentUser,
    required this.isCurrentUserAdmin,
    required this.isOnlyAdmin,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          UserAvatar(
            name: member.name,
            photoUrl: member.profilePhoto,
            radius: 20,
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
          _MemberRoleSelector(
            member: member,
            isCurrentUser: isCurrentUser,
            isCurrentUserAdmin: isCurrentUserAdmin,
            isOnlyAdmin: isOnlyAdmin,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _MemberRoleSelector extends StatelessWidget {
  final GetMemberResponseModel member;
  final bool isCurrentUser;
  final bool isCurrentUserAdmin;
  final bool isOnlyAdmin;
  final bool isLoading;

  const _MemberRoleSelector({
    required this.member,
    required this.isCurrentUser,
    required this.isCurrentUserAdmin,
    required this.isOnlyAdmin,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _RoleBadge(
      label: _roleLabel(member.role),
      isAdmin: member.role == RoleEnum.admin,
      showDropdownIcon: isCurrentUserAdmin && !isLoading,
    );

    if (!isCurrentUserAdmin || isLoading) {
      return badge;
    }

    final canRevokeOnlyAdmin =
        isCurrentUser && isOnlyAdmin && member.role == RoleEnum.admin;
    final roles = <RoleEnum>[
      member.role,
      ...RoleEnum.values.where((role) => role != member.role),
    ];

    return PopupMenuButton<RoleEnum>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 150),
      tooltip: 'Modificar rol de ${member.name}',
      position: PopupMenuPosition.under,
      onSelected: (role) {
        if (role != member.role) {
          _confirmRoleChange(context, role);
        }
      },
      itemBuilder: (context) {
        return roles.map((role) {
          final isCurrentRole = role == member.role;
          final isDisabled =
              isCurrentRole || (canRevokeOnlyAdmin && role == RoleEnum.member);

          return PopupMenuItem<RoleEnum>(
            value: role,
            enabled: !isDisabled,
            child: Text(
              _roleLabel(role),
              style: TextStyle(
                color: isCurrentRole
                    ? AppColors.mutedText.withValues(alpha: 0.55)
                    : AppColors.mutedText,
              ),
            ),
          );
        }).toList();
      },
      child: badge,
    );
  }

  Future<void> _confirmRoleChange(BuildContext context, RoleEnum role) async {
    final isAssigningAdmin = role == RoleEnum.admin;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar cambio de rol'),
        content: Text(
          isAssigningAdmin
              ? '¿Querés asignar el rol de Administrador a ${member.name}?'
              : '¿Querés revocar el rol de Administrador de ${member.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final success = await groupProvider.updateMemberRole(
      memberId: member.id,
      role: role,
      isCurrentUserAdmin: isCurrentUserAdmin,
    );

    if (!context.mounted) {
      return;
    }

    final message = success
        ? 'Rol de ${member.name} actualizado correctamente.'
        : groupProvider.errorMessage ?? 'No se pudo modificar el rol.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _roleLabel(RoleEnum role) {
  switch (role) {
    case RoleEnum.admin:
      return 'Administrador';
    case RoleEnum.member:
      return 'Miembro';
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final bool isAdmin;
  final bool showDropdownIcon;

  const _RoleBadge({
    required this.label,
    required this.isAdmin,
    this.showDropdownIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isAdmin ? AppColors.primary : AppColors.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showDropdownIcon) ...[
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isAdmin ? AppColors.primary : AppColors.mutedText,
              size: 14,
            ),
          ],
        ],
      ),
    );
  }
}
