import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const AppScreenHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    final hasBackButton = onBack != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(hasBackButton ? 8 : 16, 8, 16, 8),
      child: Row(
        children: [
          if (hasBackButton)
            IconButton(
              onPressed: onBack,
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
