import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'user_avatar.dart';

class AvatarStackItem {
  const AvatarStackItem({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.items,
    this.radius = 16,
    this.maxShown = 4,
  });

  final List<AvatarStackItem> items;
  final double radius;
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final shown = items.take(maxShown).toList(growable: false);
    final remaining = items.length - shown.length;
    final step = radius * 1.1;
    final circles = shown.length + (remaining > 0 ? 1 : 0);
    final width = radius * 2 + step * (circles - 1);

    return SizedBox(
      width: width,
      height: radius * 2,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: UserAvatar(
                name: shown[i].name,
                photoUrl: shown[i].photoUrl,
                radius: radius,
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: shown.length * step,
              child: CircleAvatar(
                radius: radius,
                backgroundColor: AppColors.fieldColor,
                child: Text(
                  '+$remaining',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
