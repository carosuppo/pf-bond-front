import 'package:bond_front/features/point_of_interest/models/point_of_interest_request.dart';
import 'package:bond_front/features/point_of_interest/widgets/point_of_interest_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('temporal exige vigencia, permite nombre opcional y cancela', (
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
            createTemporary: true,
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

    await tester.ensureVisible(find.text('Registrar'));
    await tester.tap(find.text('Registrar'));
    await tester.pump();
    expect(find.text('Elegí cuánto tiempo estará disponible.'), findsOneWidget);
    expect(submitted, isNull);

    await tester.tap(find.byKey(const ValueKey('temporary-duration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hora').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(submitted?.name, isEmpty);
    expect(submitted?.isTemporary, isTrue);
    expect(submitted?.durationMinutes, 60);
    expect(closed, isTrue);
  });

  testWidgets('cancelar descarta el borrador temporal sin crearlo', (
    tester,
  ) async {
    var createCalls = 0;
    var closed = false;
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PointOfInterestEditor(
            scrollController: scrollController,
            selectedLocation: const LatLng(-34.6, -58.4),
            createTemporary: true,
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
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(createCalls, 0);
  });
}
