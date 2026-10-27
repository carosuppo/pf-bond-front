import 'package:flutter/foundation.dart';
import '../models/documentation_models.dart';
import '../services/documentation_service.dart';

class DocumentationProvider extends ChangeNotifier {
  final DocumentationService service;
  final int groupId;
  DocumentationProvider(this.service, this.groupId);
  DocumentationListing data = const DocumentationListing([], [], []);
  String? folderId;
  int? memberId;
  String? error;
  bool loading = false, saving = false;
  bool _disposed = false;
  int _generation = 0;
  final List<String?> _folderHistory = <String?>[];
  bool get canGoBack => _folderHistory.isNotEmpty;

  Future<void> goBack() async {
    if (!canGoBack) return;
    folderId = _folderHistory.removeLast();
    memberId = null;
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  Future<void> load() async {
    final int generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final DocumentationListing result = await service.list(
        groupId,
        folderId,
        memberId,
      );
      if (!_disposed && generation == _generation) data = result;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e.toString();
        data = const DocumentationListing([], [], []);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> navigate(String? id) {
    if (id != folderId) _folderHistory.add(folderId);
    folderId = id;
    memberId = null;
    return load();
  }

  Future<void> filter(int? id) {
    memberId = id;
    return load();
  }

  String location(String? id) {
    final List<String> parts = <String>[];
    final Set<String> visited = <String>{};
    while (id != null && visited.add(id)) {
      final List<DocumentFolder> found = data.folders
          .where((DocumentFolder f) => f.id == id)
          .toList();
      if (found.isEmpty) break;
      parts.insert(0, found.first.name);
      id = found.first.parentId;
    }
    return <String>['Raíz', ...parts].join(' / ');
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (saving) return false;
    saving = true;
    error = null;
    notifyListeners();
    try {
      await action();
      if (!_disposed) await load();
      return true;
    } catch (e) {
      if (!_disposed) error = e.toString();
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(
    String name,
    int? member,
    String? destination,
    SelectedDocumentFile? file,
    String? id,
  ) =>
      _mutate(() => service.save(groupId, name, member, destination, file, id));
  Future<bool> saveFolder(String name, String? id) =>
      _mutate(() => service.folder(groupId, name, folderId, id));
  Future<bool> delete(String id, bool folder) =>
      _mutate(() => service.delete(groupId, id, folder));
}
