import 'dart:async';
import 'dart:convert';
import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/network/api_exception.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/documentation/models/documentation_models.dart';
import 'package:bond_front/features/documentation/screens/document_preview_screen.dart';
import 'package:bond_front/features/documentation/services/documentation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class PreviewApi extends ApiClient {
  PreviewApi() : super(SessionStorageService());
  int version = 1;
  String mimeType = 'image/png';
  int? deniedStatus;
  int checks = 0;
  final List<String> downloads = <String>[];
  Completer<Map<String, dynamic>>? pendingCheck;
  Completer<Uint8List>? pendingDownload;
  final Uint8List png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a0S8AAAAASUVORK5CYII=',
  );

  @override
  Future<Map<String, dynamic>> authenticatedGet(String path) async {
    expectSync(path, '/group/1/documentation/documents/doc/status');
    checks++;
    if (deniedStatus != null) {
      throw ApiException(
        'Acceso denegado o documento inexistente',
        statusCode: deniedStatus!,
      );
    }
    if (pendingCheck != null) return pendingCheck!.future;
    return <String, dynamic>{'version': version, 'mimeType': mimeType};
  }

  @override
  Future<Uint8List> authenticatedBytes(String path) async {
    downloads.add(path);
    if (pendingDownload != null) return pendingDownload!.future;
    return png;
  }
}

void main() {
  const FamilyDocument document = FamilyDocument(
    id: 'doc',
    name: 'Documento',
    memberName: null,
    mimeType: 'image/png',
    folderId: null,
    memberId: null,
  );

  Future<void> open(WidgetTester tester, PreviewApi api) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentPreviewScreen(
          service: DocumentationService(api),
          groupId: 1,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'descarga al abrir y solo consulta estado cada 30 segundos si no cambia la versión',
    (WidgetTester tester) async {
      final PreviewApi api = PreviewApi();
      await open(tester, api);
      expect(api.downloads, <String>[
        '/group/1/documentation/documents/doc/content?version=1',
      ]);
      expect(api.checks, 1);
      await tester.pump(const Duration(seconds: 29));
      expect(api.checks, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(api.checks, 3);
      expect(api.downloads, hasLength(1));
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('descarga una vez al cambiar versión y usa el tipo actualizado', (
    WidgetTester tester,
  ) async {
    final PreviewApi api = PreviewApi();
    await open(tester, api);
    const MethodChannel channel = MethodChannel('bond/documents');
    int renders = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          renders++;
          expect(call.method, 'renderPdf');
          return <String, dynamic>{'image': api.png, 'pages': 2};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    api.version = 2;
    api.mimeType = 'application/pdf';
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(api.downloads, hasLength(2));
    expect(api.downloads.last, endsWith('?version=2'));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(renders, 1);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(api.downloads, hasLength(2));
    expect(renders, 1);
  });

  for (final int statusCode in <int>[401, 403, 404]) {
    testWidgets(
      'retira contenido en memoria ante $statusCode sin otra descarga',
      (WidgetTester tester) async {
        final PreviewApi api = PreviewApi();
        await open(tester, api);
        api.deniedStatus = statusCode;
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(
          find.text('Acceso denegado o documento inexistente'),
          findsOneWidget,
        );
        expect(api.downloads, hasLength(1));
      },
    );
  }

  for (final bool changed in <bool>[false, true]) {
    testWidgets(
      'resumed consulta primero y ${changed ? 'descarga la nueva versión' : 'reutiliza la misma versión en memoria'}',
      (WidgetTester tester) async {
        final PreviewApi api = PreviewApi();
        await open(tester, api);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(find.byType(Image), findsNothing);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump(const Duration(seconds: 60));
        expect(api.checks, 1);
        api.pendingCheck = Completer<Map<String, dynamic>>();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(api.checks, 2);
        expect(api.downloads, hasLength(1));
        expect(find.byType(Image), findsNothing);
        api.version = changed ? 2 : 1;
        api.pendingCheck!.complete(<String, dynamic>{
          'version': api.version,
          'mimeType': api.mimeType,
        });
        api.pendingCheck = null;
        await tester.pumpAndSettle();
        expect(api.downloads, hasLength(changed ? 2 : 1));
        expect(find.byType(Image), findsOneWidget);
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(api.checks, 3);
        expect(api.downloads, hasLength(changed ? 2 : 1));
      },
    );
  }

  testWidgets('resumed no vuelve a mostrar el contenido si perdió acceso', (
    WidgetTester tester,
  ) async {
    final PreviewApi api = PreviewApi();
    await open(tester, api);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    api.deniedStatus = 403;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(
      find.text('Acceso denegado o documento inexistente'),
      findsOneWidget,
    );
    expect(api.downloads, hasLength(1));
  });

  testWidgets(
    'una comprobación lenta no parpadea ni se solapa con el siguiente intervalo',
    (WidgetTester tester) async {
      final PreviewApi api = PreviewApi();
      await open(tester, api);
      api.pendingCheck = Completer<Map<String, dynamic>>();
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(api.checks, 2);
      api.pendingCheck!.complete(<String, dynamic>{
        'version': 1,
        'mimeType': 'image/png',
      });
      api.pendingCheck = null;
      await tester.pumpAndSettle();
      expect(api.downloads, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 60));
      expect(api.checks, 2);
    },
  );

  testWidgets(
    'una descarga pendiente al suspender no restaura contenido después de revocar acceso',
    (WidgetTester tester) async {
      final PreviewApi api = PreviewApi();
      await open(tester, api);
      api.version = 2;
      api.pendingDownload = Completer<Uint8List>();
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(api.downloads, hasLength(2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      api.deniedStatus = 403;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      api.pendingDownload!.complete(api.png);
      api.pendingDownload = null;
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(
        find.text('Acceso denegado o documento inexistente'),
        findsOneWidget,
      );
    },
  );
}
