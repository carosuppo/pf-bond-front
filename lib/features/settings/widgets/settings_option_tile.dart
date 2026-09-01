import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/settings_option.dart';

/// Componente reutilizable que representa una fila de opción de configuración.
class SettingsOptionTile extends StatelessWidget {
  const SettingsOptionTile({super.key, required this.option});

  final SettingsOption option;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(option.icon, color: AppColors.mutedText),
      title: Text(option.title, style: const TextStyle(color: AppColors.text)),
      trailing: option.onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: AppColors.mutedText),
      onTap: option.onTap,
    );
  }
}
