import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';

/// Tile de selección de miembro con check, mismo estilo que
/// la pantalla de crear evento. Opcionalmente muestra una foto
/// y un widget a la derecha del nombre (ej: un importe).
class MemberCheckTile extends StatelessWidget {
  const MemberCheckTile({
    super.key,
    required this.name,
    this.photoUrl,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    this.trailing,
  });

  final String name;
  final String? photoUrl;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim();

    return InkWell(
      onTap: enabled ? () => onChanged(!selected) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            if (photo != null && photo.isNotEmpty)
              UserAvatar(name: name, photoUrl: photo, radius: 20)
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: selected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                key: ValueKey(selected),
                color: selected ? AppColors.primary : AppColors.mutedText,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
