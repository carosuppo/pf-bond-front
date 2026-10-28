import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';
import '../models/documentation_models.dart';

class DocumentationService {
  final ApiClient api;
  static const MethodChannel _channel = MethodChannel('bond/documents');
  DocumentationService(this.api);
  String _base(int groupId) => '/group/$groupId/documentation';
  Future<DocumentationListing> list(
    int groupId,
    String? folderId,
    int? memberId,
  ) async {
    final Map<String, String> query = <String, String>{
      'folderId': ?folderId,
      if (memberId != null) 'memberId': '$memberId',
    };
    final String suffix = query.isEmpty
        ? ''
        : '?${Uri(queryParameters: query).query}';
    return DocumentationListing.fromJson(
      await api.authenticatedGet('${_base(groupId)}$suffix'),
    );
  }

  Future<void> save(
    int groupId,
    String name,
    int? memberId,
    String? folderId,
    SelectedDocumentFile? file,
    String? id,
  ) async {
    await api.authenticatedMultipart(
      id == null ? 'POST' : 'PATCH',
      '${_base(groupId)}/documents${id == null ? '' : '/$id'}',
      <String, String>{
        'name': name.trim(),
        'memberId': memberId?.toString() ?? '',
        'folderId': folderId ?? '',
      },
      file: file == null
          ? null
          : http.MultipartFile.fromBytes(
              'file',
              file.bytes,
              filename: file.name,
              contentType: MediaType.parse(file.mimeType),
            ),
    );
  }

  Future<void> folder(
    int groupId,
    String name,
    String? parentId,
    String? id,
  ) async {
    if (id == null) {
      await api.authenticatedPost('${_base(groupId)}/folders', <String, String>{
        'name': name.trim(),
        'parentId': ?parentId,
      });
    } else {
      await api.authenticatedPatch(
        '${_base(groupId)}/folders/$id',
        <String, String>{'name': name.trim()},
      );
    }
  }

  Future<void> delete(int groupId, String id, bool folder) =>
      api.authenticatedDelete(
        '${_base(groupId)}/${folder ? 'folders' : 'documents'}/$id',
      );
  Future<SelectedDocumentFile?> pick() async {
    final Map<String, dynamic>? result = await _channel
        .invokeMapMethod<String, dynamic>('pick');
    if (result == null) return null;
    final SelectedDocumentFile file = SelectedDocumentFile(
      result['name'] as String,
      result['mimeType'] as String,
      result['bytes'] as Uint8List,
    );
    if (file.bytes.isEmpty || file.bytes.length > 10485760) {
      throw Exception('El archivo debe tener contenido y no superar 10 MB.');
    }
    if (!<String>[
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/webp',
    ].contains(file.mimeType)) {
      throw Exception('Usá PDF, JPG, PNG o WebP.');
    }
    return file;
  }

  Future<DocumentStatus> status(int groupId, String documentId) async =>
      DocumentStatus.fromJson(
        await api.authenticatedGet(
          '${_base(groupId)}/documents/$documentId/status',
        ),
      );

  Future<DocumentPreview> preview(
    int groupId,
    FamilyDocument document,
    int page, {
    DocumentStatus? checkedStatus,
  }) async {
    // Each page/open rechecks permissions. No downloaded bytes are stored on disk by Dart.
    final DocumentStatus current =
        checkedStatus ?? await status(groupId, document.id);
    final Uint8List bytes = await api.authenticatedBytes(
      '${_base(groupId)}/documents/${document.id}/content?version=${current.version}',
    );
    if (!current.isPdf) return DocumentPreview(bytes, 1, current);
    final Map<String, dynamic>? result = await _channel
        .invokeMapMethod<String, dynamic>('renderPdf', <String, dynamic>{
          'bytes': bytes,
          'page': page,
        });
    if (result == null) throw Exception('No se pudo abrir el PDF.');
    return DocumentPreview(
      result['image'] as Uint8List,
      result['pages'] as int,
      current,
    );
  }
}
