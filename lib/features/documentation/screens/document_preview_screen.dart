import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/documentation_models.dart';
import '../services/documentation_service.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final DocumentationService service;
  final int groupId;
  final FamilyDocument document;
  const DocumentPreviewScreen({
    super.key,
    required this.service,
    required this.groupId,
    required this.document,
  });
  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen>
    with WidgetsBindingObserver {
  DocumentPreview? _preview;
  String? _error;
  int _page = 0, _generation = 0;
  bool _loading = false;
  bool _checking = false, _suspended = false;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
      if (!_checking) _load(revalidate: true);
    });
  }

  @override
  void dispose() {
    _generation++;
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _evict();
    super.dispose();
  }

  void _evict() {
    if (_preview != null) MemoryImage(_preview!.image).evict();
    _preview = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _refresh?.cancel();
    if (state == AppLifecycleState.resumed) {
      _load(revalidate: true);
    } else {
      _generation++;
      setState(() {
        // Keep only the in-memory preview, hidden until access is revalidated.
        if (_preview != null) MemoryImage(_preview!.image).evict();
        _suspended = true;
        _loading = false;
        _checking = false;
      });
    }
    if (state == AppLifecycleState.resumed) {
      _refresh = Timer.periodic(const Duration(seconds: 30), (Timer timer) {
        if (!_checking) _load(revalidate: true);
      });
    }
  }

  Future<void> _load({bool revalidate = false}) async {
    final int generation = ++_generation;
    setState(() {
      if (!revalidate) _evict();
      _loading = _preview == null;
      _checking = true;
      _error = null;
    });
    try {
      final DocumentStatus status = await widget.service.status(
        widget.groupId,
        widget.document.id,
      );
      if (!mounted || generation != _generation) return;
      if (revalidate && _preview?.status.version == status.version) {
        setState(() => _suspended = false);
        return;
      }
      setState(() {
        _evict();
        _loading = true;
      });
      final DocumentPreview preview = await widget.service.preview(
        widget.groupId,
        widget.document,
        _page,
        checkedStatus: status,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _preview = preview;
          _suspended = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _evict();
          _error = e.toString();
          _suspended = false;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text(widget.document.name)),
    body: Column(
      children: <Widget>[
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _preview != null && !_suspended
              ? InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      _preview!.image,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stack,
                          ) => const Text('No se pudo visualizar el archivo.'),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _error ??
                            'Vista protegida. Volvé a abrir el documento.',
                      ),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
        ),
        if (_preview?.status.isPdf == true && !_suspended)
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: 'Página anterior',
                  onPressed: _page == 0 || _loading
                      ? null
                      : () {
                          _page--;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_page + 1} / ${_preview!.pages}'),
                IconButton(
                  tooltip: 'Página siguiente',
                  onPressed: _page + 1 >= _preview!.pages || _loading
                      ? null
                      : () {
                          _page++;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
