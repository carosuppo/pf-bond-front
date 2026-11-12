import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_filter_dropdown.dart';
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
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                top: 64,
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
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
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              Expanded(
                                child: _CompactFolderPath(
                                  path: p.location(p.folderId),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          AppFilterDropdown<int>(
                            label: 'Filtrar integrante (todas las subcarpetas)',
                            selectedValue:
                                p.data.members.any(
                                  (DocumentMember m) => m.id == p.memberId,
                                )
                                ? p.memberId!
                                : 0,
                            options: <AppFilterOption<int>>[
                              const AppFilterOption<int>(
                                value: 0,
                                label: 'Todos',
                              ),
                              for (final DocumentMember m in p.data.members)
                                AppFilterOption<int>(
                                  value: m.id,
                                  label: m.name,
                                ),
                            ],
                            enabled: !disabled,
                            onSelected: (int id) =>
                                p.filter(id == 0 ? null : id),
                          ),
                          Row(
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: disabled
                                    ? null
                                    : () => _folder(context, null),
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                ),
                                label: const Text('Nueva carpeta'),
                              ),
                              TextButton.icon(
                                onPressed: disabled
                                    ? null
                                    : () => _edit(context, null),
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
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                              children: <Widget>[
                                _DocumentationSection(
                                  title: 'Carpetas',
                                  child: folders.isEmpty
                                      ? const _DocumentationEmptyCard(
                                          message:
                                              'No hay carpetas en esta ubicación.',
                                        )
                                      : _DocumentationListCard(
                                          children: <Widget>[
                                            for (final folder
                                                in folders) ...<Widget>[
                                              if (folder.id != folders.first.id)
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                                  child: Divider(
                                                    height: 1,
                                                    color: AppColors.divider,
                                                  ),
                                                ),
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.folder,
                                                  color: AppColors.primary,
                                                ),
                                                title: Text(folder.name),
                                                onTap: disabled
                                                    ? null
                                                    : () =>
                                                          p.navigate(folder.id),
                                                trailing:
                                                    PopupMenuButton<String>(
                                                      enabled: !disabled,
                                                      onSelected:
                                                          (String action) {
                                                            if (action ==
                                                                'rename') {
                                                              _folder(
                                                                context,
                                                                folder,
                                                              );
                                                            } else {
                                                              _delete(
                                                                context,
                                                                folder.id,
                                                                folder.name,
                                                                true,
                                                              );
                                                            }
                                                          },
                                                      itemBuilder:
                                                          (
                                                            BuildContext
                                                            context,
                                                          ) =>
                                                              const <
                                                                PopupMenuEntry<
                                                                  String
                                                                >
                                                              >[
                                                                PopupMenuItem<
                                                                  String
                                                                >(
                                                                  value:
                                                                      'rename',
                                                                  child: Text(
                                                                    'Renombrar',
                                                                  ),
                                                                ),
                                                                PopupMenuItem<
                                                                  String
                                                                >(
                                                                  value:
                                                                      'delete',
                                                                  child: Text(
                                                                    'Eliminar',
                                                                  ),
                                                                ),
                                                              ],
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 24),
                                _DocumentationSection(
                                  title: 'Documentos',
                                  child: p.data.documents.isEmpty
                                      ? _DocumentationEmptyCard(
                                          message: p.memberId == null
                                              ? 'No hay documentos en esta ubicación.'
                                              : 'No hay documentos para este integrante.',
                                        )
                                      : _DocumentationListCard(
                                          children: <Widget>[
                                            for (final document
                                                in p
                                                    .data
                                                    .documents) ...<Widget>[
                                              if (document.id !=
                                                  p.data.documents.first.id)
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                                  child: Divider(
                                                    height: 1,
                                                    color: AppColors.divider,
                                                  ),
                                                ),
                                              ListTile(
                                                leading: Icon(
                                                  document.isPdf
                                                      ? Icons
                                                            .picture_as_pdf_outlined
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
                                                          builder:
                                                              (
                                                                BuildContext
                                                                context,
                                                              ) => DocumentPreviewScreen(
                                                                service:
                                                                    p.service,
                                                                groupId:
                                                                    p.groupId,
                                                                document:
                                                                    document,
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
                                                  itemBuilder:
                                                      (BuildContext context) =>
                                                          const <
                                                            PopupMenuEntry<
                                                              String
                                                            >
                                                          >[
                                                            PopupMenuItem<
                                                              String
                                                            >(
                                                              value: 'edit',
                                                              child: Text(
                                                                'Editar / mover / reemplazar',
                                                              ),
                                                            ),
                                                            PopupMenuItem<
                                                              String
                                                            >(
                                                              value: 'delete',
                                                              child: Text(
                                                                'Eliminar',
                                                              ),
                                                            ),
                                                          ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child:
                    groupSelector ??
                    Center(
                      child: Text(
                        groupName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentationSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DocumentationSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _DocumentationListCard extends StatelessWidget {
  final List<Widget> children;

  const _DocumentationListCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _DocumentationEmptyCard extends StatelessWidget {
  final String message;

  const _DocumentationEmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
      ),
    );
  }
}

class _CompactFolderPath extends StatelessWidget {
  final String path;

  const _CompactFolderPath({required this.path});

  @override
  Widget build(BuildContext context) {
    final TextStyle style = DefaultTextStyle.of(
      context,
    ).style.merge(const TextStyle(color: AppColors.mutedText));
    final TextDirection textDirection = Directionality.of(context);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final String displayPath = _pathThatFits(
          path,
          constraints.maxWidth,
          style,
          textDirection,
          textScaler,
        );

        return Text(
          displayPath,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }

  String _pathThatFits(
    String path,
    double maxWidth,
    TextStyle style,
    TextDirection textDirection,
    TextScaler textScaler,
  ) {
    if (!maxWidth.isFinite ||
        _textWidth(path, style, textDirection, textScaler) <= maxWidth) {
      return path;
    }

    final List<String> segments = path.split(' / ');
    final List<String> folders = segments.first == 'Raíz'
        ? segments.skip(1).toList()
        : segments;
    if (folders.isEmpty) return path;

    String compactPath = '.../${folders.last}';
    for (var start = folders.length - 2; start >= 0; start--) {
      final String candidate = '.../${folders.skip(start).join('/')}';
      if (_textWidth(candidate, style, textDirection, textScaler) > maxWidth) {
        break;
      }
      compactPath = candidate;
    }
    return compactPath;
  }

  double _textWidth(
    String value,
    TextStyle style,
    TextDirection textDirection,
    TextScaler textScaler,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }
}
