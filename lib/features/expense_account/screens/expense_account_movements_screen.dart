import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../models/expense_account_detail_model.response.dart';
import '../providers/expense_account_provider.dart';

class ExpenseAccountMovementsScreen extends StatelessWidget {
  const ExpenseAccountMovementsScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _MovementsContent(accountId: accountId)),
    );
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
    final expenses = detail.movements
        .where((movement) => movement.kind == 'EXPENSE')
        .toList(growable: false);
    final payments = detail.movements
        .where((movement) => movement.kind == 'PAYMENT')
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
                ),
                _MovementsList(
                  emptyMessage: 'Todavía no hay pagos en esta cuenta.',
                  movements: payments,
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
  const _MovementsList({required this.emptyMessage, required this.movements});

  final String emptyMessage;
  final List<AccountMovementModel> movements;

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

        return _MovementCard(movement: movement);
      },
    );
  }
}

/// Tarjeta preparada para el detalle de cada movimiento. Hoy el back solo
/// envía el tipo; las historias de registrar gasto y pago agregarán título,
/// importe, fecha, pagador y participantes.
class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final AccountMovementModel movement;

  @override
  Widget build(BuildContext context) {
    final isExpense = movement.kind == 'EXPENSE';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpense ? Icons.receipt_long_outlined : Icons.payments_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isExpense ? 'Gasto' : 'Pago',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
