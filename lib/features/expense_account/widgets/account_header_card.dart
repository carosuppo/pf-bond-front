import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AccountHeaderCard extends StatelessWidget {
  const AccountHeaderCard({
    super.key,
    required this.name,
    required this.groupName,
    this.eventName,
  });

  final String name;
  final String groupName;
  final String? eventName;

  @override
  Widget build(BuildContext context) {
    final event = eventName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              event != null
                  ? Icons.calendar_month_outlined
                  : Icons.groups_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event != null
                      ? 'Grupo: $groupName \nEvento: $event'
                      : 'Grupo: $groupName',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
