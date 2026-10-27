import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/features/documentation/screens/documentation_group_screen.dart';
import 'package:bond_front/features/documentation/screens/documentation_screen.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/group/widgets/group_selector_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'documentation_test.dart' show FakeApi;

class NavigationGroups extends GroupProvider {
  NavigationGroups(FakeApi api)
    : super(GroupService(api), AppPreferencesService()) {
    groups = <GetGroupsResponseModel>[
      GetGroupsResponseModel(id: 1, name: 'Familia'),
      GetGroupsResponseModel(id: 2, name: 'Otro grupo'),
    ];
    activeGroup = groups.first;
  }
  @override
  Future<void> selectGroup(GetGroupsResponseModel group) async {
    activeGroup = group;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'Atrás del sistema recorre carpetas y luego la pantalla anterior',
    (WidgetTester tester) async {
      final FakeApi api = FakeApi();
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const DocumentationScreen(
                            groupId: 1,
                            groupName: 'Familia',
                          ),
                    ),
                  ),
                  child: const Text('Abrir documentos'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir documentos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estudios'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.requests.last, contains('folderId=folder'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.requests.last, '/group/1/documentation');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Abrir documentos'), findsOneWidget);
    },
  );

  testWidgets(
    'cambia de grupo desde documentos y reinicia carpeta e historial',
    (WidgetTester tester) async {
      final FakeApi api = FakeApi();
      final NavigationGroups groups = NavigationGroups(api);
      int exits = 0;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: api),
            ChangeNotifierProvider<GroupProvider>.value(value: groups),
          ],
          child: MaterialApp(
            home: DocumentationGroupScreen(
              isActive: true,
              onExit: () => exits++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GroupSelectorButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otro grupo'));
      await tester.pumpAndSettle();
      expect(groups.activeGroup!.id, 2);
      expect(api.requests.last, '/group/2/documentation');
      expect(find.text('Salud'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(exits, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Atrás cierra el selector antes de retroceder de carpeta', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi();
    final NavigationGroups groups = NavigationGroups(api);
    int exits = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<GroupProvider>.value(value: groups),
        ],
        child: MaterialApp(
          home: DocumentationGroupScreen(isActive: true, onExit: () => exits++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salud'));
    await tester.pumpAndSettle();
    final int count = api.requests.length;
    await tester.tap(find.byType(GroupSelectorButton));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Otro grupo'), findsNothing);
    expect(api.requests.length, count);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(api.requests.last, '/group/1/documentation');
  });

  testWidgets('una pestaña de documentos inactiva no intercepta Atrás', (
    WidgetTester tester,
  ) async {
    final FakeApi api = FakeApi();
    int exits = 0;
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api,
        child: MaterialApp(
          home: DocumentationScreen(
            groupId: 1,
            groupName: 'Familia',
            handlesSystemBack: false,
            onExit: () => exits++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salud'));
    await tester.pumpAndSettle();
    final int count = api.requests.length;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(api.requests.length, count);
    expect(exits, 0);
  });

  testWidgets(
    'Atrás vuelve a la carpeta visitada incluso después de saltar a raíz',
    (WidgetTester tester) async {
      final FakeApi api = FakeApi();
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: const MaterialApp(
            home: DocumentationScreen(groupId: 1, groupName: 'Familia'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estudios'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Raíz'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.requests.last, contains('folderId=child'));
    },
  );
}
