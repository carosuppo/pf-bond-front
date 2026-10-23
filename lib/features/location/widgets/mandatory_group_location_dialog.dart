import 'package:flutter/material.dart';

import '../models/mandatory_group_location_action.dart';

Future<MandatoryGroupLocationAction?> showMandatoryGroupLocationDialog({
  required BuildContext context,
  required String groupName,
}) {
  return showDialog<MandatoryGroupLocationAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ubicación obligatoria'),
      content: Text(
        'El grupo “$groupName” obliga a compartir tu ubicación. Si no quieres '
        'activar los permisos de ubicación, debes salir del grupo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(MandatoryGroupLocationAction.leaveGroup),
          child: const Text('Salir del grupo'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(MandatoryGroupLocationAction.activateLocation),
          child: const Text('Activar ubicación'),
        ),
      ],
    ),
  );
}
