import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/global_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../formatters/expense_split.dart';
import '../formatters/money_formatter.dart';
import '../models/create_expense_model.request.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/expense_model.response.dart';
import '../models/expense_split_type.dart';
import '../providers/expense_account_provider.dart';
import 'member_check_tile.dart';

class CreateExpenseForm extends StatefulWidget {
  final int accountId;
  final AccountMovementModel? expense;
  final bool hasConfirmedPayments;

  const CreateExpenseForm({
    super.key,
    required this.accountId,
    this.expense,
    this.hasConfirmedPayments = false,
  });

  @override
  State<CreateExpenseForm> createState() => _CreateExpenseFormState();
}

class _MemberInfo {
  const _MemberInfo({required this.id, required this.name, this.photoUrl});

  final int id;
  final String name;
  final String? photoUrl;
}

class _CreateExpenseFormState extends State<CreateExpenseForm> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final Map<int, TextEditingController> _customAmountControllers = {};

  int? _payerMemberId;
  GetGroupResponseModel? _accountGroupDetails;
  int? _requestedGroupId;
  bool _isGroupDetailsLoading = false;
  String? _groupDetailsError;
  ExpenseSplitType _splitType = ExpenseSplitType.equal;
  final Set<int> _selectedParticipantIds = {};
  bool _initializedExpense = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ExpenseAccountProvider>().loadAccountDetail(
        accountId: widget.accountId,
      );
    });
  }

  void _ensureAccountGroupLoaded(int groupId) {
    if (_requestedGroupId == groupId) {
      return;
    }

    _requestedGroupId = groupId;
    _accountGroupDetails = null;
    _isGroupDetailsLoading = true;
    _groupDetailsError = null;
    unawaited(_loadAccountGroupDetails(groupId));
  }

  Future<void> _loadAccountGroupDetails(int groupId) async {
    try {
      final groupDetails = await context
          .read<GroupProvider>()
          .getGroupDetailsForAccount(groupId: groupId);
      if (!mounted || _requestedGroupId != groupId) {
        return;
      }

      setState(() {
        _accountGroupDetails = groupDetails;
        _isGroupDetailsLoading = false;
        _groupDetailsError = groupDetails == null
            ? 'No se pudo cargar el grupo de esta cuenta.'
            : null;
        _payerMemberId ??= _defaultPayerId();
      });
      _initializeExpenseIfNeeded();
    } catch (error) {
      if (!mounted || _requestedGroupId != groupId) {
        return;
      }

      setState(() {
        _isGroupDetailsLoading = false;
        _groupDetailsError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  TextEditingController _createCustomAmountController(String value) {
    final controller = TextEditingController(text: value);
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    return controller;
  }

  void _initializeExpenseIfNeeded() {
    final expense = widget.expense;
    if (_initializedExpense || expense == null) return;

    final currentShares = expense.shares
        .where((share) => share.isCurrent)
        .toList(growable: false);
    if (currentShares.isEmpty) return;

    final base = expense.amountCents ~/ currentShares.length;
    final remainder = expense.amountCents % currentShares.length;
    final upperShareCount = currentShares
        .where((share) => share.amountCents == base + 1)
        .length;
    final isEqualDistribution =
        currentShares.every(
          (share) => share.amountCents == base || share.amountCents == base + 1,
        ) &&
        upperShareCount == remainder;

    _initializedExpense = true;
    _titleController.text = expense.title ?? '';
    _amountController.text = MoneyFormatter.formatCents(expense.amountCents);
    _payerMemberId = expense.payerMemberId;
    _splitType =
        expense.splitType ??
        (isEqualDistribution
            ? ExpenseSplitType.equal
            : ExpenseSplitType.custom);
    _selectedParticipantIds
      ..clear()
      ..addAll(currentShares.map((share) => share.memberId));
    for (final share in currentShares) {
      _customAmountControllers[share.memberId] = _createCustomAmountController(
        MoneyFormatter.formatCents(share.amountCents),
      );
    }
    setState(() {});
  }

  void _retryAccountGroupLoad(int groupId) {
    setState(() {
      _requestedGroupId = null;
    });
    _ensureAccountGroupLoaded(groupId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final controller in _customAmountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _defaultPayerId() {
    final currentUserId = context.read<AuthProvider>().authResponse?.user.id;
    final groupDetails = _accountGroupDetails;
    final detail = context.read<ExpenseAccountProvider>().accountDetail;

    if (currentUserId == null || groupDetails == null || detail == null) {
      return null;
    }

    if (groupDetails.id != detail.groupId) {
      return null;
    }

    for (final member in groupDetails.members) {
      if (member.idUser == currentUserId &&
          detail.members.any((m) => m.memberId == member.id)) {
        return member.id;
      }
    }

    return null;
  }

  List<_MemberInfo> _accountMembers() {
    final detail = context.read<ExpenseAccountProvider>().accountDetail;

    final groupDetails = _accountGroupDetails;
    if (detail == null || groupDetails?.id != detail.groupId) {
      return const [];
    }

    final byId = {
      for (final member in groupDetails!.members) member.id: member,
    };

    return [
      for (final memberId in detail.members.map((m) => m.memberId))
        _MemberInfo(
          id: memberId,
          name: byId[memberId]?.name ?? 'Miembro',
          photoUrl: byId[memberId]?.profilePhoto,
        ),
    ];
  }

  _MemberInfo? _memberInfo(int memberId) {
    for (final member in _accountMembers()) {
      if (member.id == memberId) {
        return member;
      }
    }

    return null;
  }

  int? get _amountCents => MoneyFormatter.parseCents(_amountController.text);

  List<({int memberId, int amountCents})> get _previewShares {
    final amount = _amountCents;

    if (amount == null || _selectedParticipantIds.isEmpty) {
      return [];
    }

    final ordered = _accountMembers()
        .where((member) => _selectedParticipantIds.contains(member.id))
        .map((member) => member.id)
        .toList(growable: false);

    return splitEquallyCents(amount, ordered);
  }

  int get _assignedCents {
    var total = 0;

    for (final memberId in _selectedParticipantIds) {
      total +=
          MoneyFormatter.parseCents(
            _customAmountControllers[memberId]?.text ?? '',
          ) ??
          0;
    }

    return total;
  }

  bool get _customAmountsValid {
    for (final memberId in _selectedParticipantIds) {
      if (MoneyFormatter.parseCents(
            _customAmountControllers[memberId]?.text ?? '',
          ) ==
          null) {
        return false;
      }
    }

    return true;
  }

  void _toggleParticipant(int memberId, bool selected) {
    setState(() {
      if (selected) {
        _selectedParticipantIds.add(memberId);
        _customAmountControllers.putIfAbsent(
          memberId,
          () => _createCustomAmountController(''),
        );
      } else {
        _selectedParticipantIds.remove(memberId);
        _customAmountControllers.remove(memberId)?.dispose();
      }
    });
  }

  void _switchSplitType(ExpenseSplitType splitType) {
    if (_splitType == splitType) {
      return;
    }

    final equalShares = _previewShares;
    if (splitType == ExpenseSplitType.custom) {
      for (final share in equalShares) {
        final controller = _customAmountControllers.putIfAbsent(
          share.memberId,
          () => _createCustomAmountController(''),
        );
        controller.text = MoneyFormatter.formatCents(share.amountCents);
      }
    }
    setState(() {
      _splitType = splitType;
    });
  }

  Future<void> _openPayerSheet(List<_MemberInfo> members) async {
    if (widget.hasConfirmedPayments) return;
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mutedText.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¿Quién pagó?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (_, index) {
                      final member = members[index];

                      return MemberCheckTile(
                        name: member.name,
                        photoUrl: member.photoUrl,
                        selected: member.id == _payerMemberId,
                        enabled: true,
                        onChanged: (_) {
                          Navigator.of(sheetContext).pop();
                          setState(() {
                            _payerMemberId = member.id;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveExpense() async {
    final amount = _amountCents;

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un importe mayor que cero.')),
      );

      return;
    }

    if (_payerMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí quién pagó el gasto.')),
      );

      return;
    }

    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí al menos un participante.')),
      );

      return;
    }

    if (_splitType == ExpenseSplitType.custom) {
      if (!_customAmountsValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisá los importes del reparto.')),
        );

        return;
      }

      final assigned = _assignedCents;

      if (assigned != amount) {
        if (!mounted) {
          return;
        }

        await _showMismatchDialog(assigned: assigned, total: amount);

        return;
      }
    }

    final provider = context.read<ExpenseAccountProvider>();
    final title = _titleController.text.trim().isEmpty
        ? null
        : _titleController.text.trim();
    final participantIds = _splitType == ExpenseSplitType.equal
        ? _selectedParticipantIds.toList(growable: false)
        : null;
    final shares = _splitType == ExpenseSplitType.custom
        ? [
            for (final memberId in _selectedParticipantIds)
              ExpenseShareRequestModel(
                memberId: memberId,
                amountCents:
                    MoneyFormatter.parseCents(
                      _customAmountControllers[memberId]?.text ?? '',
                    ) ??
                    0,
              ),
          ]
        : null;

    if (widget.expense case final expense?) {
      final changes = _editChanges(amount);
      if (changes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay cambios para guardar.')),
        );
        return;
      }
      final confirmed = await _confirmEdit(changes);
      if (!mounted || !confirmed) return;

      final success = await provider.updateExpense(
        accountId: widget.accountId,
        expenseId: expense.id,
        title: title,
        amountCents: amount,
        payerMemberId: _payerMemberId!,
        splitType: _splitType,
        participantIds: participantIds,
        shares: shares,
      );
      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.updateExpenseErrorMessage ??
                  'No se pudo actualizar el gasto.',
            ),
          ),
        );
        return;
      }

      await _showUpdateSuccessDialog(expense);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final success = await provider.createExpense(
      accountId: widget.accountId,
      title: title,
      amountCents: amount,
      payerMemberId: _payerMemberId!,
      splitType: _splitType,
      participantIds: participantIds,
      shares: shares,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Error al registrar el gasto.',
          ),
        ),
      );
      return;
    }

    final created = provider.createdExpense;

    if (created == null) {
      Navigator.of(context).pop(true);
      return;
    }

    await _showSuccessDialog(created);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  List<String> _editChanges(int amountCents) {
    final expense = widget.expense;
    if (expense == null) return const [];

    final changes = <String>[];
    final oldTitle = expense.title?.trim() ?? '';
    final newTitle = _titleController.text.trim();
    if (oldTitle != newTitle) {
      changes.add(
        'Título: ${oldTitle.isEmpty ? 'Sin título' : oldTitle} → ${newTitle.isEmpty ? 'Sin título' : newTitle}',
      );
    }
    if (expense.amountCents != amountCents) {
      changes.add(
        'Importe: ${MoneyFormatter.formatCentsShort(expense.amountCents)} → ${MoneyFormatter.formatCentsShort(amountCents)}',
      );
    }
    if (expense.payerMemberId != _payerMemberId) {
      changes.add(
        'Pagador: ${_memberInfo(expense.payerMemberId ?? -1)?.name ?? 'Miembro'} → ${_memberInfo(_payerMemberId!)?.name ?? 'Miembro'}',
      );
    }

    final oldShares = {
      for (final share in expense.shares.where((share) => share.isCurrent))
        share.memberId: share.amountCents,
    };
    final newShares = <int, int>{
      if (_splitType == ExpenseSplitType.equal)
        for (final share in _previewShares) share.memberId: share.amountCents
      else
        for (final memberId in _selectedParticipantIds)
          memberId:
              MoneyFormatter.parseCents(
                _customAmountControllers[memberId]?.text ?? '',
              ) ??
              0,
    };
    final oldIds = oldShares.keys.toSet();
    final newIds = newShares.keys.toSet();
    if (!_sameSet(oldIds, newIds)) {
      final oldNames = oldIds.map((id) => _memberInfo(id)?.name ?? 'Miembro');
      final newNames = newIds.map((id) => _memberInfo(id)?.name ?? 'Miembro');
      changes.add(
        'Participantes: ${oldNames.isEmpty ? 'Ninguno' : oldNames.join(', ')} → ${newNames.isEmpty ? 'Ninguno' : newNames.join(', ')}',
      );
    }
    final oldSplitType = expense.splitType ?? _inferSplitType(expense);
    if (oldSplitType != _splitType) {
      changes.add(
        'Modalidad de reparto: ${oldSplitType.label} → ${_splitType.label}',
      );
    }
    for (final memberId in {...oldIds, ...newIds}) {
      final before = oldShares[memberId];
      final after = newShares[memberId];
      if (before == null && after != null) {
        changes.add(
          '${_memberInfo(memberId)?.name ?? 'Miembro'}: agregado · ${MoneyFormatter.formatCentsShort(after)}',
        );
      } else if (before != null && after == null) {
        changes.add(
          '${_memberInfo(memberId)?.name ?? 'Miembro'}: quitado · ${MoneyFormatter.formatCentsShort(before)}',
        );
      } else if (before != after && before != null && after != null) {
        changes.add(
          '${_memberInfo(memberId)?.name ?? 'Miembro'}: ${MoneyFormatter.formatCentsShort(before)} → ${MoneyFormatter.formatCentsShort(after)}',
        );
      }
    }
    return changes;
  }

  ExpenseSplitType _inferSplitType(AccountMovementModel expense) {
    final shares = expense.shares.where((share) => share.isCurrent).toList();
    if (shares.isEmpty) return ExpenseSplitType.equal;
    final base = expense.amountCents ~/ shares.length;
    final remainder = expense.amountCents % shares.length;
    final upperShareCount = shares
        .where((share) => share.amountCents == base + 1)
        .length;
    final isEqual =
        shares.every(
          (share) => share.amountCents == base || share.amountCents == base + 1,
        ) &&
        upperShareCount == remainder;
    return isEqual ? ExpenseSplitType.equal : ExpenseSplitType.custom;
  }

  bool _sameSet(Set<int> first, Set<int> second) =>
      first.length == second.length && first.containsAll(second);

  Future<bool> _confirmEdit(List<String> changes) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revisá los cambios'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final change in changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(change),
                ),
              if (widget.hasConfirmedPayments) ...[
                const SizedBox(height: 8),
                const Text(
                  'Este gasto tiene pagos registrados. Los cambios pueden generar nuevas deudas o importes a devolver; los importes definitivos se calcularán al guardar.',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _showUpdateSuccessDialog(AccountMovementModel expense) async {
    final updated = context.read<ExpenseAccountProvider>().accountDetail;
    final adjustments =
        updated?.movements
            .where(
              (movement) =>
                  movement.kind == 'ADJUSTMENT' &&
                  movement.expenseId == expense.id &&
                  movement.status == 'PENDING',
            )
            .toList(growable: false) ??
        const <AccountMovementModel>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gasto actualizado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Los cambios se guardaron correctamente.'),
              if (widget.hasConfirmedPayments) ...[
                const SizedBox(height: 14),
                const Text(
                  'Ajustes económicos pendientes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (adjustments.isEmpty)
                  const Text('No hay nuevos ajustes pendientes.'),
                for (final adjustment in adjustments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${adjustment.debtorMemberId == expense.payerMemberId ? 'Devolución' : 'Importe adicional'}: '
                      '${_memberInfo(adjustment.debtorMemberId ?? -1)?.name ?? 'Miembro'} paga a '
                      '${_memberInfo(adjustment.creditorMemberId ?? -1)?.name ?? 'Miembro'} · '
                      '${MoneyFormatter.formatCentsShort(adjustment.amountCents)}',
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMismatchDialog({
    required int assigned,
    required int total,
  }) async {
    final difference = total - assigned;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Revisá el reparto',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La suma de los importes (${MoneyFormatter.formatCentsShort(assigned)}) '
                  'no coincide con el total del gasto (${MoneyFormatter.formatCentsShort(total)}). '
                  'Diferencia: ${MoneyFormatter.formatCentsShort(difference)}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  text: 'Entendido',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSuccessDialog(ExpenseResponseModel expense) async {
    final payer = _memberInfo(expense.payerMemberId);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  '¡Gasto registrado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _SummaryRow(
                  label: 'Pagó',
                  value:
                      '${payer?.name ?? 'Miembro'} · ${MoneyFormatter.formatCentsShort(expense.amountCents)}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aportes',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                for (final share in expense.shares)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _memberInfo(share.memberId)?.name ?? 'Miembro',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          MoneyFormatter.formatCentsShort(share.amountCents),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${payer?.name ?? 'Miembro'} recibe los aportes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                AppPrimaryButton(
                  text: 'Ver movimientos',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _hasChanges {
    final expense = widget.expense;
    if (expense != null) {
      final amount = _amountCents;
      return amount == null || _editChanges(amount).isNotEmpty;
    }
    return _titleController.text.trim().isNotEmpty ||
        _amountController.text.trim().isNotEmpty ||
        _selectedParticipantIds.isNotEmpty;
  }

  Future<void> _handleBack() async {
    if (!_hasChanges) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      return;
    }

    final shouldDiscard = await showDiscardChangesDialog(context);

    if (!mounted || !shouldDiscard) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final detail = provider.accountDetail;
    if (detail != null) {
      _ensureAccountGroupLoaded(detail.groupId);
    }
    final isLoading = provider.isLoading || provider.isUpdatingExpense;

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    final maxContentWidth = screenWidth > 600 ? 480.0 : double.infinity;
    final horizontalPadding = screenWidth > 600 ? 32.0 : 24.0;

    final members = _accountMembers();
    final payer = _payerMemberId == null ? null : _memberInfo(_payerMemberId!);
    final previewShares = _previewShares;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: widget.expense == null
                  ? 'Registrar gasto'
                  : 'Editar gasto',
              onBack: _handleBack,
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
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (_isGroupDetailsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (_groupDetailsError != null ||
                      _accountGroupDetails?.id != detail.groupId) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _groupDetailsError ??
                                  'No se pudo cargar el grupo de esta cuenta.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () =>
                                  _retryAccountGroupLoad(detail.groupId),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlobalTextField(
                              controller: _titleController,
                              label: 'Título (opcional)',
                              maxLength: 100,
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 16),
                            GlobalTextField(
                              controller: _amountController,
                              label: 'Importe *',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              enabled: !isLoading,
                            ),
                            const SizedBox(height: 20),
                            _PayerCard(
                              payerName: payer?.name,
                              locked: widget.hasConfirmedPayments,
                              enabled:
                                  !isLoading &&
                                  members.isNotEmpty &&
                                  !widget.hasConfirmedPayments,
                              onTap: () => _openPayerSheet(members),
                            ),
                            if (widget.hasConfirmedPayments) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'El pagador no se puede cambiar porque este gasto tiene pagos registrados.',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const _FieldHeader(label: 'Tipo de reparto'),
                            const SizedBox(height: 8),
                            _TypeSegmented(
                              splitType: _splitType,
                              enabled: !isLoading,
                              onChanged: _switchSplitType,
                            ),
                            const SizedBox(height: 20),
                            const _FieldHeader(label: 'Participantes'),
                            const SizedBox(height: 4),
                            Text(
                              'Elegí entre quiénes se divide el gasto. El pagador puede participar o no.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ParticipantsSection(
                              members: members,
                              selectedIds: _selectedParticipantIds,
                              splitType: _splitType,
                              previewShares: previewShares,
                              customControllers: _customAmountControllers,
                              enabled: !isLoading,
                              onToggle: _toggleParticipant,
                            ),
                            if (_splitType == ExpenseSplitType.custom &&
                                _selectedParticipantIds.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _AssignedTotal(
                                assignedCents: _assignedCents,
                                totalCents: _amountCents,
                              ),
                            ],
                            const SizedBox(height: 24),
                            AppPrimaryButton(
                              text: widget.expense == null
                                  ? 'Registrar gasto'
                                  : 'Guardar cambios',
                              loading: isLoading,
                              onPressed: isLoading ? null : _saveExpense,
                            ),
                            const SizedBox(height: 12),
                            AppSecondaryButton(
                              text: 'Cancelar',
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PayerCard extends StatelessWidget {
  const _PayerCard({
    required this.payerName,
    required this.locked,
    required this.enabled,
    required this.onTap,
  });

  final String? payerName;
  final bool locked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_outlined,
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
                      'Pagó',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payerName ?? 'Elegí quién pagó',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSegmented extends StatelessWidget {
  const _TypeSegmented({
    required this.splitType,
    required this.enabled,
    required this.onChanged,
  });

  final ExpenseSplitType splitType;
  final bool enabled;
  final ValueChanged<ExpenseSplitType> onChanged;

  Widget _option(
    BuildContext context, {
    required ExpenseSplitType value,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : AppColors.mutedText,
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _option(
            context,
            value: ExpenseSplitType.equal,
            selected: splitType == ExpenseSplitType.equal,
            onTap: enabled ? () => onChanged(ExpenseSplitType.equal) : null,
          ),
          _option(
            context,
            value: ExpenseSplitType.custom,
            selected: splitType == ExpenseSplitType.custom,
            onTap: enabled ? () => onChanged(ExpenseSplitType.custom) : null,
          ),
        ],
      ),
    );
  }
}

class _ParticipantsSection extends StatefulWidget {
  const _ParticipantsSection({
    required this.members,
    required this.selectedIds,
    required this.splitType,
    required this.previewShares,
    required this.customControllers,
    required this.enabled,
    required this.onToggle,
  });

  final List<_MemberInfo> members;
  final Set<int> selectedIds;
  final ExpenseSplitType splitType;
  final List<({int memberId, int amountCents})> previewShares;
  final Map<int, TextEditingController> customControllers;
  final bool enabled;
  final void Function(int memberId, bool selected) onToggle;

  @override
  State<_ParticipantsSection> createState() => _ParticipantsSectionState();
}

class _ParticipantsSectionState extends State<_ParticipantsSection> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _previewFor(int memberId) {
    for (final share in widget.previewShares) {
      if (share.memberId == memberId) {
        return MoneyFormatter.formatCentsShort(share.amountCents);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.fieldColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No hay miembros para repartir el gasto.',
          style: TextStyle(color: AppColors.mutedText),
        ),
      );
    }

    final filteredMembers = _query.isEmpty
        ? widget.members
        : widget.members
              .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    final isCustom = widget.splitType == ExpenseSplitType.custom;

    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(14),
      color: AppColors.fieldColor,
      child: Column(
        children: [
          if (widget.members.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _searchController,
                enabled: widget.enabled,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar miembro...',
                  hintStyle: const TextStyle(color: AppColors.mutedText),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.mutedText,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.03),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          if (filteredMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Sin resultados para tu búsqueda.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            )
          else
            for (final member in filteredMembers)
              MemberCheckTile(
                name: member.name,
                photoUrl: member.photoUrl,
                selected: widget.selectedIds.contains(member.id),
                enabled: widget.enabled,
                onChanged: (selected) => widget.onToggle(member.id, selected),
                trailing: isCustom && widget.selectedIds.contains(member.id)
                    ? _CustomAmountField(
                        controller: widget.customControllers[member.id]!,
                        enabled: widget.enabled,
                      )
                    : (!isCustom && widget.selectedIds.contains(member.id)
                          ? Text(
                              _previewFor(member.id) ?? '',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null),
              ),
        ],
      ),
    );
  }
}

class _CustomAmountField extends StatelessWidget {
  const _CustomAmountField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        textAlign: TextAlign.end,
        style: const TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: '0,00',
          hintStyle: const TextStyle(color: AppColors.mutedText),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _AssignedTotal extends StatelessWidget {
  const _AssignedTotal({required this.assignedCents, required this.totalCents});

  final int assignedCents;
  final int? totalCents;

  @override
  Widget build(BuildContext context) {
    final total = totalCents;

    if (total == null) {
      return Text(
        'Asignado ${MoneyFormatter.formatCentsShort(assignedCents)}',
        style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
      );
    }

    final difference = total - assignedCents;
    final matches = difference == 0;

    return Row(
      children: [
        const Icon(Icons.info_outline, color: AppColors.mutedText, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            matches
                ? 'Asignado ${MoneyFormatter.formatCentsShort(assignedCents)} de ${MoneyFormatter.formatCentsShort(total)}'
                : difference > 0
                ? 'Asignado ${MoneyFormatter.formatCentsShort(assignedCents)} de ${MoneyFormatter.formatCentsShort(total)} · Faltan ${MoneyFormatter.formatCentsShort(difference)}'
                : 'Asignado ${MoneyFormatter.formatCentsShort(assignedCents)} de ${MoneyFormatter.formatCentsShort(total)} · Sobra ${MoneyFormatter.formatCentsShort(-difference)}',
            style: TextStyle(
              color: matches ? AppColors.success : AppColors.error,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
