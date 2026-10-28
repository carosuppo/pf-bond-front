import 'dart:convert';
import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/documentation/models/documentation_models.dart';
import 'package:bond_front/features/documentation/providers/documentation_provider.dart';
import 'package:bond_front/features/documentation/screens/documentation_screen.dart';
import 'package:bond_front/features/documentation/services/documentation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class FakeApi extends ApiClient {
  FakeApi() : super(SessionStorageService());
  final List<String> requests = <String>[];
  final List<String> deletes = <String>[];
  Map<String, String>? submitted;
  http.MultipartFile? uploaded;
  bool fail = false, removed = false;
  final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a0S8AAAAASUVORK5CYII=',
  );
  @override
  Future<Map<String, dynamic>> authenticatedGet(String path) async {
    requests.add(path);
    if (fail) throw Exception('No pertenecés a este grupo.');
    if (path.endsWith('/status')) {
      return <String, dynamic>{
        'version': 1,
        'mimeType': path.contains('/pdf/') ? 'application/pdf' : 'image/png',
      };
    }
    return <String, dynamic>{
      'folders': removed
          ? <Map<String, String>>[]
          : <Map<String, String?>>[
              <String, String?>{
                'id': 'folder',
                'name': 'Salud',
                'parentId': null,
              },
              <String, String?>{
                'id': 'child',
                'name': 'Estudios',
                'parentId': 'folder',
              },
            ],
      'members': <Map<String, dynamic>>[
        <String, dynamic>{'id': 2, 'name': 'Ana'},
      ],
      'documents': removed || !path.contains('memberId=2')
          ? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'doc',
                'name': 'Análisis',
                'memberName': 'Ana',
                'memberId': 2,
                'folderId': 'child',
                'mimeType': 'image/png',
              },
            ],
    };
  }

  @override
  Future<void> authenticatedDelete(String path) async {
    deletes.add(path);
    if (fail) throw Exception('Error al eliminar');
    removed = true;
  }

  @override
  Future<Map<String, dynamic>> authenticatedMultipart(
    String method,
    String path,
    Map<String, String> fields, {
    http.MultipartFile? file,
  }) async {
    requests.add('$method $path');
    submitted = fields;
    uploaded = file;
    return <String, dynamic>{};
  }

  @override
  Future<Uint8List> authenticatedBytes(String path) async {
    requests.add(path);
    if (fail) throw Exception('Acceso revocado');
    return png;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> open(WidgetTester tester, FakeApi api) async {
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api,
        child: const MaterialApp(
          home: DocumentationScreen(groupId: 1, groupName: 'Familia'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('navega carpetas y vuelve a raíz', (WidgetTester tester) async {
    final FakeApi api = FakeApi();
    await open(tester, api);
    expect(find.text('Salud'), findsOneWidget);
    expect(find.text('Estudios'), findsNothing);
    await tester.tap(find.text('Salud'));
    await tester.pumpAndSettle();
    expect(api.requests.last, contains('folderId=folder'));
    expect(find.text('Estudios'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Raíz'));
    await tester.pumpAndSettle();
    expect(api.requests.last, '/group/1/documentation');
  });
  testWidgets(
    'cancelar borrado conserva contenido; confirmar advierte y elimina',
    (WidgetTester tester) async {
      final FakeApi api = FakeApi();
      await open(tester, api);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TODO su contenido'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.deletes, isEmpty);
      expect(find.text('Salud'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(api.deletes.single, '/group/1/documentation/folders/folder');
      expect(find.text('Esta carpeta está vacía.'), findsOneWidget);
    },
  );
  testWidgets('filtro incluye ubicación de subcarpetas y error de revocación', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi();
    await open(tester, api);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    expect(api.requests.last, contains('memberId=2'));
    expect(find.textContaining('Raíz / Salud / Estudios'), findsOneWidget);
    api.fail = true;
    await tester.tap(find.widgetWithText(TextButton, 'Raíz'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pertenecés'), findsOneWidget);
    expect(find.text('Análisis'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'formulario exige nombre y archivo pero permite omitir integrante',
    (WidgetTester tester) async {
      final FakeApi api = FakeApi();
      await open(tester, api);
      await tester.tap(find.text('Subir archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresá un nombre.'), findsOneWidget);
      expect(find.text('Seleccioná un integrante.'), findsNothing);
      expect(api.submitted, isNull);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Documento general',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Seleccioná un archivo.'), findsOneWidget);
      const MethodChannel channel = MethodChannel('bond/documents');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (MethodCall call) async => <String, dynamic>{
              'name': 'general.pdf',
              'mimeType': 'application/pdf',
              'bytes': Uint8List.fromList(utf8.encode('%PDF-1.7')),
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.tap(find.text('Seleccionar archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(api.submitted?['memberId'], '');
      expect(api.submitted?['name'], 'Documento general');
    },
  );
  test(
    'documento sin integrante se interpreta y edición permite desasociarlo',
    () async {
      final FamilyDocument document = FamilyDocument.fromJson(<String, dynamic>{
        'id': 'doc',
        'name': 'General',
        'memberId': null,
        'memberName': null,
        'mimeType': 'application/pdf',
        'folderId': null,
      });
      expect(document.memberId, isNull);
      expect(document.memberName, isNull);
      final FakeApi api = FakeApi();
      await DocumentationService(
        api,
      ).save(1, 'General', null, null, null, 'doc');
      expect(api.requests.single, 'PATCH /group/1/documentation/documents/doc');
      expect(api.submitted?['memberId'], '');
    },
  );
  test(
    'reemplazo usa PATCH misma identidad y envía destino raíz explícito',
    () async {
      final FakeApi api = FakeApi();
      final DocumentationService service = DocumentationService(api);
      await service.save(
        1,
        ' DNI ',
        2,
        null,
        SelectedDocumentFile(
          'dni.pdf',
          'application/pdf',
          Uint8List.fromList(<int>[37, 80, 68, 70]),
        ),
        'doc',
      );
      expect(api.requests.single, 'PATCH /group/1/documentation/documents/doc');
      expect(api.submitted, <String, String>{
        'name': 'DNI',
        'memberId': '2',
        'folderId': '',
      });
      expect(api.uploaded?.contentType.toString(), 'application/pdf');
    },
  );
  test('selector cancelado no produce archivo y valida límite', () async {
    final DocumentationService service = DocumentationService(FakeApi());
    const MethodChannel channel = MethodChannel('bond/documents');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
    expect(await service.pick(), isNull);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (MethodCall call) async => <String, dynamic>{
            'name': 'big.pdf',
            'mimeType': 'application/pdf',
            'bytes': Uint8List(10485761),
          },
        );
    await expectLater(service.pick(), throwsException);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'vista PDF e imagen descargan nuevamente y pierden acceso al revocar',
    () async {
      final FakeApi api = FakeApi();
      final DocumentationService service = DocumentationService(api);
      const FamilyDocument image = FamilyDocument(
        id: 'image',
        name: 'Imagen',
        memberName: 'Ana',
        mimeType: 'image/png',
        folderId: null,
        memberId: 2,
      );
      expect((await service.preview(1, image, 0)).image, api.png);
      const MethodChannel channel = MethodChannel('bond/documents');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (MethodCall call) async => <String, dynamic>{
              'image': api.png,
              'pages': 2,
            },
          );
      const FamilyDocument pdf = FamilyDocument(
        id: 'pdf',
        name: 'PDF',
        memberName: 'Ana',
        mimeType: 'application/pdf',
        folderId: null,
        memberId: 2,
      );
      expect((await service.preview(1, pdf, 1)).pages, 2);
      api.fail = true;
      await expectLater(service.preview(1, pdf, 0), throwsException);
      expect(
        api.requests
            .where((String path) => path.contains('/content?version='))
            .length,
        2,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test('fallo de borrado informa error y conserva listado', () async {
    final FakeApi api = FakeApi();
    final DocumentationProvider p = DocumentationProvider(
      DocumentationService(api),
      1,
    );
    await p.load();
    api.fail = true;
    expect(await p.delete('folder', true), isFalse);
    expect(p.data.folders, hasLength(2));
    expect(p.error, contains('Error al eliminar'));
    p.dispose();
  });
}
