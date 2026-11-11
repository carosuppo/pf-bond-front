import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/models/get_member_model.response.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_group_details_loader.dart';
import '../widgets/account_header_card.dart';

class ExpenseAccountSettingsScreen extends StatefulWidget {
  const ExpenseAccountSettingsScreen({super.key, required this.accountId});

  final int accountId;

  @override
  State<ExpenseAccountSettingsScreen> createState() =>
      _ExpenseAccountSettingsScreenState();
}

class _ExpenseAccountSettingsScreenState
    extends State<ExpenseAccountSettingsScreen> {
  late final ExpenseAccountProvider _provider;
  int _groupDetailsLoadAttempt = 0;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseAccountProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _provider.accountDetail?.id == widget.accountId) return;
      _provider.loadAccountDetail(accountId: widget.accountId, force: true);
    });
  }

  int? _currentAccountMemberId(
    ExpenseAccountDetailResponseModel detail,
    GetGroupResponseModel? groupDetails,
    int? currentUserId,
  ) {
    if (currentUserId == null || groupDetails == null) return null;

    for (final member in groupDetails.members) {
      if (member.idUser == currentUserId &&
          detail.members.any(
            (accountMember) => accountMember.memberId == member.id,
          )) {
        return member.id;
      }
    }
    return null;
  }

  Future<void> _editAccount(int memberId) async {
    final saved = await Navigator.of(context).pushNamed(
      AppRoutes.editExpenseAccount,
      arguments: {'accountId': widget.accountId},
    );
    if (!mounted || saved != true) return;

    final updated = _provider.updatedExpenseAccount;
    if (updated != null && !updated.memberIds.contains(memberId)) {
      Navigator.of(context).pop(true);
    }
  }

  void _retryGroupDetails() {
    setState(() => _groupDetailsLoadAttempt++);
  }

  Future<void> _confirmDeleteAccount(
    ExpenseAccountDetailResponseModel detail,
  ) async {
    if (_provider.isDeletingExpenseAccount) return;

    final confirmed = await showAppMessageDialog(
      context,
      title: 'Eliminar cuenta',
      message:
          'La cuenta «${detail.name}» dejará de estar disponible para todos '
          'sus miembros. Sus gastos, pagos e historial dejarán de estar '
          'accesibles desde la aplicación. Esta acción no se puede deshacer '
          'desde la app.',
      confirmText: 'Eliminar cuenta',
      icon: Icons.delete_outline_rounded,
      accentColor: AppColors.error,
      confirmButtonColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final deleted = await _provider.deleteExpenseAccount(
      accountId: widget.accountId,
    );
    if (!mounted) return;

    if (deleted) {
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Cuenta eliminada correctamente.')),
      );
      return;
    }

    final errorMessage =
        _provider.deleteExpenseAccountErrorMessage ??
        'No se pudo eliminar la cuenta. Volvé a intentarlo.';
    messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final currentUserId = context.watch<AuthProvider>().authResponse?.user.id;
    final detail = provider.accountDetail;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (provider.isDetailLoading ||
                detail == null ||
                detail.id != widget.accountId) {
              if (provider.detailErrorMessage != null) {
                return _SettingsLoadError(
                  message: provider.detailErrorMessage!,
                  onRetry: () => provider.loadAccountDetail(
                    accountId: widget.accountId,
                    force: true,
                  ),
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            return AccountGroupDetailsLoader(
              key: ValueKey(_groupDetailsLoadAttempt),
              groupId: detail.groupId,
              builder: (context, groupDetails, isLoading, error) {
                if (isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (error != null || groupDetails == null) {
                  return _SettingsLoadError(
                    message: 'No se pudieron cargar los datos del grupo.',
                    onRetry: _retryGroupDetails,
                  );
                }

                final memberId = _currentAccountMemberId(
                  detail,
                  groupDetails,
                  currentUserId,
                );
                final isGroupAdmin =
                    currentUserId != null &&
                    groupDetails.members.any(
                      (member) =>
                          member.idUser == currentUserId &&
                          member.role == RoleEnum.admin,
                    );
                final isCreator =
                    currentUserId != null &&
                    detail.createdByUserId == currentUserId;

                return Column(
                  children: [
                    AppScreenHeader(
                      title: 'Configuración de cuenta',
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: _AccountSettingsContent(
                        detail: detail,
                        groupDetails: groupDetails,
                        canEdit: memberId != null,
                        canDelete: isCreator || isGroupAdmin,
                        isUpdating: provider.isUpdatingExpenseAccount,
                        isDeleting: provider.isDeletingExpenseAccount,
                        onEdit: memberId == null
                            ? null
                            : () => _editAccount(memberId),
                        onDelete: () => _confirmDeleteAccount(detail),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AccountSettingsContent extends StatelessWidget {
  const _AccountSettingsContent({
    required this.detail,
    required this.groupDetails,
    required this.canEdit,
    required this.canDelete,
    required this.isUpdating,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel? groupDetails;
  final bool canEdit;
  final bool canDelete;
  final bool isUpdating;
  final bool isDeleting;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  GetMemberResponseModel? _groupMember(int memberId) {
    for (final member in groupDetails?.members ?? const []) {
      if (member.id == memberId) return member;
    }
    return null;
  }

  Widget _sectionHeading(String title, {String? detail}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (detail != null)
            Text(
              detail,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _membersCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < detail.members.length; index++) ...[
            if (index > 0)
              const Divider(height: 1, color: AppColors.border, indent: 52),
            _MemberRow(
              name:
                  _groupMember(detail.members[index].memberId)?.name ??
                  'Miembro ${detail.members[index].memberId}',
              photoUrl: _groupMember(
                detail.members[index].memberId,
              )?.profilePhoto,
            ),
          ],
          if (detail.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No hay miembros asociados a esta cuenta.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editAction() {
    return Material(
      color: AppColors.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isUpdating ? null : onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editar cuenta',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Nombre, evento y miembros',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isUpdating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                )
              else
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

  Widget _deleteAction() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isDeleting ? null : onDelete,
        icon: isDeleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppColors.error,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.delete_outline),
        label: Text(isDeleting ? 'Eliminando…' : 'Eliminar cuenta'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeading('Información general'),
                AccountHeaderCard(
                  name: detail.name,
                  groupName: detail.groupName,
                  eventName: detail.eventName,
                ),
                const SizedBox(height: 20),
                if (canEdit) ...[
                  _sectionHeading('Administración'),
                  _editAction(),
                  const SizedBox(height: 20),
                ],
                _sectionHeading(
                  'Miembros asociados',
                  detail: '${detail.members.length}',
                ),
                _membersCard(),
              ],
            ),
          ),
        ),
        if (canDelete)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _deleteAction(),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          UserAvatar(name: name, photoUrl: photoUrl, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
