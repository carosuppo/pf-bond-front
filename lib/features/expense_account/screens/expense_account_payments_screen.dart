import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../group/models/get_group_model.response.dart';
import '../formatters/money_formatter.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/pending_expense_adjustment_model.response.dart';
import '../models/pending_expense_share_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_header_card.dart';
import '../widgets/account_group_details_loader.dart';

class ExpenseAccountPaymentsScreen extends StatefulWidget {
  const ExpenseAccountPaymentsScreen({
    super.key,
    required this.accountId,
    required this.groupId,
  });

  final int accountId;
  final int groupId;

  @override
  State<ExpenseAccountPaymentsScreen> createState() =>
      _ExpenseAccountPaymentsScreenState();
}

class _ExpenseAccountPaymentsScreenState
    extends State<ExpenseAccountPaymentsScreen> {
  late final ExpenseAccountProvider _provider;
  final Set<int> _selectedExpenseShareIds = {};
  final Set<int> _selectedAdjustmentIds = {};

  @override
  void initState() {
    super.initState();
    _provider = context.read<ExpenseAccountProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final detailRequest = _provider.accountDetail?.id == widget.accountId
          ? Future<void>.value()
          : _provider.loadAccountDetail(
              accountId: widget.accountId,
              force: true,
            );
      Future.wait<void>([
        _provider.loadPendingExpenseShares(
          accountId: widget.accountId,
          force: true,
        ),
        _provider.loadPendingExpenseAdjustments(
          accountId: widget.accountId,
          force: true,
        ),
        detailRequest,
      ]);
    });
  }

  Future<void> _reloadPendingShares() async {
    await Future.wait([
      _provider.loadPendingExpenseShares(
        accountId: widget.accountId,
        force: true,
      ),
      _provider.loadPendingExpenseAdjustments(
        accountId: widget.accountId,
        force: true,
      ),
    ]);
    if (!mounted) return;

    final availableIds = _provider.pendingExpenseShares
        .map((share) => share.expenseShareId)
        .toSet();
    final availableAdjustmentIds = _provider.pendingExpenseAdjustments
        .map((adjustment) => adjustment.adjustmentId)
        .toSet();
    setState(() {
      _selectedExpenseShareIds.removeWhere((id) => !availableIds.contains(id));
      _selectedAdjustmentIds.removeWhere(
        (id) => !availableAdjustmentIds.contains(id),
      );
    });
  }

  bool _isSelected(PendingExpenseShareResponseModel share) =>
      _selectedExpenseShareIds.contains(share.expenseShareId);

  bool _isAdjustmentSelected(
    PendingExpenseAdjustmentResponseModel adjustment,
  ) => _selectedAdjustmentIds.contains(adjustment.adjustmentId);

  bool _areAllSelected(
    List<PendingExpenseShareResponseModel> shares,
    List<PendingExpenseAdjustmentResponseModel> adjustments,
  ) => shares.isNotEmpty || adjustments.isNotEmpty
      ? shares.every(_isSelected) && adjustments.every(_isAdjustmentSelected)
      : false;

  List<PendingExpenseShareResponseModel> _selectedShares(
    List<PendingExpenseShareResponseModel> shares,
  ) => shares.where(_isSelected).toList(growable: false);

  int _selectedTotal(
    List<PendingExpenseShareResponseModel> shares,
    List<PendingExpenseAdjustmentResponseModel> adjustments,
  ) =>
      _selectedShares(
        shares,
      ).fold(0, (total, share) => total + share.amountCents) +
      adjustments
          .where(_isAdjustmentSelected)
          .fold(0, (total, adjustment) => total + adjustment.amountCents);

  void _toggleAll(
    List<PendingExpenseShareResponseModel> shares,
    List<PendingExpenseAdjustmentResponseModel> adjustments,
  ) {
    if (_areAllSelected(shares, adjustments)) {
      setState(() {
        _selectedExpenseShareIds.clear();
        _selectedAdjustmentIds.clear();
      });
      return;
    }

    setState(() {
      _selectedExpenseShareIds
        ..clear()
        ..addAll(shares.map((share) => share.expenseShareId));
      _selectedAdjustmentIds
        ..clear()
        ..addAll(adjustments.map((adjustment) => adjustment.adjustmentId));
    });
  }

  Future<void> _confirmSelectedPayments(
    List<PendingExpenseShareResponseModel> pendingShares,
    List<PendingExpenseAdjustmentResponseModel> pendingAdjustments,
  ) async {
    final selectedShares = _selectedShares(pendingShares);
    final selectedAdjustments = pendingAdjustments
        .where(_isAdjustmentSelected)
        .toList(growable: false);
    if ((selectedShares.isEmpty && selectedAdjustments.isEmpty) ||
        _provider.isRegisteringExpensePayments) {
      return;
    }

    final selectedCount = selectedShares.length + selectedAdjustments.length;
    final selectedTotal = _selectedTotal(pendingShares, pendingAdjustments);
    final registerAll =
        selectedCount == pendingShares.length + pendingAdjustments.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar registro'),
        content: Text(
          'Vas a registrar $selectedCount '
          '${selectedCount == 1 ? 'pago o ajuste' : 'pagos y ajustes'} por '
          '${MoneyFormatter.formatCentsShort(selectedTotal)}. '
          'Se saldarán los importes seleccionados completos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final succeeded = await _provider.registerExpensePayments(
      accountId: widget.accountId,
      expenseShareIds: selectedShares
          .map((share) => share.expenseShareId)
          .toList(growable: false),
      adjustmentIds: selectedAdjustments
          .map((adjustment) => adjustment.adjustmentId)
          .toList(growable: false),
      registerAll: registerAll,
    );
    if (!mounted) return;

    if (!succeeded) {
      final message =
          _provider.paymentRegistrationErrorMessage ??
          'No se pudieron registrar los pagos.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final payments = _provider.registeredExpensePayments;
    final registeredTotal = payments.fold(
      0,
      (total, payment) => total + payment.amountCents,
    );
    final message = payments.isEmpty
        ? 'No había participaciones pendientes para registrar.'
        : 'Se registraron ${payments.length} '
              '${payments.length == 1 ? 'pago o ajuste' : 'pagos y ajustes'} por '
              '${MoneyFormatter.formatCentsShort(registeredTotal)}.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop(true);
  }

  String _memberName(GetGroupResponseModel? groupDetails, int memberId) {
    for (final member in groupDetails?.members ?? const []) {
      if (member.id == memberId) {
        return member.name;
      }
    }
    return 'Miembro $memberId';
  }

  Widget _buildBody(
    ExpenseAccountProvider provider,
    GetGroupResponseModel? groupDetails,
  ) {
    final shares = provider.pendingExpenseShares;
    final adjustments = provider.pendingExpenseAdjustments;
    final isLoading =
        provider.isPendingExpenseSharesLoading ||
        provider.isPendingExpenseAdjustmentsLoading;
    final hasError =
        provider.pendingExpenseSharesErrorMessage != null ||
        provider.pendingExpenseAdjustmentsErrorMessage != null;

    if (isLoading && shares.isEmpty && adjustments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (hasError && shares.isEmpty && adjustments.isEmpty) {
      return _LoadError(
        message:
            provider.pendingExpenseSharesErrorMessage ??
            provider.pendingExpenseAdjustmentsErrorMessage!,
        onRetry: _reloadPendingShares,
      );
    }

    if (shares.isEmpty && adjustments.isEmpty) {
      return const _EmptyPendingShares();
    }

    final payerByExpense = {
      for (final movement
          in provider.accountDetail?.movements ??
              const <AccountMovementModel>[])
        if (movement.kind == 'EXPENSE') movement.id: movement.payerMemberId!,
    };

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _reloadPendingShares,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          if (provider.accountDetail != null) ...[
            AccountHeaderCard(
              name: provider.accountDetail!.name,
              groupName: provider.accountDetail!.groupName,
              eventName: provider.accountDetail!.eventName,
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            'Seleccioná participaciones y ajustes para registrar los importes completos.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
          if (hasError) ...[
            const SizedBox(height: 12),
            _InlineError(
              message:
                  provider.pendingExpenseSharesErrorMessage ??
                  provider.pendingExpenseAdjustmentsErrorMessage!,
            ),
          ],
          const SizedBox(height: 12),
          _SelectAllTile(
            selected: _areAllSelected(shares, adjustments),
            enabled: !provider.isRegisteringExpensePayments && !isLoading,
            onTap: () => _toggleAll(shares, adjustments),
          ),
          const SizedBox(height: 8),
          for (final share in shares)
            _PendingShareTile(
              share: share,
              recipientName: _memberName(groupDetails, share.payerMemberId),
              selected: _isSelected(share),
              enabled: !provider.isRegisteringExpensePayments && !isLoading,
              onTap: () {
                setState(() {
                  if (!_selectedExpenseShareIds.add(share.expenseShareId)) {
                    _selectedExpenseShareIds.remove(share.expenseShareId);
                  }
                });
              },
            ),
          for (final adjustment in adjustments)
            _PendingAdjustmentTile(
              adjustment: adjustment,
              typeLabel:
                  adjustment.debtorMemberId ==
                      payerByExpense[adjustment.expenseId]
                  ? 'Devolución'
                  : 'Importe adicional',
              debtorName: _memberName(groupDetails, adjustment.debtorMemberId),
              creditorName: _memberName(
                groupDetails,
                adjustment.creditorMemberId,
              ),
              selected: _isAdjustmentSelected(adjustment),
              enabled: !provider.isRegisteringExpensePayments && !isLoading,
              onTap: () {
                setState(() {
                  if (!_selectedAdjustmentIds.add(adjustment.adjustmentId)) {
                    _selectedAdjustmentIds.remove(adjustment.adjustmentId);
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    ExpenseAccountProvider provider,
    List<PendingExpenseShareResponseModel> shares,
    List<PendingExpenseAdjustmentResponseModel> adjustments,
  ) {
    final selected = _selectedShares(shares);
    final selectedAdjustmentCount = adjustments
        .where(_isAdjustmentSelected)
        .length;
    final selectedCount = selected.length + selectedAdjustmentCount;
    final totalCents = _selectedTotal(shares, adjustments);
    final areAllSelected = _areAllSelected(shares, adjustments);
    final buttonText = areAllSelected
        ? 'Registrar todos los pagos y ajustes'
        : selectedCount == 1
        ? 'Registrar pago o ajuste'
        : 'Registrar $selectedCount pagos y ajustes';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardColor,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.paymentRegistrationErrorMessage != null) ...[
              _InlineError(message: provider.paymentRegistrationErrorMessage!),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$selectedCount '
                    '${selectedCount == 1 ? 'seleccionado' : 'seleccionados'}',
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  MoneyFormatter.formatCentsShort(totalCents),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              text: buttonText,
              onPressed:
                  selectedCount == 0 ||
                      provider.isPendingExpenseSharesLoading ||
                      provider.isPendingExpenseAdjustmentsLoading
                  ? null
                  : () => _confirmSelectedPayments(shares, adjustments),
              loading: provider.isRegisteringExpensePayments,
              leading: const Icon(Icons.check_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final shares = provider.pendingExpenseShares;
    final adjustments = provider.pendingExpenseAdjustments;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Registrar pagos',
              onBack: provider.isRegisteringExpensePayments
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: AccountGroupDetailsLoader(
                groupId: widget.groupId,
                builder: (context, groupDetails, isLoading, error) =>
                    _buildBody(provider, groupDetails),
              ),
            ),
            if (shares.isNotEmpty || adjustments.isNotEmpty)
              _buildSummary(provider, shares, adjustments),
          ],
        ),
      ),
    );
  }
}

class _SelectAllTile extends StatelessWidget {
  const _SelectAllTile({
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
                activeColor: AppColors.primary,
              ),
              const Expanded(
                child: Text(
                  'Seleccionar todos',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingShareTile extends StatelessWidget {
  const _PendingShareTile({
    required this.share,
    required this.recipientName,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PendingExpenseShareResponseModel share;
  final String recipientName;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = share.expenseTitle?.trim();
    final expenseName = title == null || title.isEmpty
        ? 'Gasto #${share.expenseId}'
        : title;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expenseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pagar a $recipientName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                MoneyFormatter.formatCentsShort(share.amountCents),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingAdjustmentTile extends StatelessWidget {
  const _PendingAdjustmentTile({
    required this.adjustment,
    required this.typeLabel,
    required this.debtorName,
    required this.creditorName,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PendingExpenseAdjustmentResponseModel adjustment;
  final String typeLabel;
  final String debtorName;
  final String creditorName;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = adjustment.expenseTitle?.trim();
    final expenseName = title == null || title.isEmpty
        ? 'Gasto #${adjustment.expenseId}'
        : title;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expenseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$typeLabel · $debtorName paga a $creditorName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                MoneyFormatter.formatCentsShort(adjustment.amountCents),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.mutedText,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _EmptyPendingShares extends StatelessWidget {
  const _EmptyPendingShares();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.fieldColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tenés pagos pendientes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tus pagos y ajustes pendientes aparecerán acá.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}
