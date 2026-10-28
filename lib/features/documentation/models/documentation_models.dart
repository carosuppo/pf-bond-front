import 'dart:typed_data';

class FamilyDocument {
  final String id, name, mimeType;
  final String? memberName;
  final String? folderId;
  final int? memberId;
  const FamilyDocument({
    required this.id,
    required this.name,
    required this.memberName,
    required this.mimeType,
    required this.folderId,
    required this.memberId,
  });
  factory FamilyDocument.fromJson(Map<String, dynamic> json) => FamilyDocument(
    id: json['id'] as String,
    name: json['name'] as String,
    memberName: json['memberName'] as String?,
    mimeType: json['mimeType'] as String,
    folderId: json['folderId'] as String?,
    memberId: json['memberId'] as int?,
  );
  bool get isPdf => mimeType == 'application/pdf';
}

class DocumentFolder {
  final String id, name;
  final String? parentId;
  const DocumentFolder(this.id, this.name, this.parentId);
  factory DocumentFolder.fromJson(Map<String, dynamic> json) => DocumentFolder(
    json['id'] as String,
    json['name'] as String,
    json['parentId'] as String?,
  );
}

class DocumentMember {
  final int id;
  final String name;
  final bool active;
  const DocumentMember(this.id, this.name, {this.active = true});
}

class DocumentationListing {
  final List<FamilyDocument> documents;
  final List<DocumentFolder> folders;
  final List<DocumentMember> members;
  const DocumentationListing(this.documents, this.folders, this.members);
  factory DocumentationListing.fromJson(
    Map<String, dynamic> json,
  ) => DocumentationListing(
    (json['documents'] as List)
        .map(
          (row) =>
              FamilyDocument.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(),
    (json['folders'] as List)
        .map(
          (row) =>
              DocumentFolder.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(),
    (json['members'] as List).map((row) {
      final Map<String, dynamic> member = Map<String, dynamic>.from(row as Map);
      return DocumentMember(
        member['id'] as int,
        member['name'] as String,
        active: member['active'] as bool? ?? true,
      );
    }).toList(),
  );
}

class SelectedDocumentFile {
  final String name, mimeType;
  final Uint8List bytes;
  const SelectedDocumentFile(this.name, this.mimeType, this.bytes);
}

class DocumentStatus {
  final int version;
  final String mimeType;
  const DocumentStatus(this.version, this.mimeType);
  factory DocumentStatus.fromJson(Map<String, dynamic> json) =>
      DocumentStatus(json['version'] as int, json['mimeType'] as String);
  bool get isPdf => mimeType == 'application/pdf';
}

class DocumentPreview {
  final Uint8List image;
  final int pages;
  final DocumentStatus status;
  const DocumentPreview(this.image, this.pages, this.status);
}
