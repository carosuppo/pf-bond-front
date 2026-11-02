import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../models/documentation_models.dart';
import '../providers/documentation_provider.dart';

class DocumentEditor extends StatefulWidget {
  final FamilyDocument? document;
  const DocumentEditor({super.key, this.document});
  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  int? _member;
  String? _folder;
  SelectedDocumentFile? _file;
  String? _error;
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.document?.name);
    _member = widget.document?.memberId;
    _folder = widget.document == null
        ? context.read<DocumentationProvider>().folderId
        : widget.document!.folderId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final SelectedDocumentFile? file = await context
          .read<DocumentationProvider>()
          .service
          .pick();
      if (mounted && file != null) {
        setState(() {
          _file = file;
          if (_name.text.isEmpty) _name.text = file.name;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.document == null && _file == null) {
      setState(() => _error = 'Seleccioná un archivo.');
      return;
    }
    final DocumentationProvider p = context.read<DocumentationProvider>();
    final bool success = await p.save(
      _name.text,
      _member,
      _folder,
      _file,
      widget.document?.id,
    );
    if (mounted && success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final DocumentationProvider p = context.watch<DocumentationProvider>();
    final bool disabled = p.saving || _picking;
    final List<DocumentMember> members = p.data.members
        .where((DocumentMember m) => m.active)
        .toList();
    if (widget.document?.memberId != null &&
        !members.any((DocumentMember m) => m.id == widget.document!.memberId)) {
      members.add(
        DocumentMember(
          widget.document!.memberId!,
          '${widget.document!.memberName} (ya no pertenece al grupo)',
        ),
      );
    }
    return PopScope(
      canPop: !disabled,
      child: AlertDialog(
        title: Text(
          widget.document == null ? 'Subir documento' : 'Editar documento',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: _name,
                    enabled: !disabled,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (String? value) =>
                        value == null || value.trim().isEmpty
                        ? 'Ingresá un nombre.'
                        : null,
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _member ?? 0,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Integrante (opcional)',
                    ),
                    items: <DropdownMenuItem<int>>[
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Sin integrante'),
                      ),
                      for (final DocumentMember member in members)
                        DropdownMenuItem<int>(
                          value: member.id,
                          child: Text(member.name),
                        ),
                    ],
                    onChanged: disabled
                        ? null
                        : (int? value) => setState(
                            () => _member = value == 0 ? null : value,
                          ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _folder ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Carpeta de destino',
                    ),
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Raíz'),
                      ),
                      for (final DocumentFolder folder in p.data.folders)
                        DropdownMenuItem<String>(
                          value: folder.id,
                          child: Text(
                            p.location(folder.id),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: disabled
                        ? null
                        : (String? value) => setState(
                            () => _folder = value == '' ? null : value,
                          ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: disabled ? null : _pick,
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      _file?.name ??
                          (widget.document == null
                              ? 'Seleccionar archivo'
                              : 'Reemplazar archivo (opcional)'),
                    ),
                  ),
                  const Text('PDF, JPG, PNG o WebP · máximo 10 MB'),
                  if (_error != null || p.error != null)
                    Text(
                      _error ?? p.error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  if (disabled) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: disabled ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: disabled ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
