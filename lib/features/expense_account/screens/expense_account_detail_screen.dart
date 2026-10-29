import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/models/get_member_model.response.dart';
import '../formatters/money_formatter.dart';
import '../models/balance_status.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_group_details_loader.dart';
import '../widgets/account_header_card.dart';

class ExpenseAccountDetailScreen extends StatelessWidget {
  const ExpenseAccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _SummaryContent(accountId: accountId)),
    );
  }
}

class _SummaryContent extends StatefulWidget {
  const _SummaryContent({required this.accountId});

  final int accountId;

  @override
  State<_SummaryContent> createState() => _SummaryContentState();
}

class _SummaryContentState extends State<_SummaryContent> {
  late final ExpenseAccountProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseAccountProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _provider.loadAccountDetail(accountId: widget.accountId, force: true);
    });
  }

  @override
  void dispose() {
    _provider.clearDetail();
    super.dispose();
  }

  Future<void> _goToBalance() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountBalance,
      arguments: {'accountId': widget.accountId},
    );
  }

  Future<void> _goToMovements() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountMovements,
      arguments: {'accountId': widget.accountId},
    );
  }

  Future<void> _goToCreateExpense() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.createExpense,
      arguments: {'accountId': widget.accountId},
    );
  }

  Future<void> _goToPayments() async {
    final groupId = _provider.accountDetail?.groupId;
    if (groupId == null) return;

    final registered = await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountPayments,
      arguments: {'accountId': widget.accountId, 'groupId': groupId},
    );

    if (!mounted || registered != true) {
      return;
    }

    await Future.wait([
      _provider.loadAccountDetail(accountId: widget.accountId, force: true),
      _provider.loadAccounts(),
    ]);
  }

  Future<void> _goToEditAccount() async {
    final memberId = _provider.accountDetail?.myMemberId;
    final saved = await Navigator.of(context).pushNamed(
      AppRoutes.editExpenseAccount,
      arguments: {'accountId': widget.accountId},
    );
    if (!mounted || saved != true || memberId == null) return;

    final updated = _provider.updatedExpenseAccount;
    if (updated != null && !updated.memberIds.contains(memberId)) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmDeleteAccount(
    ExpenseAccountDetailResponseModel detail,
  ) async {
    if (_provider.isDeletingExpenseAccount) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text(
          'La cuenta «${detail.name}» dejará de estar disponible para todos '
          'sus miembros. Sus gastos, pagos e historial dejarán de estar '
          'accesibles desde la aplicación. Esta acción no se puede deshacer '
          'desde la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Eliminar cuenta',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
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

    return Column(
      children: [
        AppScreenHeader(
          title: provider.accountDetail?.name ?? 'Cuenta',
          onBack: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (provider.isDetailLoading || detail == null) {
                if (provider.detailErrorMessage != null) {
                  return _SummaryError(
                    message: provider.detailErrorMessage!,
                    onRetry: () =>
                        provider.loadAccountDetail(accountId: widget.accountId),
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return AccountGroupDetailsLoader(
                groupId: detail.groupId,
                builder: (context, groupDetails, isGroupDetailsLoading, _) {
                  final isGroupAdmin =
                      currentUserId != null &&
                      groupDetails?.members.any(
                            (member) =>
                                member.idUser == currentUserId &&
                                member.role == RoleEnum.admin,
                          ) ==
                          true;
                  final isCreator =
                      currentUserId != null &&
                      detail.createdByUserId == currentUserId;

                  return _SummaryBody(
                    detail: detail,
                    groupDetails: groupDetails,
                    isGroupDetailsLoading: isGroupDetailsLoading,
                    canDeleteAccount: isGroupAdmin || isCreator,
                    isDeletingAccount: provider.isDeletingExpenseAccount,
                    deleteErrorMessage:
                        provider.deleteExpenseAccountErrorMessage,
                    onDeleteAccountTap: () => _confirmDeleteAccount(detail),
                    onBalanceTap: _goToBalance,
                    onMovementsTap: _goToMovements,
                    onCreateExpenseTap: _goToCreateExpense,
                    onPaymentsTap: _goToPayments,
                    onEditAccountTap: _goToEditAccount,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.message, required this.onRetry});

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
            const Icon(
              Icons.error_outline,
              color: AppColors.mutedText,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.detail,
    required this.groupDetails,
    required this.isGroupDetailsLoading,
    required this.canDeleteAccount,
    required this.isDeletingAccount,
    required this.deleteErrorMessage,
    required this.onDeleteAccountTap,
    required this.onBalanceTap,
    required this.onMovementsTap,
    required this.onCreateExpenseTap,
    required this.onPaymentsTap,
    required this.onEditAccountTap,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel? groupDetails;
  final bool isGroupDetailsLoading;
  final bool canDeleteAccount;
  final bool isDeletingAccount;
  final String? deleteErrorMessage;
  final VoidCallback onDeleteAccountTap;
  final VoidCallback onBalanceTap;
  final VoidCallback onMovementsTap;
  final VoidCallback onCreateExpenseTap;
  final VoidCallback onPaymentsTap;
  final VoidCallback onEditAccountTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountHeaderCard(
            name: detail.name,
            groupName: detail.groupName,
            eventName: detail.eventName,
          ),
          const SizedBox(height: 12),
          _BalanceCard(
            detail: detail,
            groupDetails: groupDetails,
            isGroupDetailsLoading: isGroupDetailsLoading,
            onBalanceTap: onBalanceTap,
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(text: 'Ver movimientos', onPressed: onMovementsTap),
          const SizedBox(height: 12),
          AppSecondaryButton(
            text: 'Registrar gasto',
            onPressed: onCreateExpenseTap,
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            text: 'Registrar pagos',
            onPressed: onPaymentsTap,
            leading: const Icon(Icons.payments_outlined),
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            text: 'Editar cuenta',
            onPressed: onEditAccountTap,
            leading: const Icon(Icons.edit_outlined),
          ),
          if (canDeleteAccount) ...[
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: isDeletingAccount ? null : onDeleteAccountTap,
                icon: isDeletingAccount
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.error,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(
                  isDeletingAccount ? 'Eliminando…' : 'Eliminar cuenta',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (deleteErrorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                deleteErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.detail,
    required this.groupDetails,
    required this.isGroupDetailsLoading,
    required this.onBalanceTap,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel? groupDetails;
  final bool isGroupDetailsLoading;
  final VoidCallback onBalanceTap;

  List<int> get _highlightedMemberIds {
    final debts = [
      ...detail.debtsToMe.map((debt) => debt.memberId),
      ...detail.myDebts.map((debt) => debt.memberId),
    ];

    if (debts.isNotEmpty) {
      return debts.toSet().toList(growable: false);
    }

    return detail.members.map((member) => member.memberId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.myStatus == BalanceStatus.aFavor
                      ? 'Te deben'
                      : detail.myStatus == BalanceStatus.enContra
                      ? 'Debés'
                      : 'Saldado',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            MoneyFormatter.formatCentsShort(detail.myBalanceCents),
            style: TextStyle(
              color: detail.myStatus.color,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _MembersPreview(
            memberIds: detail.members
                .map((member) => member.memberId)
                .toList(growable: false),
            previewIds: _highlightedMemberIds,
            groupId: detail.groupId,
            groupDetails: groupDetails,
            isGroupDetailsLoading: isGroupDetailsLoading,
          ),
          const SizedBox(height: 12),
          _TextActionButton(text: 'Ver mi balance', onTap: onBalanceTap),
        ],
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersPreview extends StatefulWidget {
  const _MembersPreview({
    required this.memberIds,
    required this.previewIds,
    required this.groupId,
    required this.groupDetails,
    required this.isGroupDetailsLoading,
  });

  final List<int> memberIds;
  final List<int> previewIds;
  final int groupId;
  final GetGroupResponseModel? groupDetails;
  final bool isGroupDetailsLoading;

  @override
  State<_MembersPreview> createState() => _MembersPreviewState();
}

class _MembersPreviewState extends State<_MembersPreview> {
  bool _expanded = false;

  List<AvatarStackItem> _items(
    GetGroupResponseModel details, {
    bool all = false,
  }) {
    final byId = {
      if (details.id == widget.groupId)
        for (final member in details.members) member.id: member,
    };
    final ids = all ? widget.memberIds : widget.previewIds.take(5);

    return [
      for (final memberId in ids)
        AvatarStackItem(
          name: byId[memberId]?.name ?? 'Miembro',
          photoUrl: byId[memberId]?.profilePhoto,
        ),
    ];
  }

  Widget _buildPreview(GetGroupResponseModel details) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AvatarStack(items: _items(details)),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.mutedText,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          for (final item in _items(details, all: true))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  UserAvatar(
                    name: item.name,
                    photoUrl: item.photoUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGroupDetailsLoading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }
    final details = widget.groupDetails;
    if (details == null) {
      return const Text(
        'No se pudo cargar el grupo de esta cuenta.',
        style: TextStyle(color: AppColors.mutedText, fontSize: 13),
      );
    }
    return _buildPreview(details);
  }
}
