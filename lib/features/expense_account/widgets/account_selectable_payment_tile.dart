import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../formatters/money_formatter.dart';

class AccountSelectablePaymentTile extends StatelessWidget {
  const AccountSelectablePaymentTile({
    super.key,
    required this.title,
    required this.description,
    required this.amountCents,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final int amountCents;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: enabled ? (_) => onTap() : null,
                    activeColor: AppColors.primary,
                    checkColor: AppColors.onPrimary,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.mutedText,
                      width: 1.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 104),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  MoneyFormatter.formatCentsShort(amountCents),
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
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
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}
