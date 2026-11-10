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
import '../widgets/account_new_movement_sheet.dart';
import '../widgets/account_payment_status_badge.dart';
import '../widgets/account_separated_list.dart';
import '../widgets/movement_date_header.dart';
import '../widgets/movement_list_item.dart';

class ExpenseAccountMovementsScreen extends StatefulWidget {
  const ExpenseAccountMovementsScreen({super.key, required this.accountId});

  final int accountId;

  @override
  State<ExpenseAccountMovementsScreen> createState() =>
      _ExpenseAccountMovementsScreenState();
}

class _ExpenseAccountMovementsScreenState
    extends State<ExpenseAccountMovementsScreen> {
  late final ScrollController _scrollController;
  bool _isFabExtended = true;
  double _previousScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final difference = currentOffset - _previousScrollOffset;
    if (difference > 0 && _isFabExtended) {
      setState(() => _isFabExtended = false);
    } else if (difference < 0 && !_isFabExtended) {
      setState(() => _isFabExtended = true);
    }
    _previousScrollOffset = currentOffset;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PrimaryScrollController(
        controller: _scrollController,
        child: SafeArea(child: _MovementsContent(accountId: widget.accountId)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        isExtended: _isFabExtended,
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
          arguments: {'accountId': widget.accountId},
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
          arguments: {'accountId': widget.accountId, 'groupId': groupId},
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

class _MovementDateGroup {
  _MovementDateGroup(this.date);

  final DateTime date;
  final List<_MovementListItem> items = [];
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

  GetMemberResponseModel? _movementAuthor(
    AccountMovementModel movement,
    ExpenseAccountProvider provider,
  ) {
    var creatorUserId = movement.kind == 'ADJUSTMENT'
        ? movement.createdByUserId
        : accountMovementCreatorUserId(
            movement: movement,
            accountId: accountId,
            createdExpense: provider.createdExpense,
            updatedExpense: provider.updatedExpense,
          );

    if (creatorUserId == null &&
        movement.kind == 'PAYMENT' &&
        movement.fromMemberId != null) {
      for (final member in groupDetails.members) {
        if (member.id == movement.fromMemberId) {
          creatorUserId = member.idUser;
          break;
        }
      }
    }

    var viewerUserId = currentUserId;
    if (viewerUserId == null) {
      for (final member in groupDetails.members) {
        if (member.id == memberId) {
          viewerUserId = member.idUser;
          break;
        }
      }
    }

    if (creatorUserId == null || creatorUserId == viewerUserId) return null;
    for (final member in groupDetails.members) {
      if (member.idUser == creatorUserId) return member;
    }
    return null;
  }

  String _movementTypeLabel(AccountMovementModel movement) {
    if (movement.kind == 'ADJUSTMENT') return 'Ajuste económico';
    if (movement.kind == 'PAYMENT') {
      return movement.adjustmentId == null ? 'Pago' : 'Pago de ajuste';
    }
    return 'Gasto';
  }

  String _movementTitle(AccountMovementModel movement) {
    final title = movement.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final expenseTitle = movement.expenseTitle?.trim();
    if (expenseTitle != null && expenseTitle.isNotEmpty) return expenseTitle;
    return _movementTypeLabel(movement);
  }

  bool _isPending(_MovementListItem item) {
    if (item.isAnnulled) return false;
    final movement = item.movement;

    if (movement.kind == 'ADJUSTMENT') return movement.status == 'PENDING';
    if (movement.kind != 'EXPENSE') return false;

    if (detail.movements.any(
      (candidate) =>
          candidate.kind == 'ADJUSTMENT' &&
          candidate.expenseId == movement.id &&
          candidate.status == 'PENDING',
    )) {
      return true;
    }

    final status = _statusForItem(item)?.label;
    return status == 'Pendiente' ||
        status == 'Cobros pendientes' ||
        status == 'Ajuste pendiente';
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
      color: AppColors.cardColor,
      surfaceTintColor: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
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
              leading: Icon(Icons.edit_outlined, color: AppColors.text),
              title: Text('Editar'),
            ),
          ),
        if (canManageExpense)
          const PopupMenuItem(
            height: 56,
            value: _MovementAction.deleteExpense,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text('Eliminar', style: TextStyle(color: AppColors.error)),
            ),
          ),
        if (canAnnulPayment)
          const PopupMenuItem(
            height: 56,
            value: _MovementAction.annulPayment,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.block_outlined, color: AppColors.error),
              title: Text('Anular', style: TextStyle(color: AppColors.error)),
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
        final author = _movementAuthor(movement, provider);
        final isAdjustment =
            movement.kind == 'ADJUSTMENT' ||
            (movement.kind == 'PAYMENT' && movement.adjustmentId != null);
        return MovementListItem(
          icon: movement.kind == 'EXPENSE'
              ? Icons.receipt_long_outlined
              : movement.kind == 'ADJUSTMENT'
              ? Icons.compare_arrows_rounded
              : Icons.payments_outlined,
          title: _movementTitle(movement),
          typeLabel: _movementTypeLabel(movement),
          amountCents: movement.amountCents,
          authorName: author?.name,
          authorPhotoUrl: author?.profilePhoto,
          isPayment: movement.kind == 'PAYMENT',
          isAdjustment: isAdjustment,
          isAnnulled: item.isAnnulled,
          isPending: _isPending(item),
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
              return item.movement.kind == 'EXPENSE' ||
                  item.movement.kind == 'ADJUSTMENT';
            case _MovementFilter.payments:
              return item.movement.kind == 'PAYMENT';
          }
        })
        .toList(growable: false);
  }

  String _filterLabel(_MovementFilter filter) => switch (filter) {
    _MovementFilter.all => 'Todos',
    _MovementFilter.expenses => 'Gastos',
    _MovementFilter.payments => 'Pagos',
  };

  List<_MovementDateGroup> _groupByDate(List<_MovementListItem> items) {
    final groups = <_MovementDateGroup>[];
    for (final item in items) {
      final movement = item.movement;
      final date =
          movement.confirmedAt ?? movement.settledAt ?? movement.createdAt;
      if (groups.isEmpty ||
          !EventDateFormatter.isSameLocalDay(groups.last.date, date)) {
        groups.add(_MovementDateGroup(date));
      }
      groups.last.items.add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final dateGroups = _groupByDate(filteredItems);

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
              : ListView(
                  primary: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 128),
                  children: [
                    for (final group in dateGroups) ...[
                      MovementDateHeader(date: group.date),
                      AccountSeparatedList(
                        itemCount: group.items.length,
                        itemBuilder: (context, index) =>
                            widget.itemBuilder(context, group.items[index]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SharePaymentSummary {
  const _SharePaymentSummary({
    required this.paidCents,
    required this.outstandingCents,
    required this.pendingPaymentCents,
    required this.pendingRefundCents,
    required this.paidAdjustmentCents,
    required this.hasAdjustment,
  });

  final int paidCents;
  final int outstandingCents;
  final int pendingPaymentCents;
  final int pendingRefundCents;
  final int paidAdjustmentCents;
  final bool hasAdjustment;
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

  String get _movementTypeLabel => switch (movement.kind) {
    'EXPENSE' => 'Gasto',
    'ADJUSTMENT' => 'Ajuste económico',
    _ => 'Pago',
  };

  IconData get _movementIcon => switch (movement.kind) {
    'EXPENSE' => Icons.receipt_long_outlined,
    'ADJUSTMENT' => Icons.compare_arrows_rounded,
    _ => Icons.payments_outlined,
  };

  Color get _movementAccentColor {
    if (item.isAnnulled || movement.status == 'CANCELED') {
      return AppColors.error;
    }
    if (movement.kind == 'PAYMENT' || movement.status == 'PAID') {
      return AppColors.success;
    }
    return AppColors.primary;
  }

  String? get _movementStatusLabel {
    if (item.isAnnulled || movement.status == 'CANCELED') return 'Anulado';
    if (movement.kind == 'ADJUSTMENT') {
      return switch (movement.status) {
        'PENDING' => 'Pendiente',
        'PAID' => 'Pagado',
        _ => null,
      };
    }
    if (movement.kind == 'PAYMENT' && movement.confirmedAt != null) {
      return 'Confirmado';
    }
    return null;
  }

  Widget _detailsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 6),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _summaryAmountRow(String label, int cents, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            MoneyFormatter.formatCentsShort(cents),
            style: TextStyle(
              color: color ?? AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

  _SharePaymentSummary _sharePaymentSummary(AccountShareModel share) {
    final payerMemberId = movement.payerMemberId;
    final relatedAdjustments = _expenseAdjustments
        .where(
          (adjustment) =>
              adjustment.debtorMemberId == share.memberId ||
              adjustment.creditorMemberId == share.memberId,
        )
        .toList(growable: false);
    final directPaymentsCents = allMovements
        .where(
          (candidate) =>
              candidate.kind == 'PAYMENT' &&
              candidate.expenseId == movement.id &&
              candidate.expenseShareId != null &&
              candidate.adjustmentId == null &&
              candidate.fromMemberId == share.memberId &&
              candidate.toMemberId == payerMemberId,
        )
        .fold<int>(0, (total, payment) => total + payment.amountCents);
    final paidByMemberCents = relatedAdjustments
        .where(
          (adjustment) =>
              adjustment.status == 'PAID' &&
              adjustment.debtorMemberId == share.memberId,
        )
        .fold<int>(0, (total, adjustment) => total + adjustment.amountCents);
    final refundedToMemberCents = relatedAdjustments
        .where(
          (adjustment) =>
              adjustment.status == 'PAID' &&
              adjustment.creditorMemberId == share.memberId,
        )
        .fold<int>(0, (total, adjustment) => total + adjustment.amountCents);
    final netPaidCents =
        directPaymentsCents + paidByMemberCents - refundedToMemberCents;
    final currentOwedCents = share.isCurrent && share.memberId != payerMemberId
        ? share.amountCents
        : 0;
    final pendingAdjustments = relatedAdjustments.where(
      (adjustment) => adjustment.status == 'PENDING',
    );
    final pendingPaymentCents = pendingAdjustments
        .where((adjustment) => adjustment.debtorMemberId == share.memberId)
        .fold<int>(0, (total, adjustment) => total + adjustment.amountCents);
    final pendingRefundCents = pendingAdjustments
        .where((adjustment) => adjustment.creditorMemberId == share.memberId)
        .fold<int>(0, (total, adjustment) => total + adjustment.amountCents);
    final paidAdjustmentCents = relatedAdjustments
        .where((adjustment) => adjustment.status == 'PAID')
        .fold<int>(0, (total, adjustment) => total + adjustment.amountCents);

    return _SharePaymentSummary(
      paidCents: netPaidCents,
      outstandingCents: currentOwedCents - netPaidCents,
      pendingPaymentCents: pendingPaymentCents,
      pendingRefundCents: pendingRefundCents,
      paidAdjustmentCents: paidAdjustmentCents,
      hasAdjustment: relatedAdjustments.any(
        (adjustment) =>
            adjustment.status == 'PENDING' || adjustment.status == 'PAID',
      ),
    );
  }

  AccountMovementModel? get _relatedAdjustment {
    final adjustmentId = movement.kind == 'ADJUSTMENT'
        ? movement.id
        : movement.adjustmentId;
    if (adjustmentId == null) return null;

    for (final candidate in allMovements) {
      if (candidate.kind == 'ADJUSTMENT' && candidate.id == adjustmentId) {
        return candidate;
      }
    }
    return null;
  }

  AccountMovementModel? get _relatedAdjustmentPayment {
    if (movement.kind != 'ADJUSTMENT') return null;
    for (final candidate in allMovements) {
      if (candidate.kind == 'PAYMENT' &&
          candidate.adjustmentId == movement.id) {
        return candidate;
      }
    }
    return null;
  }

  Widget _participantRow(AccountShareModel share) {
    final summary = _sharePaymentSummary(share);
    final status = summary.pendingPaymentCents > 0
        ? const _MovementPaymentStatus('Ajuste pendiente', AppColors.primary)
        : summary.pendingRefundCents > 0
        ? const _MovementPaymentStatus('Ajuste a favor', AppColors.primary)
        : _statusForShare(share);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _memberName(share.memberId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
          if (summary.hasAdjustment) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _summaryAmountRow(
                    share.isCurrent ? 'Parte actual' : 'Parte registrada',
                    share.amountCents,
                  ),
                  _summaryAmountRow(
                    'Pagado',
                    summary.paidCents,
                    color: AppColors.success,
                  ),
                  if (summary.pendingPaymentCents > 0)
                    _summaryAmountRow(
                      'Ajuste pendiente · falta pagar',
                      summary.pendingPaymentCents,
                      color: AppColors.primary,
                    )
                  else if (summary.pendingRefundCents > 0)
                    _summaryAmountRow(
                      'Ajuste pendiente · falta recibir',
                      summary.pendingRefundCents,
                      color: AppColors.primary,
                    )
                  else if (summary.paidAdjustmentCents > 0)
                    _summaryAmountRow(
                      'Ajuste pagado',
                      summary.paidAdjustmentCents,
                      color: AppColors.success,
                    ),
                  if (summary.pendingPaymentCents == 0 &&
                      summary.pendingRefundCents == 0)
                    _summaryAmountRow(
                      summary.outstandingCents < 0
                          ? 'Falta recibir'
                          : 'Falta pagar',
                      summary.outstandingCents.abs(),
                      color: summary.outstandingCents == 0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _adjustmentRow(AccountMovementModel adjustment) {
    final status = switch (adjustment.status) {
      'PENDING' => const _MovementPaymentStatus('Pendiente', AppColors.primary),
      'PAID' => const _MovementPaymentStatus('Pagado', AppColors.success),
      'CANCELED' => const _MovementPaymentStatus('Anulado', AppColors.error),
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
          _detailsSection(
            title: 'Datos del gasto',
            icon: Icons.receipt_long_outlined,
            children: [
              _infoRow('Pagador', _memberName(movement.payerMemberId)),
            ],
          ),
          _detailsSection(
            title: 'Participantes y pagos',
            icon: Icons.groups_outlined,
            children: [
              for (var index = 0; index < movement.shares.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, color: AppColors.border),
                _participantRow(movement.shares[index]),
              ],
            ],
          ),
          if (_expenseAdjustments.isNotEmpty)
            _detailsSection(
              title: 'Historial de ajustes',
              icon: Icons.compare_arrows_rounded,
              children: [
                for (final adjustment in _expenseAdjustments)
                  _adjustmentRow(adjustment),
              ],
            ),
        ],
      );
    }

    if (movement.kind == 'ADJUSTMENT') {
      final relatedPayment = _relatedAdjustmentPayment;
      final statusLabel = switch (movement.status) {
        'PENDING' => 'Pendiente',
        'PAID' => 'Pagado',
        'CANCELED' => 'Anulado',
        _ => 'Sin estado',
      };
      final paidCents = movement.status == 'PAID'
          ? relatedPayment?.amountCents ?? movement.amountCents
          : 0;
      final outstandingCents = movement.status == 'PENDING'
          ? movement.amountCents
          : 0;

      return _detailsSection(
        title: 'Detalle del ajuste',
        icon: Icons.compare_arrows_rounded,
        children: [
          if (movement.expenseTitle != null)
            _infoRow('Gasto asociado', movement.expenseTitle!),
          _infoRow('Paga', _memberName(movement.debtorMemberId)),
          _infoRow('Recibe', _memberName(movement.creditorMemberId)),
          _infoRow(
            'Importe del ajuste',
            MoneyFormatter.formatCentsShort(movement.amountCents),
          ),
          _infoRow('Pagado', MoneyFormatter.formatCentsShort(paidCents)),
          _infoRow(
            'Falta pagar',
            MoneyFormatter.formatCentsShort(outstandingCents),
          ),
          _infoRow('Estado', statusLabel),
        ],
      );
    }

    final relatedAdjustment = _relatedAdjustment;
    final outstandingAdjustmentCents =
        item.isAnnulled && relatedAdjustment?.status == 'PENDING'
        ? relatedAdjustment!.amountCents
        : 0;
    final statusLabel = item.isAnnulled
        ? 'Anulado'
        : movement.confirmedAt == null
        ? 'Pendiente'
        : 'Confirmado';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _detailsSection(
          title: 'Datos del pago',
          icon: Icons.payments_outlined,
          children: [
            _infoRow('Desde', _memberName(movement.fromMemberId)),
            _infoRow('Hacia', _memberName(movement.toMemberId)),
            _infoRow('Estado', statusLabel),
          ],
        ),
        if (movement.adjustmentId != null)
          _detailsSection(
            title: 'Ajuste relacionado',
            icon: Icons.compare_arrows_rounded,
            children: [
              _infoRow(
                'Importe del ajuste',
                MoneyFormatter.formatCentsShort(
                  relatedAdjustment?.amountCents ?? movement.amountCents,
                ),
              ),
              _infoRow(
                'Pagado',
                MoneyFormatter.formatCentsShort(
                  item.isAnnulled ? 0 : movement.amountCents,
                ),
              ),
              _infoRow(
                'Falta pagar',
                MoneyFormatter.formatCentsShort(outstandingAdjustmentCents),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _movementAccentColor;
    final statusLabel = _movementStatusLabel;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            const SizedBox(height: 12),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _movementIcon,
                            color: accentColor,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _movementTypeLabel.toUpperCase(),
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                accountMovementTitle(movement),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar detalle',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.fieldColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Importe',
                                      style: TextStyle(
                                        color: AppColors.mutedText,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      MoneyFormatter.formatCentsShort(
                                        movement.amountCents,
                                      ),
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        decoration: item.isAnnulled
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (statusLabel != null)
                                AccountPaymentStatusBadge(
                                  label: statusLabel,
                                  color: accentColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: AppColors.mutedText,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${EventDateFormatter.dayMonthYear(_movementDate)} · '
                                '${EventDateFormatter.time(_movementDate)}',
                                style: const TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _movementDetails(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
