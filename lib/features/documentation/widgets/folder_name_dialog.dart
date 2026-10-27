import 'package:flutter/material.dart';

class FolderNameDialog extends StatefulWidget {
  final String? initialName;
  const FolderNameDialog({super.key, this.initialName});
  @override
  State<FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<FolderNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialName == null ? 'Nueva carpeta' : 'Renombrar carpeta',
    ),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Nombre'),
        validator: (String? value) =>
            value == null || value.trim().isEmpty ? 'Ingresá un nombre.' : null,
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _name.text.trim());
          }
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
