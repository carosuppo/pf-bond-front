import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/models/get_member_model.response.dart';
import '../balance/member_debt_trace.dart';
import '../formatters/account_movement_formatter.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';
import '../widgets/account_balance_card.dart';
import '../widgets/account_group_details_loader.dart';
import '../widgets/account_header_card.dart';
import '../widgets/account_member_debt_tile.dart';
import '../widgets/account_movement_card.dart';
import '../widgets/account_new_movement_sheet.dart';

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
  int _groupDetailsLoadAttempt = 0;

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

    await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountPayments,
      arguments: {'accountId': widget.accountId, 'groupId': groupId},
    );
  }

  Future<void> _showNewMovementOptions() async {
    final selection = await showAccountNewMovementSheet(context);

    if (!mounted || selection == null) return;
    switch (selection) {
      case NewAccountMovementType.expense:
        await _goToCreateExpense();
        break;
      case NewAccountMovementType.payment:
        await _goToPayments();
        break;
    }
  }

  Future<void> _goToAccountSettings() async {
    final leftAccount = await Navigator.of(context).pushNamed(
      AppRoutes.expenseAccountSettings,
      arguments: {'accountId': widget.accountId},
    );
    if (!mounted || leftAccount != true) return;

    Navigator.of(context).pop(true);
  }

  void _retryGroupDetails() {
    setState(() => _groupDetailsLoadAttempt++);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final currentUserId = context.watch<AuthProvider>().authResponse?.user.id;
    final detail = provider.accountDetail;

    return Builder(
      builder: (context) {
        if (provider.isDetailLoading ||
            detail == null ||
            detail.id != widget.accountId) {
          if (!provider.isDetailLoading &&
              provider.detailErrorMessage != null) {
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
          key: ValueKey(_groupDetailsLoadAttempt),
          groupId: detail.groupId,
          builder: (context, groupDetails, isLoading, error) {
            if (isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (error != null || groupDetails == null) {
              return _SummaryError(
                message: 'No se pudieron cargar los datos del grupo.',
                onRetry: _retryGroupDetails,
              );
            }

            return Column(
              children: [
                AppScreenHeader(
                  title: 'Cuenta',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: _SummaryBody(
                    detail: detail,
                    groupDetails: groupDetails,
                    currentUserId: currentUserId,
                    onSettingsTap: _goToAccountSettings,
                    onNewMovementTap: _showNewMovementOptions,
                    onMovementsTap: _goToMovements,
                  ),
                ),
              ],
            );
          },
        );
      },
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
    required this.currentUserId,
    required this.onSettingsTap,
    required this.onNewMovementTap,
    required this.onMovementsTap,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel? groupDetails;
  final int? currentUserId;
  final VoidCallback onSettingsTap;
  final VoidCallback onNewMovementTap;
  final VoidCallback onMovementsTap;

  List<AccountMovementModel> _recentMovements() {
    final movements = detail.movements.toList()
      ..sort((first, second) {
        final firstDate = first.settledAt ?? first.createdAt;
        final secondDate = second.settledAt ?? second.createdAt;
        final dateOrder = secondDate.compareTo(firstDate);
        return dateOrder != 0 ? dateOrder : second.id.compareTo(first.id);
      });

    return movements.take(3).toList(growable: false);
  }

  String _creatorSubtitle(
    AccountMovementModel movement,
    ExpenseAccountProvider provider,
  ) => accountMovementCreatorSubtitle(
    movement: movement,
    accountId: detail.id,
    allMovements: detail.movements,
    groupMembers: groupDetails?.members ?? const [],
    currentUserId: currentUserId,
    createdExpense: provider.createdExpense,
    updatedExpense: provider.updatedExpense,
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();
    final traces = calculateMemberDebtTraces(
      myMemberId: detail.myMemberId,
      movements: detail.movements,
    );
    final debtsToMe = traces
        .where((trace) => trace.netBalanceCents > 0)
        .toList(growable: false);
    final myDebts = traces
        .where((trace) => trace.netBalanceCents < 0)
        .toList(growable: false);
    final Map<int, GetMemberResponseModel> membersById = {
      if (groupDetails != null)
        for (final member in groupDetails!.members) member.id: member,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountHeaderCard(
            name: detail.name,
            groupName: detail.groupName,
            eventName: detail.eventName,
            trailing: IconButton(
              onPressed: onSettingsTap,
              tooltip: 'Configuración de cuenta',
              icon: const Icon(Icons.settings_outlined, color: AppColors.text),
            ),
          ),
          const SizedBox(height: 14),
          AccountBalanceCard(
            label: 'Saldo neto',
            status: detail.myStatus,
            balanceCents: detail.myBalanceCents,
          ),
          const SizedBox(height: 20),
          const Text(
            'Mis deudas',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (traces.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'No tenés deudas pendientes.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            )
          else ...[
            _DebtSection(
              title: 'Me deben',
              color: AppColors.success,
              emptyMessage: 'Nadie te debe en esta cuenta.',
              traces: debtsToMe,
              membersById: membersById,
              myMemberId: detail.myMemberId,
            ),
            const SizedBox(height: 8),
            _DebtSection(
              title: 'Debo',
              color: AppColors.error,
              emptyMessage: 'No debés en esta cuenta.',
              traces: myDebts,
              membersById: membersById,
              myMemberId: detail.myMemberId,
            ),
          ],
          const SizedBox(height: 18),
          AppPrimaryButton(
            text: 'Nuevo movimiento',
            onPressed: onNewMovementTap,
            leading: const Icon(Icons.add_rounded),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Actividad reciente',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onMovementsTap,
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (detail.movements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Todavía no hay movimientos.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            )
          else
            for (final movement in _recentMovements())
              AccountMovementCard(
                icon: movement.kind == 'EXPENSE'
                    ? Icons.receipt_long_outlined
                    : Icons.payments_outlined,
                accentColor: movement.kind == 'PAYMENT'
                    ? AppColors.success
                    : AppColors.primary,
                title: accountMovementTitle(movement),
                subtitle: _creatorSubtitle(movement, provider),
                amountCents: movement.amountCents,
                createdAt: movement.settledAt ?? movement.createdAt,
              ),
        ],
      ),
    );
  }
}

class _DebtSection extends StatelessWidget {
  const _DebtSection({
    required this.title,
    required this.color,
    required this.emptyMessage,
    required this.traces,
    required this.membersById,
    required this.myMemberId,
  });

  final String title;
  final Color color;
  final String emptyMessage;
  final List<MemberDebtTrace> traces;
  final Map<int, GetMemberResponseModel> membersById;
  final int myMemberId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (traces.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          )
        else
          for (final trace in traces)
            AccountMemberDebtTile(
              key: ValueKey(trace.memberId),
              trace: trace,
              memberName:
                  membersById[trace.memberId]?.name ??
                  'Miembro ${trace.memberId}',
              myMemberId: myMemberId,
            ),
      ],
    );
  }
}
