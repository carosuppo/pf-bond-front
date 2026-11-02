import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../event/formatters/event_date_formatter.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/models/get_member_model.response.dart';
import '../balance/member_debt_trace.dart';
import '../formatters/account_movement_formatter.dart';
import '../formatters/money_formatter.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/expense_model.response.dart';
import '../models/expense_payment_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_group_details_loader.dart';
import '../widgets/account_movement_card.dart';
import '../widgets/account_new_movement_sheet.dart';
import '../widgets/account_payment_status_badge.dart';

class ExpenseAccountMovementsScreen extends StatelessWidget {
  const ExpenseAccountMovementsScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _MovementsContent(accountId: accountId)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        highlightElevation: 12,
        onPressed: () => _showNewMovementOptions(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo movimiento'),
      ),
    );
  }

  Future<void> _showNewMovementOptions(BuildContext context) async {
    final selection = await showAccountNewMovementSheet(context);
    if (selection == null || !context.mounted) return;

    switch (selection) {
      case NewAccountMovementType.expense:
        await Navigator.of(context).pushNamed(
          AppRoutes.createExpense,
          arguments: {'accountId': accountId},
        );
        break;
      case NewAccountMovementType.payment:
        final groupId = context
            .read<ExpenseAccountProvider>()
            .accountDetail
            ?.groupId;
        if (groupId == null) return;
        await Navigator.of(context).pushNamed(
          AppRoutes.expenseAccountPayments,
          arguments: {'accountId': accountId, 'groupId': groupId},
        );
        break;
    }
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

              return _MovementsGroupContent(detail: detail);
            },
          ),
        ),
      ],
    );
  }
}

class _MovementsGroupContent extends StatelessWidget {
  const _MovementsGroupContent({required this.detail});

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
        return _MovementsListContent(
          detail: detail,
          groupDetails: groupDetails,
          currentUserId: context.watch<AuthProvider>().authResponse?.user.id,
        );
      },
    );
  }
}

class _MovementsListContent extends StatelessWidget {
  const _MovementsListContent({
    required this.detail,
    required this.groupDetails,
    required this.currentUserId,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel groupDetails;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    final isGroupAdmin =
        currentUserId != null &&
        groupDetails.members.any(
          (member) =>
              member.idUser == currentUserId && member.role == RoleEnum.admin,
        );
    return _MovementsList(
      detail: detail,
      groupDetails: groupDetails,
      currentUserId: currentUserId,
      isGroupAdmin: isGroupAdmin,
    );
  }
}

enum _MovementFilter { all, expenses, payments }

enum _MovementAction { editExpense, deleteExpense, annulPayment }

class _MovementListItem {
  const _MovementListItem({required this.movement, this.isAnnulled = false});

  final AccountMovementModel movement;
  final bool isAnnulled;
}

class _MovementPaymentStatus {
  const _MovementPaymentStatus(this.label, this.color);

  final String label;
  final Color color;
}

bool _hasDirectSharePayment({
  required AccountMovementModel expense,
  required int memberId,
  required List<AccountMovementModel> movements,
}) => movements.any(
  (movement) =>
      movement.kind == 'PAYMENT' &&
      movement.expenseId == expense.id &&
      movement.expenseShareId != null &&
      movement.adjustmentId == null &&
      movement.fromMemberId == memberId &&
      movement.toMemberId == expense.payerMemberId,
);

_MovementPaymentStatus? _sharePaymentStatus({
  required AccountMovementModel expense,
  required AccountShareModel share,
  required List<AccountMovementModel> movements,
}) {
  if (!share.isCurrent) {
    return const _MovementPaymentStatus('No participa', AppColors.mutedText);
  }
  if (share.amountCents <= 0) return null;
  if (share.memberId == expense.payerMemberId) {
    return const _MovementPaymentStatus('Pagador', AppColors.primary);
  }
  if (_hasDirectSharePayment(
    expense: expense,
    memberId: share.memberId,
    movements: movements,
  )) {
    return const _MovementPaymentStatus('Pagada', AppColors.success);
  }

  final relatedAdjustments = movements.where(
    (movement) =>
        movement.kind == 'ADJUSTMENT' &&
        movement.expenseId == expense.id &&
        (movement.debtorMemberId == share.memberId ||
            movement.creditorMemberId == share.memberId),
  );
  final participantOwesPayer = relatedAdjustments.where(
    (movement) =>
        movement.debtorMemberId == share.memberId &&
        movement.creditorMemberId == expense.payerMemberId,
  );
  if (participantOwesPayer.any(
    (adjustment) => adjustment.status == 'PENDING',
  )) {
    return const _MovementPaymentStatus('Ajuste pendiente', AppColors.primary);
  }
  if (participantOwesPayer.any((adjustment) => adjustment.status == 'PAID')) {
    return const _MovementPaymentStatus('Ajuste pagado', AppColors.success);
  }
  if (relatedAdjustments.isNotEmpty) return null;

  return const _MovementPaymentStatus('Pendiente', AppColors.error);
}

_MovementPaymentStatus? _expensePaymentStatusForMember({
  required AccountMovementModel expense,
  required int memberId,
  required List<AccountMovementModel> movements,
}) {
  if (expense.payerMemberId == memberId) {
    final participants = expense.shares
        .where(
          (share) =>
              share.isCurrent &&
              share.amountCents > 0 &&
              share.memberId != expense.payerMemberId,
        )
        .toList(growable: false);
    if (participants.isEmpty ||
        movements.any(
          (movement) =>
              movement.kind == 'ADJUSTMENT' && movement.expenseId == expense.id,
        )) {
      return null;
    }
    final allPaid = participants.every(
      (share) => _hasDirectSharePayment(
        expense: expense,
        memberId: share.memberId,
        movements: movements,
      ),
    );
    return allPaid
        ? const _MovementPaymentStatus('Todos pagaron', AppColors.success)
        : const _MovementPaymentStatus('Cobros pendientes', AppColors.primary);
  }

  for (final share in expense.shares) {
    if (share.memberId == memberId) {
      return _sharePaymentStatus(
        expense: expense,
        share: share,
        movements: movements,
      );
    }
  }
  return null;
}

class _MovementsList extends StatelessWidget {
  const _MovementsList({
    required this.detail,
    required this.groupDetails,
    required this.isGroupAdmin,
    required this.currentUserId,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel groupDetails;
  final bool isGroupAdmin;
  final int? currentUserId;

  int get accountId => detail.id;
  int get memberId => detail.myMemberId;

  Map<int, String> get _memberNames => {
    for (final member in groupDetails.members) member.id: member.name,
  };

  String _memberName(int? memberId) => _memberNames[memberId] ?? 'Miembro';

  DateTime _movementDate(AccountMovementModel movement) =>
      movement.confirmedAt ?? movement.settledAt ?? movement.createdAt;

  AccountMovementModel _annulledMovement(ExpensePaymentResponseModel payment) {
    String? expenseTitle;
    for (final movement in detail.movements) {
      if (movement.kind == 'EXPENSE' && movement.id == payment.expenseId) {
        expenseTitle = movement.title;
        break;
      }
    }

    return AccountMovementModel(
      id: payment.id,
      kind: 'PAYMENT',
      amountCents: payment.amountCents,
      fromMemberId: payment.fromMemberId,
      toMemberId: payment.toMemberId,
      expenseId: payment.expenseId,
      expenseShareId: payment.expenseShareId,
      adjustmentId: payment.adjustmentId,
      expenseTitle: expenseTitle,
      status: 'ANNULLED',
      createdAt: payment.createdAt,
      confirmedAt: payment.confirmedAt,
    );
  }

  List<_MovementListItem> _movementItems(ExpenseAccountProvider provider) {
    final annulledPayments =
        provider.annulledExpensePaymentsByAccount[accountId] ??
        const <ExpensePaymentResponseModel>[];
    final annulledPaymentIds = annulledPayments
        .map((payment) => payment.id)
        .toSet();
    final createdExpense = provider.createdExpense;
    final updatedExpense = provider.updatedExpense;
    final items = <_MovementListItem>[
      for (final movement in detail.movements)
        if ((movement.kind != 'PAYMENT' ||
                !annulledPaymentIds.contains(movement.id)) &&
            _canViewMovement(
              movement,
              createdExpense: createdExpense,
              updatedExpense: updatedExpense,
            ))
          _MovementListItem(movement: movement),
      for (final payment in annulledPayments)
        if (payment.fromMemberId == memberId || payment.toMemberId == memberId)
          _MovementListItem(
            movement: _annulledMovement(payment),
            isAnnulled: true,
          ),
    ];
    items.sort((first, second) {
      final dateOrder = _movementDate(
        second.movement,
      ).compareTo(_movementDate(first.movement));
      return dateOrder != 0
          ? dateOrder
          : second.movement.id.compareTo(first.movement.id);
    });
    return items;
  }

  bool _canViewMovement(
    AccountMovementModel movement, {
    required ExpenseResponseModel? createdExpense,
    required ExpenseResponseModel? updatedExpense,
  }) {
    if (movement.kind == 'EXPENSE') {
      return memberMovementAmountCents(movement, memberId) != null ||
          isGroupAdmin ||
          (currentUserId != null &&
              accountMovementCreatorUserId(
                    movement: movement,
                    accountId: accountId,
                    createdExpense: createdExpense,
                    updatedExpense: updatedExpense,
                  ) ==
                  currentUserId);
    }
    return memberMovementAmountCents(movement, memberId) != null;
  }

  String _creatorSubtitle(
    AccountMovementModel movement, {
    required ExpenseAccountProvider provider,
    required List<AccountMovementModel> allMovements,
  }) => accountMovementCreatorSubtitle(
    movement: movement,
    accountId: accountId,
    allMovements: allMovements,
    groupMembers: groupDetails.members,
    currentUserId: currentUserId,
    createdExpense: provider.createdExpense,
    updatedExpense: provider.updatedExpense,
  );

  Future<void> _confirmAnnulPayment(
    BuildContext context,
    AccountMovementModel payment,
  ) async {
    if (payment.kind != 'PAYMENT' || payment.fromMemberId != memberId) {
      return;
    }
    final provider = context.read<ExpenseAccountProvider>();
    if (provider.isAnnullingExpensePayment) return;

    final confirmed = await showAppMessageDialog(
      context,
      title: 'Anular pago',
      message:
          'Importe: ${MoneyFormatter.formatCentsShort(payment.amountCents)}\n'
          'Destinatario: ${_memberName(payment.toMemberId)}\n\n'
          'La anulación volverá a afectar las obligaciones y los saldos '
          'pendientes. Esta acción no se puede deshacer.',
      confirmText: 'Anular pago',
      icon: Icons.undo_rounded,
      accentColor: AppColors.error,
      confirmButtonColor: AppColors.error,
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

    final confirmed = await showAppMessageDialog(
      context,
      title: 'Eliminar gasto',
      message:
          'Gasto: ${accountMovementTitle(expense)}\n'
          'Importe: ${MoneyFormatter.formatCentsShort(expense.amountCents)}\n\n'
          'La eliminación es definitiva y no se puede deshacer. Se '
          'actualizarán los saldos de los miembros afectados.',
      confirmText: 'Eliminar gasto',
      icon: Icons.delete_outline_rounded,
      accentColor: AppColors.error,
      confirmButtonColor: AppColors.error,
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

  bool _canManageExpense(
    AccountMovementModel movement,
    ExpenseAccountProvider provider,
  ) {
    return movement.kind == 'EXPENSE' &&
        (isGroupAdmin ||
            (currentUserId != null &&
                accountMovementCreatorUserId(
                      movement: movement,
                      accountId: accountId,
                      createdExpense: provider.createdExpense,
                      updatedExpense: provider.updatedExpense,
                    ) ==
                    currentUserId));
  }

  bool _hasConfirmedPayments(AccountMovementModel expense) =>
      detail.movements.any(
        (candidate) =>
            candidate.expenseId == expense.id &&
            ((candidate.kind == 'PAYMENT' &&
                    candidate.expenseShareId != null) ||
                (candidate.kind == 'ADJUSTMENT' && candidate.status == 'PAID')),
      );

  _MovementPaymentStatus? _statusForItem(_MovementListItem item) {
    final movement = item.movement;
    if (item.isAnnulled) {
      return const _MovementPaymentStatus('Anulado', AppColors.error);
    }
    if (movement.kind == 'EXPENSE') {
      return _expensePaymentStatusForMember(
        expense: movement,
        memberId: memberId,
        movements: detail.movements,
      );
    }
    if (movement.kind == 'ADJUSTMENT') {
      if (movement.status == 'PENDING') {
        return const _MovementPaymentStatus('Pendiente', AppColors.primary);
      }
      if (movement.status == 'PAID') {
        return const _MovementPaymentStatus('Pagado', AppColors.success);
      }
    }
    return null;
  }

  Widget? _movementActions(
    BuildContext context,
    _MovementListItem item,
    ExpenseAccountProvider provider,
  ) {
    final movement = item.movement;
    if (item.isAnnulled) return null;

    final canManageExpense = _canManageExpense(movement, provider);
    final canAnnulPayment =
        movement.kind == 'PAYMENT' && movement.fromMemberId == memberId;
    if (!canManageExpense && !canAnnulPayment) return null;

    final isBusy =
        provider.isDeletingExpense || provider.isAnnullingExpensePayment;
    final isCurrentMovementBusy =
        provider.deletingExpenseId == movement.id ||
        provider.annullingExpensePaymentId == movement.id;

    return PopupMenuButton<_MovementAction>(
      tooltip: 'Acciones del movimiento',
      padding: EdgeInsets.zero,
      enabled: !isBusy,
      icon: isCurrentMovementBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.more_vert, color: AppColors.mutedText),
      itemBuilder: (context) => [
        if (canManageExpense)
          const PopupMenuItem(
            height: 56,
            value: _MovementAction.editExpense,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('Editar gasto'),
            ),
          ),
        if (canManageExpense)
          const PopupMenuItem(
            height: 56,
            value: _MovementAction.deleteExpense,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                'Eliminar gasto',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        if (canAnnulPayment)
          const PopupMenuItem(
            height: 56,
            value: _MovementAction.annulPayment,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.block_outlined, color: AppColors.error),
              title: Text(
                'Anular pago',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
      ],
      onSelected: (action) {
        switch (action) {
          case _MovementAction.editExpense:
            Navigator.of(context).pushNamed(
              AppRoutes.createExpense,
              arguments: {
                'accountId': accountId,
                'expense': movement,
                'hasConfirmedPayments': _hasConfirmedPayments(movement),
              },
            );
            break;
          case _MovementAction.deleteExpense:
            _confirmDeleteExpense(context, movement);
            break;
          case _MovementAction.annulPayment:
            _confirmAnnulPayment(context, movement);
            break;
        }
      },
    );
  }

  Future<void> _showMovementDetails(
    BuildContext context,
    _MovementListItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _MovementDetailsSheet(
        item: item,
        allMovements: detail.movements,
        groupMembers: groupDetails.members,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final items = _movementItems(provider);

    return _FilteredMovementList(
      items: items,
      itemBuilder: (context, item) {
        final movement = item.movement;
        final status = _statusForItem(item);
        final creatorSubtitle = _creatorSubtitle(
          movement,
          provider: provider,
          allMovements: detail.movements,
        );
        return AccountMovementCard(
          icon: movement.kind == 'EXPENSE'
              ? Icons.receipt_long_outlined
              : movement.kind == 'ADJUSTMENT'
              ? Icons.compare_arrows_rounded
              : Icons.payments_outlined,
          accentColor: item.isAnnulled
              ? AppColors.error
              : movement.kind == 'PAYMENT'
              ? AppColors.success
              : AppColors.primary,
          title: accountMovementTitle(movement),
          subtitle: creatorSubtitle,
          amountCents: movement.amountCents,
          createdAt: _movementDate(movement),
          statusLabel: status?.label,
          statusColor: status?.color ?? AppColors.primary,
          isAnnulled: item.isAnnulled,
          onTap: () => _showMovementDetails(context, item),
          trailing: _movementActions(context, item, provider),
        );
      },
    );
  }
}

class _FilteredMovementList extends StatefulWidget {
  const _FilteredMovementList({required this.items, required this.itemBuilder});

  final List<_MovementListItem> items;
  final Widget Function(BuildContext context, _MovementListItem item)
  itemBuilder;

  @override
  State<_FilteredMovementList> createState() => _FilteredMovementListState();
}

class _FilteredMovementListState extends State<_FilteredMovementList> {
  _MovementFilter _selectedFilter = _MovementFilter.all;

  String get _emptyMessage => switch (_selectedFilter) {
    _MovementFilter.all => 'Todavía no hay movimientos en esta cuenta.',
    _MovementFilter.expenses => 'Todavía no hay gastos en esta cuenta.',
    _MovementFilter.payments => 'Todavía no hay pagos en esta cuenta.',
  };

  List<_MovementListItem> get _filteredItems {
    return widget.items
        .where((item) {
          switch (_selectedFilter) {
            case _MovementFilter.all:
              return true;
            case _MovementFilter.expenses:
              return item.movement.kind == 'EXPENSE';
            case _MovementFilter.payments:
              return item.movement.kind != 'EXPENSE';
          }
        })
        .toList(growable: false);
  }

  String _filterLabel(_MovementFilter filter) => switch (filter) {
    _MovementFilter.all => 'Todos',
    _MovementFilter.expenses => 'Gastos',
    _MovementFilter.payments => 'Pagos',
  };

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final filter in _MovementFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _selectedFilter == filter,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.fieldColor,
                    side: BorderSide(
                      color: _selectedFilter == filter
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: _selectedFilter == filter
                          ? AppColors.onPrimary
                          : AppColors.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) =>
                      widget.itemBuilder(context, filteredItems[index]),
                ),
        ),
      ],
    );
  }
}

class _MovementDetailsSheet extends StatelessWidget {
  const _MovementDetailsSheet({
    required this.item,
    required this.allMovements,
    required this.groupMembers,
  });

  final _MovementListItem item;
  final List<AccountMovementModel> allMovements;
  final List<GetMemberResponseModel> groupMembers;

  AccountMovementModel get movement => item.movement;

  String _memberName(int? memberId) {
    for (final member in groupMembers) {
      if (member.id == memberId) return member.name;
    }
    return memberId == null ? 'Integrante' : 'Integrante $memberId';
  }

  DateTime get _movementDate =>
      movement.confirmedAt ?? movement.settledAt ?? movement.createdAt;

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _MovementPaymentStatus? _statusForShare(AccountShareModel share) =>
      _sharePaymentStatus(
        expense: movement,
        share: share,
        movements: allMovements,
      );

  List<AccountMovementModel> get _expenseAdjustments => allMovements
      .where(
        (candidate) =>
            candidate.kind == 'ADJUSTMENT' &&
            candidate.expenseId == movement.id,
      )
      .toList(growable: false);

  Widget _participantRow(AccountShareModel share) {
    final status = _statusForShare(share);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _memberName(share.memberId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyFormatter.formatCentsShort(share.amountCents),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: 4),
                AccountPaymentStatusBadge(
                  label: status.label,
                  color: status.color,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _adjustmentRow(AccountMovementModel adjustment) {
    final status = switch (adjustment.status) {
      'PENDING' => const _MovementPaymentStatus('Pendiente', AppColors.primary),
      'PAID' => const _MovementPaymentStatus('Pagado', AppColors.success),
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_memberName(adjustment.debtorMemberId)} → '
                  '${_memberName(adjustment.creditorMemberId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
                ),
                if (status != null) ...[
                  const SizedBox(height: 4),
                  AccountPaymentStatusBadge(
                    label: status.label,
                    color: status.color,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            MoneyFormatter.formatCentsShort(adjustment.amountCents),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _movementDetails() {
    if (movement.kind == 'EXPENSE') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Gasto'),
          _infoRow('Pagador', _memberName(movement.payerMemberId)),
          _sectionTitle('Participantes'),
          for (final share in movement.shares) _participantRow(share),
          if (_expenseAdjustments.isNotEmpty) ...[
            _sectionTitle('Ajustes económicos'),
            for (final adjustment in _expenseAdjustments)
              _adjustmentRow(adjustment),
          ],
        ],
      );
    }

    if (movement.kind == 'ADJUSTMENT') {
      final status = movement.status == 'PENDING'
          ? 'Pendiente'
          : movement.status == 'PAID'
          ? 'Pagado'
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Ajuste económico'),
          _infoRow('Debe', _memberName(movement.debtorMemberId)),
          _infoRow('Recibe', _memberName(movement.creditorMemberId)),
          if (status != null) _infoRow('Estado', status),
        ],
      );
    }

    final status = item.isAnnulled
        ? 'Anulado'
        : movement.confirmedAt == null
        ? null
        : 'Confirmado';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Pago'),
        _infoRow('Desde', _memberName(movement.fromMemberId)),
        _infoRow('Hacia', _memberName(movement.toMemberId)),
        if (status != null) _infoRow('Estado', status),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                accountMovementTitle(movement),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                MoneyFormatter.formatCentsShort(movement.amountCents),
                style: TextStyle(
                  color: item.isAnnulled ? AppColors.error : AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: item.isAnnulled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                EventDateFormatter.dayMonthYear(_movementDate),
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
              _movementDetails(),
            ],
          ),
        ),
      ),
    );
  }
}
