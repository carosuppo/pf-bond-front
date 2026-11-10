import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../formatters/money_formatter.dart';
import 'movement_status_chip.dart';

class MovementListItem extends StatelessWidget {
  const MovementListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.typeLabel,
    required this.amountCents,
    this.authorName,
    this.authorPhotoUrl,
    this.isPayment = false,
    this.isAdjustment = false,
    this.isAnnulled = false,
    this.isPending = false,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String typeLabel;
  final int amountCents;
  final String? authorName;
  final String? authorPhotoUrl;
  final bool isPayment;
  final bool isAdjustment;
  final bool isAnnulled;
  final bool isPending;
  final VoidCallback? onTap;
  final Widget? trailing;

  String? get _shortAuthorName {
    final normalizedName = authorName?.trim();
    if (normalizedName == null || normalizedName.isEmpty) return null;
    return normalizedName.split(RegExp(r'\s+')).first;
  }

  Color get _accentColor {
    if (isAnnulled) return AppColors.mutedText;
    if (isAdjustment) return AppColors.placeholder;
    if (isPayment) return AppColors.success;
    return AppColors.primary;
  }

  Color get _amountColor {
    if (isAnnulled || isAdjustment) return AppColors.mutedText;
    if (isPayment) return AppColors.success;
    return AppColors.text;
  }

  String get _amountLabel {
    final formattedAmount = MoneyFormatter.formatCentsShort(amountCents.abs());
    if (isPayment) return '+ $formattedAmount';
    if (!isAdjustment) return '− $formattedAmount';
    return formattedAmount;
  }

  @override
  Widget build(BuildContext context) {
    final shortAuthorName = _shortAuthorName;
    final titleColor = isAnnulled || isAdjustment
        ? AppColors.mutedText
        : AppColors.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _accentColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: isAdjustment ? 13 : 14,
                        fontWeight: isAdjustment
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          typeLabel,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 11,
                          ),
                        ),
                        if (isPending) const MovementStatusChip(),
                      ],
                    ),
                    if (shortAuthorName != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          UserAvatar(
                            name: authorName!,
                            photoUrl: authorPhotoUrl,
                            radius: 9,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              shortAuthorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: Text(
                  _amountLabel,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _amountColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: isAnnulled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
