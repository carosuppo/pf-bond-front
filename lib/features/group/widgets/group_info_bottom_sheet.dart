import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/widgets/profile_photo_editor.dart';
import '../formatters/invitation_code_formatter.dart';
import '../models/get_group_model.response.dart';
import '../models/get_member_model.response.dart';
import '../providers/group_provider.dart';

class GroupInfoBottomSheet extends StatefulWidget {
  final GetGroupResponseModel group;
  final ScrollController scrollController;
  final Widget? bottomContent;
  final bool showMembersSection;

  const GroupInfoBottomSheet({
    super.key,
    required this.group,
    required this.scrollController,
    this.bottomContent,
    this.showMembersSection = true,
  });

  @override
  State<GroupInfoBottomSheet> createState() => _GroupInfoBottomSheetState();
}

class _GroupInfoBottomSheetState extends State<GroupInfoBottomSheet> {
  Future<void> _openImageEditor(GetGroupResponseModel group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Consumer<GroupProvider>(
        builder: (context, provider, child) {
          return PhotoEditorModal(
            title: 'Editar imagen del grupo',
            name: group.name,
            currentPhotoUrl: group.image,
            selectedPhoto: provider.selectedGroupImage,
            isSaving: provider.isSavingGroupImage,
            errorMessage: provider.errorMessage,
            selectionDescription: 'Elegí una imagen para personalizar tu grupo',
            onGallery: provider.pickGroupImageFromGallery,
            onCamera: provider.pickGroupImageFromCamera,
            onConfirm: () => provider.saveGroupImage(
              groupId: group.id,
              isCurrentUserAdmin: true,
            ),
            onCancel: provider.clearSelectedGroupImage,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final displayedGroup = groupProvider.groupDetails?.id == widget.group.id
        ? groupProvider.groupDetails!
        : widget.group;
    final isCurrentUserAdmin = displayedGroup.members.any(
      (member) =>
          member.idUser == authProvider.authResponse?.user.id &&
          member.role == RoleEnum.admin,
    );
    final adminCount = displayedGroup.members
        .where((member) => member.role == RoleEnum.admin)
        .length;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GroupImage(
              name: displayedGroup.name,
              imageUrl: displayedGroup.image,
              canEdit: isCurrentUserAdmin,
              onEdit: () => _openImageEditor(displayedGroup),
            ),
            const SizedBox(height: 16),
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

            if (widget.showMembersSection) ...[
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
            ],
            if (widget.bottomContent != null) ...[
              const SizedBox(height: 24),
              widget.bottomContent!,
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupImage extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool canEdit;
  final VoidCallback onEdit;

  const _GroupImage({
    required this.name,
    required this.imageUrl,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim();
    final avatar = image == null || image.isEmpty
        ? CircleAvatar(
            radius: 54,
            backgroundColor: AppColors.primary,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 38,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : ClipOval(
            child: Image.network(
              image,
              width: 108,
              height: 108,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => CircleAvatar(
                radius: 54,
                backgroundColor: AppColors.primary,
                child: const Icon(
                  Icons.groups_rounded,
                  color: AppColors.onPrimary,
                  size: 42,
                ),
              ),
            ),
          );

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (canEdit)
            Positioned(
              right: -2,
              bottom: -2,
              child: PhotoEditButton(
                onPressed: onEdit,
                tooltip: 'Editar imagen del grupo',
              ),
            ),
        ],
      ),
    );
  }
}

class GroupMembersBottomSheet extends StatelessWidget {
  final GetGroupResponseModel group;
  final ScrollController scrollController;

  const GroupMembersBottomSheet({
    super.key,
    required this.group,
    required this.scrollController,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final member in displayedGroup.members)
                  SizedBox(
                    width: cardWidth,
                    height: 170,
                    child: _MemberListItem(
                      member: member,
                      isCurrentUser:
                          member.idUser == authProvider.authResponse?.user.id,
                      isCurrentUserAdmin: isCurrentUserAdmin,
                      isOnlyAdmin: adminCount == 1,
                      isLoading: groupProvider.isLoading,
                      onRemove:
                          isCurrentUserAdmin &&
                              member.idUser !=
                                  authProvider.authResponse?.user.id
                          ? () => _confirmRemove(
                              context,
                              member.name,
                              member.id,
                              isCurrentUserAdmin,
                            )
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    String memberName,
    int memberId,
    bool isCurrentUserAdmin,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Expulsar miembro'),
        content: Text('¿Querés expulsar a $memberName del grupo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final success = await groupProvider.removeMember(
      memberId: memberId,
      isCurrentUserAdmin: isCurrentUserAdmin,
    );

    if (!context.mounted) {
      return;
    }

    final message = success
        ? 'Miembro expulsado correctamente.'
        : groupProvider.errorMessage ?? 'No se pudo expulsar al miembro.';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
  final VoidCallback? onRemove;

  const _MemberListItem({
    required this.member,
    required this.isCurrentUser,
    required this.isCurrentUserAdmin,
    required this.isOnlyAdmin,
    required this.isLoading,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Center(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UserAvatar(
                      name: member.name,
                      photoUrl: member.profilePhoto,
                      radius: 30,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      member.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MemberRoleSelector(
                      member: member,
                      isCurrentUser: isCurrentUser,
                      isCurrentUserAdmin: isCurrentUserAdmin,
                      isOnlyAdmin: isOnlyAdmin,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                tooltip: 'Expulsar miembro',
                onPressed: isLoading ? null : onRemove,
                color: AppColors.error,
                icon: const Icon(Icons.person_remove_outlined),
              ),
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
