import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/group_inbox_provider.dart';

class GroupInboxButton extends StatelessWidget {
  const GroupInboxButton({super.key});

  @override
  Widget build(BuildContext context) {
    final inbox = Provider.of<GroupInboxProvider?>(context);
    final hasUnread = (inbox?.unreadCount ?? 0) > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.inbox),
          tooltip: hasUnread
              ? 'Buzón de entrada con notificaciones sin leer'
              : 'Buzón de entrada',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          color: AppColors.primary,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_rounded),
              if (hasUnread)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    key: const Key('group-inbox-unread-indicator'),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cardColor,
                        width: 1.5,
                      ),
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
