import 'package:bond_front/core/routes/app_routes.dart';
import 'package:bond_front/core/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la ruta de creación de cuentas devuelve un resultado booleano', () {
    final Route<dynamic> route = AppRouter.onGenerateRoute(
      const RouteSettings(name: AppRoutes.createExpenseAccount),
    );

    expect(route, isA<MaterialPageRoute<bool?>>());
  });
}
