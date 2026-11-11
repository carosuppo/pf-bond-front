import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../event/formatters/event_date_formatter.dart';
import '../formatters/money_formatter.dart';
import 'account_payment_status_badge.dart';

class AccountMovementCard extends StatelessWidget {
  const AccountMovementCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amountCents,
    required this.createdAt,
    this.accentColor = AppColors.primary,
    this.statusLabel,
    this.statusColor = AppColors.primary,
    this.isAnnulled = false,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int amountCents;
  final DateTime createdAt;
  final Color accentColor;
  final String? statusLabel;
  final Color statusColor;
  final bool isAnnulled;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final amountStyle = TextStyle(
      color: isAnnulled ? AppColors.mutedText : AppColors.text,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      decoration: isAnnulled ? TextDecoration.lineThrough : null,
      decorationColor: AppColors.mutedText,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
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
                            style: TextStyle(
                              color: isAnnulled
                                  ? AppColors.mutedText
                                  : AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(width: 6),
                          AccountPaymentStatusBadge(
                            label: statusLabel!,
                            color: isAnnulled ? AppColors.error : statusColor,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              MoneyFormatter.formatCentsShort(amountCents),
                              style: amountStyle,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          EventDateFormatter.dayMonthYear(createdAt),
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
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
