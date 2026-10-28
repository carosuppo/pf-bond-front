import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../models/documentation_models.dart';
import '../providers/documentation_provider.dart';
import '../services/documentation_service.dart';
import '../widgets/document_editor.dart';
import '../widgets/folder_name_dialog.dart';
import 'document_preview_screen.dart';

class DocumentationScreen extends StatelessWidget {
  final int groupId;
  final String groupName;
  final Widget? groupSelector;
  final bool handlesSystemBack;
  final VoidCallback? onExit;
  const DocumentationScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupSelector,
    this.handlesSystemBack = true,
    this.onExit,
  });
  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<DocumentationProvider>(
        key: ValueKey<int>(groupId),
        create: (BuildContext context) => DocumentationProvider(
          DocumentationService(context.read<ApiClient>()),
          groupId,
        )..load(),
        child: _DocumentationView(
          groupName: groupName,
          groupSelector: groupSelector,
          handlesSystemBack: handlesSystemBack,
          onExit: onExit,
        ),
      );
}

class _DocumentationView extends StatelessWidget {
  final String groupName;
  final Widget? groupSelector;
  final bool handlesSystemBack;
  final VoidCallback? onExit;
  const _DocumentationView({
    required this.groupName,
    this.groupSelector,
    required this.handlesSystemBack,
    this.onExit,
  });

  Future<void> _edit(BuildContext context, FamilyDocument? document) async {
    final DocumentationProvider provider = context
        .read<DocumentationProvider>();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          ChangeNotifierProvider<DocumentationProvider>.value(
            value: provider,
            child: DocumentEditor(document: document),
          ),
    );
  }

  Future<void> _folder(BuildContext context, DocumentFolder? folder) async {
    final DocumentationProvider provider = context
        .read<DocumentationProvider>();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          FolderNameDialog(initialName: folder?.name),
    );
    if (result != null) await provider.saveFolder(result, folder?.id);
  }

  Future<void> _delete(
    BuildContext context,
    String id,
    String name,
    bool folder,
  ) async {
    final DocumentationProvider provider = context
        .read<DocumentationProvider>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Eliminar $name'),
        content: Text(
          folder
              ? 'Se eliminará esta carpeta y TODO su contenido, incluidos documentos y subcarpetas. ¿Confirmás la eliminación?'
              : 'El documento dejará de estar disponible para todo el grupo. ¿Confirmás la eliminación?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.delete(id, folder);
  }

  @override
  Widget build(BuildContext context) {
    final DocumentationProvider p = context.watch<DocumentationProvider>();
    final List<DocumentFolder> folders = p.memberId == null
        ? p.data.folders
              .where((DocumentFolder f) => f.parentId == p.folderId)
              .toList()
        : <DocumentFolder>[];
    final List<DocumentFolder> current = p.data.folders
        .where((DocumentFolder f) => f.id == p.folderId)
        .toList();
    final bool disabled = p.loading || p.saving;
    return PopScope<void>(
      canPop: !handlesSystemBack || (!p.canGoBack && onExit == null),
      onPopInvokedWithResult: (bool didPop, void result) {
        if (didPop || !handlesSystemBack) return;
        if (p.canGoBack) {
          p.goBack();
        } else {
          onExit?.call();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: onExit == null,
          title: const Text('Documentación'),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  groupSelector ??
                      Text(
                        groupName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  Row(
                    children: <Widget>[
                      if (p.folderId != null)
                        IconButton(
                          tooltip: 'Subir un nivel',
                          onPressed: disabled
                              ? null
                              : () => p.navigate(
                                  current.isEmpty
                                      ? null
                                      : current.first.parentId,
                                ),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                      Expanded(child: Text(p.location(p.folderId))),
                      TextButton(
                        onPressed: disabled ? null : () => p.navigate(null),
                        child: const Text('Raíz'),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int?>(p.memberId),
                    initialValue:
                        p.data.members.any(
                          (DocumentMember m) => m.id == p.memberId,
                        )
                        ? p.memberId
                        : 0,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar integrante (todas las subcarpetas)',
                    ),
                    items: <DropdownMenuItem<int>>[
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('Todos'),
                      ),
                      for (final DocumentMember m in p.data.members)
                        DropdownMenuItem<int>(value: m.id, child: Text(m.name)),
                    ],
                    onChanged: disabled
                        ? null
                        : (int? id) => p.filter(id == 0 ? null : id),
                  ),
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: disabled
                            ? null
                            : () => _folder(context, null),
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('Nueva carpeta'),
                      ),
                      TextButton.icon(
                        onPressed: disabled ? null : () => _edit(context, null),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Subir archivo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (p.saving) const LinearProgressIndicator(),
            if (p.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  p.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            Expanded(
              child: p.loading
                  ? const Center(child: CircularProgressIndicator())
                  : p.error != null &&
                        p.data.documents.isEmpty &&
                        p.data.folders.isEmpty
                  ? Center(
                      child: TextButton(
                        onPressed: p.load,
                        child: const Text('Reintentar'),
                      ),
                    )
                  : folders.isEmpty && p.data.documents.isEmpty
                  ? Center(
                      child: Text(
                        p.memberId == null
                            ? 'Esta carpeta está vacía.'
                            : 'No hay documentos para este integrante.',
                      ),
                    )
                  : ListView(
                      children: <Widget>[
                        for (final DocumentFolder folder in folders)
                          ListTile(
                            leading: const Icon(
                              Icons.folder,
                              color: AppColors.primary,
                            ),
                            title: Text(folder.name),
                            onTap: disabled
                                ? null
                                : () => p.navigate(folder.id),
                            trailing: PopupMenuButton<String>(
                              enabled: !disabled,
                              onSelected: (String action) {
                                if (action == 'rename') {
                                  _folder(context, folder);
                                } else {
                                  _delete(
                                    context,
                                    folder.id,
                                    folder.name,
                                    true,
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'rename',
                                      child: Text('Renombrar'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                            ),
                          ),
                        for (final FamilyDocument document in p.data.documents)
                          ListTile(
                            leading: Icon(
                              document.isPdf
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.image_outlined,
                            ),
                            title: Text(document.name),
                            subtitle: Text(
                              '${document.memberName ?? 'Sin integrante'}${p.memberId == null ? '' : '\n${p.location(document.folderId)}'}',
                            ),
                            onTap: disabled
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (BuildContext context) =>
                                          DocumentPreviewScreen(
                                            service: p.service,
                                            groupId: p.groupId,
                                            document: document,
                                          ),
                                    ),
                                  ),
                            trailing: PopupMenuButton<String>(
                              enabled: !disabled,
                              onSelected: (String action) {
                                if (action == 'edit') {
                                  _edit(context, document);
                                } else {
                                  _delete(
                                    context,
                                    document.id,
                                    document.name,
                                    false,
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Text(
                                        'Editar / mover / reemplazar',
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
