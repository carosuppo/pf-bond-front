import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum NewAccountMovementType { expense, payment }

Future<NewAccountMovementType?> showAccountNewMovementSheet(
  BuildContext context,
) => showModalBottomSheet<NewAccountMovementType>(
  context: context,
  backgroundColor: AppColors.cardColor,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 12),
          const Text(
            'Nuevo movimiento',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _NewMovementOption(
            icon: Icons.receipt_long_outlined,
            color: AppColors.primary,
            title: 'Registrar gasto',
            subtitle: 'Cargá el importe y elegí cómo repartirlo.',
            onTap: () =>
                Navigator.of(sheetContext).pop(NewAccountMovementType.expense),
          ),
          const SizedBox(height: 8),
          _NewMovementOption(
            icon: Icons.payments_outlined,
            color: AppColors.success,
            title: 'Registrar pago',
            subtitle: 'Seleccioná gastos o ajustes pendientes.',
            onTap: () =>
                Navigator.of(sheetContext).pop(NewAccountMovementType.payment),
          ),
        ],
      ),
    ),
  ),
);

class _NewMovementOption extends StatelessWidget {
  const _NewMovementOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
}
