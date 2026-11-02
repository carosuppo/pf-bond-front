import 'package:bond_front/features/auth/widgets/password_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('toggles password visibility', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordTextField(controller: controller, label: 'Contraseña'),
        ),
      ),
    );

    EditableText textField = tester.widget(find.byType(EditableText));

    expect(textField.obscureText, isTrue);
    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    textField = tester.widget(find.byType(EditableText));

    expect(textField.obscureText, isFalse);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
  });
}
