import 'package:bond_front/features/location/models/mandatory_group_location_action.dart';
import 'package:bond_front/features/location/widgets/mandatory_group_location_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra las dos opciones y explica la salida del grupo', (
    tester,
  ) async {
    Future<MandatoryGroupLocationAction?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                result = showMandatoryGroupLocationDialog(
                  context: context,
                  groupName: 'Familia',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ubicación obligatoria'), findsOneWidget);
    expect(find.text('Salir del grupo'), findsOneWidget);
    expect(find.text('Activar ubicación'), findsOneWidget);
    expect(
      find.textContaining('El grupo “Familia” obliga a compartir'),
      findsOneWidget,
    );
    expect(find.textContaining('debes salir del grupo'), findsOneWidget);

    await tester.tap(find.text('Salir del grupo'));
    await tester.pumpAndSettle();

    expect(await result, MandatoryGroupLocationAction.leaveGroup);
  });

  testWidgets('la opción de activar ubicación devuelve esa acción', (
    tester,
  ) async {
    Future<MandatoryGroupLocationAction?>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                result = showMandatoryGroupLocationDialog(
                  context: context,
                  groupName: 'Familia',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activar ubicación'));
    await tester.pumpAndSettle();

    expect(await result, MandatoryGroupLocationAction.activateLocation);
  });
}
