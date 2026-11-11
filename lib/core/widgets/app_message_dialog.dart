import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Displays a confirmation/message dialog and returns whether it was accepted.
/// Optional callbacks run after the dialog closes; a null [cancelText] hides
/// the cancel button.
Future<bool> showAppMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String? cancelText = 'Cancelar',
  FutureOr<void> Function()? onConfirm,
  FutureOr<void> Function()? onCancel,
  IconData icon = Icons.warning_rounded,
  Color accentColor = AppColors.primary,
  Color confirmButtonColor = AppColors.primary,
  bool barrierDismissible = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => _AppMessageDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      accentColor: accentColor,
      confirmButtonColor: confirmButtonColor,
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );

  if (confirmed == true) {
    await onConfirm?.call();
    return true;
  }

  await onCancel?.call();
  return false;
}

class _AppMessageDialog extends StatelessWidget {
  const _AppMessageDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.icon,
    required this.accentColor,
    required this.confirmButtonColor,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final IconData icon;
  final Color accentColor;
  final Color confirmButtonColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final messageMaxHeight = MediaQuery.sizeOf(context).height * 0.45;

    return Dialog(
      backgroundColor: AppColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.fieldColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: messageMaxHeight),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (cancelText != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        cancelText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmButtonColor,
                      foregroundColor: confirmButtonColor == AppColors.primary
                          ? AppColors.onPrimary
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
