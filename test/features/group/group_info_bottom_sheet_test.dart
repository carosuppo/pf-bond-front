import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/features/auth/models/auth_response.dart';
import 'package:bond_front/features/auth/models/user_model.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/auth/services/session_state_cleanup.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/models/get_member_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/group/widgets/group_info_bottom_sheet.dart';
import 'package:bond_front/features/location/widgets/group_info_sheet.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _NoopSessionStateCleanup implements SessionStateCleanup {
  @override
  Future<void> clear() async {}
}

class _TestPreferences extends AppPreferencesService {
  @override
  Future<int?> getActiveGroupId() async => null;

  @override
  Future<void> saveActiveGroupId(int groupId) async {}

  @override
  Future<void> clearActiveGroupId() async {}
}

class _FakeGroupService extends GroupService {
  _FakeGroupService() : super(ApiClient(SessionStorageService()));

  int updateCalls = 0;
  int deleteCalls = 0;
  int leaveCalls = 0;
  int? leftGroupId;
  int? updatedMemberId;
  RoleEnum? updatedRole;
  GetGroupResponseModel? groupToLoad;
  List<GetGroupsResponseModel> groupsToLoad = [];
  int getGroupCalls = 0;

  @override
  Future<void> deleteGroup({required int groupId}) async {
    deleteCalls++;
  }

  @override
  Future<void> leaveGroup({required int groupId}) async {
    leaveCalls++;
    leftGroupId = groupId;
  }

  @override
  Future<void> updateMemberRole({
    required int memberId,
    required RoleEnum role,
  }) async {
    updateCalls++;
    updatedMemberId = memberId;
    updatedRole = role;
  }

  @override
  Future<GetGroupResponseModel> getGroup({required int groupId}) async {
    getGroupCalls++;
    return groupToLoad!;
  }

  @override
  Future<List<GetGroupsResponseModel>> getGroups() async {
    return groupsToLoad;
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
  final apiClient = ApiClient(storage);
  final pushNotificationService = PushNotificationService(
    NotificationApiService(apiClient),
    AppPreferencesService(),
  );
  final authProvider = AuthProvider(
    AuthService(
      apiClient,
      storage,
      pushNotificationService,
      BackgroundLocationService(),
    ),
    _NoopSessionStateCleanup(),
  );
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

Future<GroupProvider> _pumpGroupInfo(
  WidgetTester tester, {
  required GetGroupResponseModel group,
  required _FakeGroupService service,
}) async {
  final groupProvider = GroupProvider(service, _TestPreferences())
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
  return groupProvider;
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

  testWidgets('refreshes member roles before opening the members list', (
    tester,
  ) async {
    const staleGroup = GetGroupResponseModel(
      id: 1,
      name: 'Grupo',
      description: null,
      shareLocationMandatorily: false,
      invitationCode: 'ABC123',
      members: [
        GetMemberResponseModel(
          id: 10,
          idUser: 1,
          name: 'Miembro actual',
          role: RoleEnum.member,
        ),
        GetMemberResponseModel(
          id: 11,
          idUser: 2,
          name: 'Admin de prueba',
          role: RoleEnum.member,
        ),
      ],
    );
    const freshGroup = GetGroupResponseModel(
      id: 1,
      name: 'Grupo',
      description: null,
      shareLocationMandatorily: false,
      invitationCode: 'ABC123',
      members: [
        GetMemberResponseModel(
          id: 10,
          idUser: 1,
          name: 'Miembro actual',
          role: RoleEnum.member,
        ),
        GetMemberResponseModel(
          id: 11,
          idUser: 2,
          name: 'Admin de prueba',
          role: RoleEnum.admin,
        ),
      ],
    );
    final service = _FakeGroupService()..groupToLoad = freshGroup;
    final groupProvider = GroupProvider(service, AppPreferencesService())
      ..groupDetails = staleGroup;
    final sheetController = DraggableScrollableController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _authProvider()),
          ChangeNotifierProvider.value(value: groupProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                GroupInfoSheet(
                  controller: sheetController,
                  group: staleGroup,
                  memberInfo: null,
                  memberInfoLoading: false,
                  pointsContent: const SizedBox.shrink(),
                  pointsCount: 0,
                  onScrollControllerChanged: (_) {},
                  onDragUpdate: (_) {},
                  onDragEnd: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Miembros'));
    await tester.tap(find.widgetWithText(ListTile, 'Miembros'));
    await tester.pumpAndSettle();

    expect(service.getGroupCalls, 1);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Miembro'), findsOneWidget);
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

  testWidgets('offers WhatsApp invitation to every group member', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    expect(find.text('Invitar por WhatsApp'), findsOneWidget);
    expect(find.byTooltip('Copiar código'), findsOneWidget);
  });

  testWidgets('cancels leaving a group without changing membership', (
    tester,
  ) async {
    final service = _FakeGroupService();
    final groupProvider = await _pumpGroupInfo(
      tester,
      group: _groupWithMember,
      service: service,
    );

    final leaveButton = find.byKey(const Key('leave-group-button'));
    await tester.ensureVisible(leaveButton);
    await tester.tap(leaveButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(service.leaveCalls, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(service.leaveCalls, 0);
    expect(groupProvider.groupDetails?.members.length, 2);
    expect(find.text('Miembro de prueba'), findsOneWidget);
  });

  testWidgets('places the leave button below every member card', (
    tester,
  ) async {
    final service = _FakeGroupService();
    final groupProvider = GroupProvider(service, _TestPreferences())
      ..groupDetails = _groupWithMember;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _authProvider()),
          ChangeNotifierProvider.value(value: groupProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GroupMembersBottomSheet(
              group: _groupWithMember,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final leaveButton = find.byKey(const Key('leave-group-button'));
    final memberCards = find.byType(Card);
    await tester.ensureVisible(leaveButton);

    expect(memberCards, findsNWidgets(2));
    final leaveButtonRect = tester.getRect(leaveButton);
    for (var index = 0; index < memberCards.evaluate().length; index++) {
      expect(
        leaveButtonRect.top,
        greaterThan(tester.getRect(memberCards.at(index)).bottom),
      );
    }
  });

  testWidgets('leaves a group with other members after confirmation', (
    tester,
  ) async {
    const otherGroup = GetGroupResponseModel(
      id: 2,
      name: 'Otro grupo',
      description: null,
      shareLocationMandatorily: false,
      invitationCode: 'DEF456',
      members: [],
    );
    final service = _FakeGroupService()
      ..groupsToLoad = [GetGroupsResponseModel(id: 2, name: 'Otro grupo')]
      ..groupToLoad = otherGroup;
    final groupProvider = await _pumpGroupInfo(
      tester,
      group: _groupWithMember,
      service: service,
    );

    final leaveButton = find.byKey(const Key('leave-group-button'));
    await tester.ensureVisible(leaveButton);
    await tester.tap(leaveButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandonar'));
    await tester.pumpAndSettle();

    expect(service.leaveCalls, 1);
    expect(service.leftGroupId, 1);
    expect(service.getGroupCalls, 1);
    expect(groupProvider.groups.map((group) => group.id), [2]);
    expect(groupProvider.activeGroup?.id, 2);
    expect(groupProvider.groupDetails?.id, 2);
  });

  testWidgets('warns and removes the group after its only member confirms', (
    tester,
  ) async {
    final service = _FakeGroupService();
    final groupProvider = await _pumpGroupInfo(
      tester,
      group: _groupWithOnlyAdmin,
      service: service,
    );

    final leaveButton = find.byKey(const Key('leave-group-button'));
    await tester.ensureVisible(leaveButton);
    await tester.tap(leaveButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sos el único miembro'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(service.leaveCalls, 0);
    expect(groupProvider.groupDetails?.members.length, 1);

    await tester.ensureVisible(leaveButton);
    await tester.tap(leaveButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandonar'));
    await tester.pumpAndSettle();

    expect(service.leaveCalls, 1);
    expect(service.leftGroupId, 1);
    expect(groupProvider.groupDetails, isNull);
  });

  testWidgets('asks for confirmation before deleting the group', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    final deleteButton = find.byKey(const Key('delete-group-button'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        '¿Querés eliminar "Grupo"? Se removerá a todos sus miembros y esta acción es definitiva.',
      ),
      findsOneWidget,
    );
    expect(service.deleteCalls, 0);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 1);
  });

  testWidgets('cancels group deletion from the cancel action', (tester) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    final deleteButton = find.byKey(const Key('delete-group-button'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(service.deleteCalls, 0);
  });

  testWidgets('cancels group deletion by tapping outside the dialog', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    final deleteButton = find.byKey(const Key('delete-group-button'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(service.deleteCalls, 0);
  });

  testWidgets('cancels group deletion when the back gesture dismisses dialog', (
    tester,
  ) async {
    final service = _FakeGroupService();
    await _pumpGroupInfo(tester, group: _groupWithMember, service: service);

    final deleteButton = find.byKey(const Key('delete-group-button'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(service.deleteCalls, 0);
  });
}
