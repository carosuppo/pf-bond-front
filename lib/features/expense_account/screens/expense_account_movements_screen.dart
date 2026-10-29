import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../group/models/get_group_model.response.dart';
import '../balance/member_debt_trace.dart';
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
        );
      },
    );
  }
}

class _MovementsTabsContent extends StatelessWidget {
  const _MovementsTabsContent({
    required this.detail,
    required this.groupDetails,
  });

  final ExpenseAccountDetailResponseModel detail;
  final GetGroupResponseModel groupDetails;

  @override
  Widget build(BuildContext context) {
    final memberNames = {
      for (final member in groupDetails.members) member.id: member.name,
    };
    final expenses = detail.movements
        .where(
          (movement) =>
              movement.kind == 'EXPENSE' &&
              memberMovementAmountCents(movement, detail.myMemberId) != null,
        )
        .toList(growable: false);
    final payments = detail.movements
        .where(
          (movement) =>
              movement.kind == 'PAYMENT' &&
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
                ),
                _MovementsList(
                  emptyMessage: 'Todavía no hay pagos en esta cuenta.',
                  movements: payments,
                  memberId: detail.myMemberId,
                  memberNames: memberNames,
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
  });

  final String emptyMessage;
  final List<AccountMovementModel> movements;
  final int memberId;
  final Map<int, String> memberNames;

  String _memberName(int? memberId) {
    return memberNames[memberId] ?? 'Miembro';
  }

  String _title(AccountMovementModel movement) {
    final title = movement.title?.trim();

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
      return 'Adelantaste · pagaste vos';
    }

    if (movement.fromMemberId == memberId) {
      return 'Pagaste a ${_memberName(movement.toMemberId)}';
    }
    return '${_memberName(movement.fromMemberId)} te pagó';
  }

  @override
  Widget build(BuildContext context) {
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

        return AccountMovementCard(
          icon: isExpense
              ? Icons.receipt_long_outlined
              : Icons.payments_outlined,
          accentColor: isExpense ? AppColors.primary : AppColors.success,
          title: _title(movement),
          subtitle: _subtitle(movement),
          amountCents: memberMovementAmountCents(movement, memberId) ?? 0,
          createdAt: movement.createdAt,
        );
      },
    );
  }
}
