import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_message_dialog.dart';

Future<bool> showCancelEventDialog(BuildContext context, String eventName) {
  return showAppMessageDialog(
    context,
    title: '¿Cancelar evento?',
    message:
        'Se va a cancelar "$eventName" y se va a avisar a los miembros. '
        'Esta acción no se puede deshacer.',
    cancelText: 'Volver',
    confirmText: 'Sí, cancelar',
    icon: Icons.event_busy_rounded,
    accentColor: AppColors.error,
    confirmButtonColor: AppColors.error,
  );
}
