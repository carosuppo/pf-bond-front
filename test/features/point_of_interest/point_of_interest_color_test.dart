import 'package:bond_front/features/point_of_interest/models/point_of_interest.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest_color.dart';
import 'package:bond_front/features/point_of_interest/models/point_of_interest_request.dart';
import 'package:bond_front/features/point_of_interest/widgets/point_of_interest_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> jsonPoint() => {
  'id': 1,
  'name': 'Colegio',
  'radius': 100,
  'latitude': -34.6,
  'longitude': -58.3,
  'groupId': 3,
  'createdAt': '2026-08-01T00:00:00Z',
};
void main() {
  for (final color in PointOfInterestColor.values) {
    test('parses and serializes ${color.backendValue}', () {
      final point = PointOfInterest.fromJson({
        ...jsonPoint(),
        'color': color.backendValue,
      });
      expect(point.color, color);
      expect(color.label, isNotEmpty);
      expect(
        CreatePointOfInterestRequest(
          name: 'Colegio',
          radius: 100,
          latitude: 0,
          longitude: 0,
          color: color,
        ).toJson()['color'],
        color.backendValue,
      );
      expect(UpdatePointOfInterestRequest(color: color).toJson(), {
        'color': color.backendValue,
      });
    });
  }
  test(
    'missing color defaults to BLUE, but invalid supplied values are rejected',
    () {
      expect(
        PointOfInterest.fromJson(jsonPoint()).color,
        PointOfInterestColor.blue,
      );
      for (final value in ['PINK', '#000000', '', null, 123]) {
        expect(
          () => PointOfInterest.fromJson({...jsonPoint(), 'color': value}),
          throwsFormatException,
        );
      }
      expect(
        const CreatePointOfInterestRequest(
          name: 'Lugar',
          radius: 100,
          latitude: 0,
          longitude: 0,
        ).toJson()['color'],
        'BLUE',
      );
      expect(const UpdatePointOfInterestRequest(name: 'Lugar').toJson(), {
        'name': 'Lugar',
      });
    },
  );
  test('mapping defines exactly the seven requested colors in order', () {
    expect(PointOfInterestColor.values.map((c) => c.visualColor), [
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.grey,
      Colors.black,
    ]);
    expect(PointOfInterestColor.values.map((c) => c.backendValue), [
      'RED',
      'GREEN',
      'ORANGE',
      'BLUE',
      'PURPLE',
      'GREY',
      'BLACK',
    ]);
  });

  for (final editing in [false, true]) {
    testWidgets(
      'editor initial selection, preview callback and save (editing=$editing)',
      (tester) async {
        final scroll = ScrollController();
        final initial = editing
            ? PointOfInterest.fromJson({...jsonPoint(), 'color': 'RED'})
            : null;
        PointOfInterestColor? preview;
        Map<String, dynamic>? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PointOfInterestEditor(
                initial: initial,
                scrollController: scroll,
                selectedLocation: const LatLng(-34.6, -58.3),
                onLocationChanged: (_) {},
                onRadiusChanged: (_) {},
                onColorChanged: (color) => preview = color,
                onCreate: (request) async {
                  saved = request.toJson();
                  return true;
                },
                onUpdate: (request) async {
                  saved = request.toJson();
                  return true;
                },
                onClosed: () {},
              ),
            ),
          ),
        );
        expect(find.byType(ChoiceChip), findsNWidgets(7));
        final initiallySelected = tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .singleWhere((chip) => chip.selected);
        expect(
          (initiallySelected.label as Text).data,
          editing ? 'Rojo' : 'Azul',
        );
        if (!editing) {
          await tester.enterText(find.byType(TextFormField).first, 'Colegio');
        }
        await tester.tap(find.widgetWithText(ChoiceChip, 'Púrpura'));
        await tester.pump();
        expect(preview, PointOfInterestColor.purple);
        final button = find.widgetWithText(
          FilledButton,
          editing ? 'Guardar' : 'Registrar',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(saved!['color'], 'PURPLE');
        expect(saved!['radius'], 100);
        expect(saved!['latitude'], -34.6);
        expect(saved!['longitude'], -58.3);
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
      },
    );
  }
  testWidgets(
    'color-only change marks edit dirty and always keeps a selection',
    (tester) async {
      final key = GlobalKey<PointOfInterestEditorState>();
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointOfInterestEditor(
              key: key,
              initial: PointOfInterest.fromJson({
                ...jsonPoint(),
                'color': 'RED',
              }),
              scrollController: scroll,
              selectedLocation: const LatLng(-34.6, -58.3),
              onLocationChanged: (_) {},
              onRadiusChanged: (_) {},
              onColorChanged: (_) {},
              onClosed: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Púrpura'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Púrpura'));
      await tester.pump();
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((chip) => chip.selected),
        hasLength(1),
      );
      final close = key.currentState!.requestClose();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar cambios?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      await close;
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
    },
  );
}
