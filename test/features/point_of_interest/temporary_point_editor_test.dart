import 'package:bond_front/features/point_of_interest/models/point_of_interest_request.dart';
import 'package:bond_front/features/point_of_interest/widgets/point_of_interest_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('el formulario permite seleccionar vigencia y registrar', (
    tester,
  ) async {
    CreatePointOfInterestRequest? submitted;
    var closed = false;
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointOfInterestEditor(
            scrollController: scrollController,
            selectedLocation: const LatLng(-34.6, -58.4),
            onLocationChanged: (_) {},
            onRadiusChanged: (_) {},
            onColorChanged: (_) {},
            onCreate: (request) async {
              submitted = request;
              return true;
            },
            onClosed: () => closed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('poi-validity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 horas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(submitted?.validity, PointOfInterestValidity.twelveHours);
    expect(closed, isTrue);
  });

  testWidgets('cancelar descarta el borrador temporal sin crearlo', (
    tester,
  ) async {
    var createCalls = 0;
    var closed = false;
    final editorKey = GlobalKey<PointOfInterestEditorState>();
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointOfInterestEditor(
            key: editorKey,
            scrollController: scrollController,
            selectedLocation: const LatLng(-34.6, -58.4),
            onLocationChanged: (_) {},
            onRadiusChanged: (_) {},
            onColorChanged: (_) {},
            onCreate: (_) async {
              createCalls++;
              return true;
            },
            onClosed: () => closed = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Borrador');
    final close = editorKey.currentState!.requestClose();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await close;

    expect(closed, isTrue);
    expect(createCalls, 0);
  });
}
