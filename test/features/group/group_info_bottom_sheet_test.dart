import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/auth/models/auth_response.dart';
import 'package:bond_front/features/auth/models/user_model.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_member_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/group/widgets/group_info_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeGroupService extends GroupService {
  _FakeGroupService() : super(ApiClient(SessionStorageService()));

  int updateCalls = 0;
  int? updatedMemberId;
  RoleEnum? updatedRole;

  @override
  Future<void> updateMemberRole({
    required int memberId,
    required RoleEnum role,
  }) async {
    updateCalls++;
    updatedMemberId = memberId;
    updatedRole = role;
  }
}

const _groupWithMember = GetGroupResponseModel(
  id: 1,
  name: 'Grupo',
  description: null,
  shareLocationMandatorily: false,
  invitationCode: 'ABC123',
  members: [
    GetMemberResponseModel(
      id: 10,
      idUser: 1,
      name: 'Administrador',
      role: RoleEnum.admin,
    ),
    GetMemberResponseModel(
      id: 11,
      idUser: 2,
      name: 'Miembro de prueba',
      role: RoleEnum.member,
    ),
  ],
);

const _groupWithTwoAdmins = GetGroupResponseModel(
  id: 1,
  name: 'Grupo',
  description: null,
  shareLocationMandatorily: false,
  invitationCode: 'ABC123',
  members: [
    GetMemberResponseModel(
      id: 10,
      idUser: 1,
      name: 'Administrador actual',
      role: RoleEnum.admin,
    ),
    GetMemberResponseModel(
      id: 11,
      idUser: 2,
      name: 'Administrador de prueba',
      role: RoleEnum.admin,
    ),
  ],
);

const _groupWithOnlyAdmin = GetGroupResponseModel(
  id: 1,
  name: 'Grupo',
  description: null,
  shareLocationMandatorily: false,
  invitationCode: 'ABC123',
  members: [
    GetMemberResponseModel(
      id: 10,
      idUser: 1,
      name: 'Administrador actual',
      role: RoleEnum.admin,
    ),
  ],
);

AuthProvider _authProvider() {
  final storage = SessionStorageService();
  final authProvider = AuthProvider(AuthService(ApiClient(storage), storage));
  authProvider.authResponse = AuthResponse(
    sessionToken: 'token',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    user: UserModel(
      id: 1,
      name: 'Administrador actual',
      email: 'admin@example.com',
      locationId: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  return authProvider;
}

Future<void> _pumpGroupInfo(
  WidgetTester tester, {
  required GetGroupResponseModel group,
  required _FakeGroupService service,
}) async {
  final groupProvider = GroupProvider(service, AppPreferencesService())
    ..groupDetails = group;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider()),
        ChangeNotifierProvider.value(value: groupProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: GroupInfoBottomSheet(
            group: group,
            scrollController: ScrollController(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openRoleMenu(WidgetTester tester, Finder roleBadge) async {
  await tester.ensureVisible(roleBadge);
  await tester.tap(roleBadge);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('assigns the administrator role after confirmation', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    await _openRoleMenu(tester, find.text('Miembro'));
    await tester.tap(find.text('Administrador').last);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar cambio de rol'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(service.updateCalls, 1);
    expect(service.updatedMemberId, 11);
    expect(service.updatedRole, RoleEnum.admin);
  });

  testWidgets('revokes the administrator role after confirmation', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithTwoAdmins, service: service);

    await _openRoleMenu(tester, find.text('Administrador').at(1));
    await tester.tap(find.text('Miembro').last);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar cambio de rol'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(service.updateCalls, 1);
    expect(service.updatedMemberId, 11);
    expect(service.updatedRole, RoleEnum.member);
  });

  testWidgets('cancels a role change from the confirmation dialog', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    await _openRoleMenu(tester, find.text('Miembro'));
    await tester.tap(find.text('Administrador').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar cambio de rol'), findsNothing);
    expect(service.updateCalls, 0);
  });

  testWidgets('cancels a role change when the dialog is popped', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    await _openRoleMenu(tester, find.text('Miembro'));
    await tester.tap(find.text('Administrador').last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Confirmar cambio de rol'), findsNothing);
    expect(service.updateCalls, 0);
  });

  testWidgets('disables revoking the only administrator role', (tester) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithOnlyAdmin, service: service);

    await _openRoleMenu(tester, find.text('Administrador'));

    final memberOption = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuItem<RoleEnum> &&
          widget.value == RoleEnum.member &&
          !widget.enabled,
    );

    expect(memberOption, findsOneWidget);
    await tester.tap(find.text('Miembro').last);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar cambio de rol'), findsNothing);
    expect(service.updateCalls, 0);
  });
}
