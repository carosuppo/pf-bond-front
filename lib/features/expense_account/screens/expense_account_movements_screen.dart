import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/models/get_member_model.response.dart';
import '../balance/member_debt_trace.dart';
import '../formatters/money_formatter.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_group_details_loader.dart';
import '../widgets/account_movement_card.dart';

class ExpenseAccountMovementsScreen extends StatelessWidget {
  const ExpenseAccountMovementsScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _MovementsContent(accountId: accountId)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        highlightElevation: 12,
        onPressed: () => _goToCreateExpense(context),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  Future<void> _goToCreateExpense(BuildContext context) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRoutes.createExpense, arguments: {'accountId': accountId});
  }
}

class _MovementsContent extends StatefulWidget {
  const _MovementsContent({required this.accountId});

  final int accountId;

  @override
  State<_MovementsContent> createState() => _MovementsContentState();
}

class _MovementsContentState extends State<_MovementsContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ExpenseAccountProvider>().loadAccountDetail(
        accountId: widget.accountId,
        force: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final detail = provider.accountDetail;

    return Column(
      children: [
        AppScreenHeader(
          title: 'Movimientos',
          onBack: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (provider.isDetailLoading || detail == null) {
                if (provider.detailErrorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        provider.detailErrorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              return _MovementsTabs(detail: detail);
            },
          ),
        ),
      ],
    );
  }
}

class _MovementsTabs extends StatelessWidget {
  const _MovementsTabs({required this.detail});

  final ExpenseAccountDetailResponseModel detail;

  @override
  Widget build(BuildContext context) {
    return AccountGroupDetailsLoader(
      groupId: detail.groupId,
      builder: (context, groupDetails, isLoading, error) {
        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (groupDetails == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No se pudo cargar el grupo de esta cuenta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText, fontSize: 14),
              ),
            ),
          );
        }
        return _MovementsTabsContent(
          detail: detail,
          groupDetails: groupDetails,
          currentUserId: context.watch<AuthProvider>().authResponse?.user.id,
        );
      },
    );
  }
}

class _MovementsTabsContent extends StatelessWidget {
  const _MovementsTabsContent({
    required this.detail,
    required this.groupDetails,
    required this.currentUserId,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel groupDetails;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseAccountProvider>();
    final memberNames = {
      for (final member in groupDetails.members) member.id: member.name,
    };
    final knownExpenseCreators = <int, int>{};
    final createdExpense = expenseProvider.createdExpense;
    if (createdExpense?.createdByUserId != null) {
      knownExpenseCreators[createdExpense!.id] =
          createdExpense.createdByUserId!;
    }
    final updatedExpense = expenseProvider.updatedExpense;
    if (updatedExpense?.createdByUserId != null) {
      knownExpenseCreators[updatedExpense!.id] =
          updatedExpense.createdByUserId!;
    }
    final isGroupAdmin =
        currentUserId != null &&
        groupDetails.members.any(
          (member) =>
              member.idUser == currentUserId && member.role == RoleEnum.admin,
        );
    final expensePayers = {
      for (final movement in detail.movements)
        if (movement.kind == 'EXPENSE') movement.id: movement.payerMemberId!,
    };
    final expenses = detail.movements
        .where(
          (movement) =>
              movement.kind == 'EXPENSE' &&
              (memberMovementAmountCents(movement, detail.myMemberId) != null ||
                  isGroupAdmin ||
                  (currentUserId != null &&
                      (movement.createdByUserId ??
                              knownExpenseCreators[movement.id]) ==
                          currentUserId)),
        )
        .toList(growable: false);
    final payments = detail.movements
        .where(
          (movement) =>
              (movement.kind == 'PAYMENT' ||
                  (movement.kind == 'ADJUSTMENT' &&
                      movement.status == 'PENDING')) &&
              memberMovementAmountCents(movement, detail.myMemberId) != null,
        )
        .toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.mutedText,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Gastos'),
              Tab(text: 'Pagos'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _MovementsList(
                  emptyMessage: 'Todavía no hay gastos en esta cuenta.',
                  movements: expenses,
                  memberId: detail.myMemberId,
                  memberNames: memberNames,
                  accountId: detail.id,
                  isGroupAdmin: isGroupAdmin,
                  currentUserId: currentUserId,
                  allMovements: detail.movements,
                  expensePayers: expensePayers,
                  knownExpenseCreators: knownExpenseCreators,
                ),
                _MovementsList(
                  emptyMessage: 'Todavía no hay pagos en esta cuenta.',
                  movements: payments,
                  memberId: detail.myMemberId,
                  memberNames: memberNames,
                  accountId: detail.id,
                  isGroupAdmin: isGroupAdmin,
                  currentUserId: currentUserId,
                  allMovements: detail.movements,
                  expensePayers: expensePayers,
                  knownExpenseCreators: knownExpenseCreators,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsList extends StatelessWidget {
  const _MovementsList({
    required this.emptyMessage,
    required this.movements,
    required this.memberId,
    required this.memberNames,
    required this.accountId,
    required this.isGroupAdmin,
    required this.currentUserId,
    required this.allMovements,
    required this.expensePayers,
    required this.knownExpenseCreators,
  });

  final String emptyMessage;
  final List<AccountMovementModel> movements;
  final int memberId;
  final Map<int, String> memberNames;
  final int accountId;
  final bool isGroupAdmin;
  final int? currentUserId;
  final List<AccountMovementModel> allMovements;
  final Map<int, int> expensePayers;
  final Map<int, int> knownExpenseCreators;

  String _memberName(int? memberId) {
    return memberNames[memberId] ?? 'Miembro';
  }

  String _title(AccountMovementModel movement) {
    final title = movement.title?.trim();

    if (movement.kind == 'ADJUSTMENT') {
      final expenseTitle = movement.expenseTitle?.trim();
      return expenseTitle == null || expenseTitle.isEmpty
          ? 'Ajuste económico'
          : 'Ajuste · $expenseTitle';
    }

    if (title != null && title.isNotEmpty) {
      return title;
    }

    return movement.kind == 'EXPENSE' ? 'Gasto' : 'Pago';
  }

  String _subtitle(AccountMovementModel movement) {
    if (movement.kind == 'EXPENSE') {
      final memberShare = movement.shares.where(
        (share) => share.memberId == memberId && share.amountCents > 0,
      );
      if (memberShare.isNotEmpty && movement.payerMemberId == memberId) {
        return 'Tu parte · pagaste vos';
      }
      if (memberShare.isNotEmpty) {
        return 'Tu parte · pagó ${_memberName(movement.payerMemberId)}';
      }
      if (movement.payerMemberId == memberId) {
        return 'Adelantaste · pagaste vos';
      }
      return 'Pagó ${_memberName(movement.payerMemberId)}';
    }

    if (movement.kind == 'ADJUSTMENT') {
      final payerMemberId = expensePayers[movement.expenseId];
      final isRefund = movement.debtorMemberId == payerMemberId;
      final status = movement.status == 'PAID' ? 'Pagado' : 'Pendiente';
      if (movement.debtorMemberId == memberId) {
        return '$status · ${isRefund ? 'devolución a' : 'importe adicional a'} '
            '${_memberName(movement.creditorMemberId)}';
      }
      return '$status · ${_memberName(movement.debtorMemberId)} '
          '${isRefund ? 'devuelve a' : 'aporta a'} vos';
    }

    if (movement.kind == 'PAYMENT') {
      final direction = movement.fromMemberId == memberId
          ? 'Pagaste a ${_memberName(movement.toMemberId)}'
          : '${_memberName(movement.fromMemberId)} te pagó';
      final paymentLabel = movement.adjustmentId == null
          ? 'Pago'
          : 'Pago de ajuste';
      return movement.adjustmentId == null
          ? direction
          : '$paymentLabel · $direction';
    }

    if (movement.fromMemberId == memberId) {
      return 'Pagaste a ${_memberName(movement.toMemberId)}';
    }
    return '${_memberName(movement.fromMemberId)} te pagó';
  }

  Future<void> _confirmAnnulPayment(
    BuildContext context,
    AccountMovementModel payment,
  ) async {
    if (payment.kind != 'PAYMENT' || payment.fromMemberId != memberId) {
      return;
    }
    final provider = context.read<ExpenseAccountProvider>();
    if (provider.isAnnullingExpensePayment) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anular pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importe: ${MoneyFormatter.formatCentsShort(payment.amountCents)}',
            ),
            const SizedBox(height: 6),
            Text('Destinatario: ${_memberName(payment.toMemberId)}'),
            const SizedBox(height: 12),
            const Text(
              'La anulación volverá a afectar las obligaciones y los saldos pendientes. Esta acción no se puede deshacer.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Anular pago'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        provider.isAnnullingExpensePayment) {
      return;
    }

    final succeeded = await provider.annulExpensePayment(
      accountId: accountId,
      paymentId: payment.id,
    );
    if (!context.mounted) return;

    final message = succeeded
        ? 'Pago anulado. Se actualizaron las obligaciones y los saldos.'
        : provider.annulExpensePaymentErrorMessage ??
              'No se pudo anular el pago. Volvé a intentarlo.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDeleteExpense(
    BuildContext context,
    AccountMovementModel expense,
  ) async {
    if (expense.kind != 'EXPENSE') return;
    final provider = context.read<ExpenseAccountProvider>();
    if (provider.isDeletingExpense) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gasto: ${_title(expense)}'),
            const SizedBox(height: 6),
            Text(
              'Importe: ${MoneyFormatter.formatCentsShort(expense.amountCents)}',
            ),
            const SizedBox(height: 12),
            const Text(
              'La eliminación es definitiva y no se puede deshacer. Se actualizarán los saldos de los miembros afectados.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar gasto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted || provider.isDeletingExpense) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final deleted = await provider.deleteExpense(
      accountId: accountId,
      expenseId: expense.id,
    );
    if (!context.mounted) return;

    final message = deleted
        ? 'Gasto eliminado correctamente. Se actualizaron los saldos y movimientos.'
        : provider.deleteExpenseErrorMessage ??
              'No se pudo eliminar el gasto. Volvé a intentarlo.';
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    if (movements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.fieldColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 44,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: movements.length,
      itemBuilder: (_, index) {
        final movement = movements[index];
        final isExpense = movement.kind == 'EXPENSE';
        final canEdit =
            isExpense &&
            (isGroupAdmin ||
                (currentUserId != null &&
                    (movement.createdByUserId ??
                            knownExpenseCreators[movement.id]) ==
                        currentUserId));
        final hasConfirmedPayments =
            isExpense &&
            allMovements.any(
              (candidate) =>
                  candidate.expenseId == movement.id &&
                  ((candidate.kind == 'PAYMENT' &&
                          candidate.expenseShareId != null) ||
                      (candidate.kind == 'ADJUSTMENT' &&
                          candidate.status == 'PAID')),
            );
        final isOwnedConfirmedPayment =
            movement.kind == 'PAYMENT' && movement.fromMemberId == memberId;

        return AccountMovementCard(
          icon: isExpense
              ? Icons.receipt_long_outlined
              : Icons.payments_outlined,
          accentColor: movement.kind == 'ADJUSTMENT'
              ? AppColors.primary
              : isExpense
              ? AppColors.primary
              : AppColors.success,
          title: _title(movement),
          subtitle: _subtitle(movement),
          amountCents:
              memberMovementAmountCents(movement, memberId) ??
              (isExpense ? movement.amountCents : 0),
          createdAt: movement.settledAt ?? movement.createdAt,
          trailing: isOwnedConfirmedPayment
              ? IconButton(
                  tooltip: 'Anular pago',
                  onPressed: provider.isAnnullingExpensePayment
                      ? null
                      : () => _confirmAnnulPayment(context, movement),
                  icon: provider.annullingExpensePaymentId == movement.id
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.error,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.block_outlined,
                          color: AppColors.error,
                          size: 20,
                        ),
                  visualDensity: VisualDensity.compact,
                )
              : canEdit
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar gasto',
                      onPressed: provider.isDeletingExpense
                          ? null
                          : () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.createExpense,
                                arguments: {
                                  'accountId': accountId,
                                  'expense': movement,
                                  'hasConfirmedPayments': hasConfirmedPayments,
                                },
                              );
                            },
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Eliminar gasto',
                      onPressed: provider.isDeletingExpense
                          ? null
                          : () => _confirmDeleteExpense(context, movement),
                      icon: provider.deletingExpenseId == movement.id
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppColors.error,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}
