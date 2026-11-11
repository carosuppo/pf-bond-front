import 'package:flutter/material.dart';

import 'app_message_dialog.dart';

Future<bool> showDiscardChangesDialog(BuildContext context) {
  return showAppMessageDialog(
    context,
    title: '¿Descartar cambios?',
    message:
        'Todavía no guardaste la información que cargaste. '
        'Si sales ahora, se va a perder.',
    cancelText: 'Seguir editando',
    confirmText: 'Descartar',
  );
}
