import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/preferences/app_preferences_service.dart';
import 'package:bond_front/core/routes/app_router.dart';
import 'package:bond_front/core/routes/app_routes.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/core/timezone/app_timezone.dart';
import 'package:bond_front/core/widgets/buttons/app_primary_button.dart';
import 'package:bond_front/features/auth/providers/auth_provider.dart';
import 'package:bond_front/features/auth/services/auth_service.dart';
import 'package:bond_front/features/auth/services/session_state_cleanup.dart';
import 'package:bond_front/features/event/models/create_event_model.request.dart';
import 'package:bond_front/features/event/models/event_model.response.dart';
import 'package:bond_front/features/event/providers/event_provider.dart';
import 'package:bond_front/features/event/screens/create_event_screen.dart';
import 'package:bond_front/features/event/screens/events_screen.dart';
import 'package:bond_front/features/event/services/event_service.dart';
import 'package:bond_front/features/event/widgets/create_event_form.dart';
import 'package:bond_front/features/event/widgets/event_calendar.dart';
import 'package:bond_front/features/event/widgets/event_details_modal.dart';
import 'package:bond_front/features/event/widgets/event_month_calendar.dart';
import 'package:bond_front/features/event/widgets/event_time_picker.dart';
import 'package:bond_front/features/group/models/get_group_model.response.dart';
import 'package:bond_front/features/group/models/get_groups_model.response.dart';
import 'package:bond_front/features/group/models/get_member_model.response.dart';
import 'package:bond_front/features/group/providers/group_provider.dart';
import 'package:bond_front/features/group/services/group_service.dart';
import 'package:bond_front/features/location/services/background_location_service.dart';
import 'package:bond_front/features/notification/services/notification_api_service.dart';
import 'package:bond_front/features/notification/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Cleanup implements SessionStateCleanup {
  @override
  Future<void> clear() async {}
}

class _Groups extends GroupProvider {
  _Groups(super.service, super.preferences);
  void switchTo(int id) {
    activeGroup = GetGroupsResponseModel(id: id, name: 'Grupo $id');
    notifyListeners();
  }
}

class _Service extends EventService {
  _Service() : super(ApiClient(SessionStorageService()));
  CreateEventRequestModel? saved;
  int? savedGroupId;

  @override
  Future<EventResponseModel> createEvent({
    required int groupId,
    required CreateEventRequestModel request,
  }) async {
    saved = request;
    savedGroupId = groupId;
    return EventResponseModel(
      id: 10,
      name: request.name,
      startAt: AppTimezone.argentinaToUtc(request.startAt),
      memberIds: request.memberIds,
    );
  }
}

class _Events extends EventProvider {
  _Events(super.service);
  final List<int> loadedGroups = <int>[];

  @override
  Future<void> loadEvents({required int groupId, int? year, int? month}) async {
    loadedGroups.add(groupId);
  }

  @override
  Future<void> ensureMonthLoaded({
    required int groupId,
    required int year,
    required int month,
  }) async {}
}

DateTime _date(int offset) {
  final DateTime now = AppTimezone.now();
  return DateTime(now.year, now.month, now.day + offset);
}

String _label(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

void _expectDay(DateTime? actual, DateTime expected) {
  expect(actual, isNotNull);
  expect(
    <int>[actual!.year, actual.month, actual.day],
    <int>[expected.year, expected.month, expected.day],
  );
}

void main() {
  setUpAll(AppTimezone.initialize);
  late _Service service;
  late _Events events;
  late _Groups groups;
  late AuthProvider auth;

  setUp(() {
    final SessionStorageService storage = SessionStorageService();
    final ApiClient api = ApiClient(storage);
    final AppPreferencesService preferences = AppPreferencesService();
    service = _Service();
    events = _Events(service);
    groups = _Groups(GroupService(api), preferences)
      ..activeGroup = GetGroupsResponseModel(id: 1, name: 'Familia')
      ..groups = <GetGroupsResponseModel>[
        GetGroupsResponseModel(id: 1, name: 'Familia'),
      ]
      ..groupDetails = const GetGroupResponseModel(
        id: 1,
        name: 'Familia',
        shareLocationMandatorily: false,
        invitationCode: 'ABC123',
        members: <GetMemberResponseModel>[
          GetMemberResponseModel(
            id: 7,
            idUser: 7,
            name: 'Invitado',
            role: RoleEnum.member,
          ),
          GetMemberResponseModel(
            id: 8,
            idUser: 8,
            name: 'Otro',
            role: RoleEnum.member,
          ),
        ],
      );
    auth = AuthProvider(
      AuthService(
        api,
        storage,
        PushNotificationService(NotificationApiService(api), preferences),
        BackgroundLocationService(),
      ),
      _Cleanup(),
    );
  });
  tearDown(() {
    events.dispose();
    groups.dispose();
    auth.dispose();
  });

  Future<void> mount(WidgetTester tester, Widget home) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GroupProvider>.value(value: groups),
          ChangeNotifierProvider<EventProvider>.value(value: events),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: home,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> form(WidgetTester tester, CreateEventForm child) async {
    await mount(
      tester,
      Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => Scaffold(body: child)),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Evento nuevo');
    await tester.ensureVisible(find.byType(AppPrimaryButton));
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();
  }

  Future<void> pick(
    WidgetTester tester,
    String field,
    DateTime date,
    TimeOfDay time,
  ) async {
    await tester.ensureVisible(find.text(field));
    await tester.tap(find.text(field));
    await tester.pumpAndSettle();
    EventMonthCalendar calendar = tester.widget<EventMonthCalendar>(
      find.byType(EventMonthCalendar),
    );
    calendar.onMonthChanged(DateTime(date.year, date.month));
    await tester.pumpAndSettle();
    calendar = tester.widget<EventMonthCalendar>(
      find.byType(EventMonthCalendar),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(EventMonthCalendar),
        matching: find.text('${date.day}'),
      ),
    );
    await tester.pumpAndSettle();
    // Exercise the existing picker callback, then its real confirmation/validation.
    tester
        .widget<EventTimePicker>(find.byType(EventTimePicker))
        .onChanged(time);
    await tester.pump();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'calendar initial today is visual only; explicit tap notifies exact date',
    (WidgetTester tester) async {
      final List<DateTime> selected = <DateTime>[];
      await mount(
        tester,
        Scaffold(body: EventCalendar(onDaySelected: selected.add)),
      );
      expect(selected, isEmpty);
      final DateTime today = _date(0);
      _expectDay(
        tester
            .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
            .selectedDay,
        today,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(EventMonthCalendar),
          matching: find.text('${today.day}'),
        ),
      );
      await tester.pumpAndSettle();
      _expectDay(selected.single, today);
    },
  );

  testWidgets(
    'another month and year selection survives month navigation and queries selected day events',
    (WidgetTester tester) async {
      final List<DateTime> selected = <DateTime>[];
      final DateTime date = DateTime(_date(0).year + 1, 1, 15);
      events.events = <EventResponseModel>[
        EventResponseModel(
          id: 1,
          name: 'Evento del dia',
          startAt: AppTimezone.argentinaToUtc(DateTime(date.year, 1, 15, 12)),
          memberIds: const <int>[],
        ),
      ];
      await mount(
        tester,
        Scaffold(body: EventCalendar(onDaySelected: selected.add)),
      );
      tester
          .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
          .onMonthChanged(date);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(EventMonthCalendar),
          matching: find.text('15'),
        ),
      );
      await tester.pumpAndSettle();
      _expectDay(selected.single, date);
      expect(find.text('Evento del dia'), findsOneWidget);
      expect(
        tester
            .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
            .dayHasEvents!(date),
        isTrue,
      );
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      _expectDay(
        tester
            .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
            .selectedDay,
        date,
      );
      expect(selected, hasLength(1));
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.pumpAndSettle();
      _expectDay(
        tester
            .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
            .selectedDay,
        date,
      );
    },
  );

  testWidgets(
    'FAB without explicit selection passes current Bond date through router and form',
    (WidgetTester tester) async {
      final DateTime before = AppTimezone.now();
      await mount(tester, const EventsScreen());
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final DateTime passed = tester
          .widget<CreateEventScreen>(find.byType(CreateEventScreen))
          .initialDate!;
      expect(passed.isBefore(before), isFalse);
      expect(passed.isAfter(AppTimezone.now()), isFalse);
      _expectDay(
        tester
            .widget<CreateEventForm>(find.byType(CreateEventForm))
            .initialStartDate,
        passed,
      );
      expect(find.textContaining(_label(passed)), findsOneWidget);
    },
  );

  testWidgets(
    'FAB keeps explicitly selected day after navigating away from its month',
    (WidgetTester tester) async {
      final DateTime date = DateTime(_date(0).year + 1, 1, 15);
      await mount(tester, const EventsScreen());
      tester
          .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
          .onMonthChanged(date);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(EventMonthCalendar),
          matching: find.text('15'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      _expectDay(
        tester
            .widget<CreateEventScreen>(find.byType(CreateEventScreen))
            .initialDate,
        date,
      );
      expect(find.textContaining(_label(date)), findsOneWidget);
      await save(tester);
      _expectDay(service.saved?.startAt, date);
    },
  );

  testWidgets('route without arguments still defaults to today', (
    WidgetTester tester,
  ) async {
    await mount(
      tester,
      Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.createEvent),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_label(_date(0))), findsOneWidget);
  });

  testWidgets(
    'future initialStartDate retains day on save and member selection',
    (WidgetTester tester) async {
      final DateTime date = _date(10);
      await form(tester, CreateEventForm(initialStartDate: date));
      expect(find.textContaining(_label(date)), findsOneWidget);
      await tester.tap(find.text('Invitado'));
      await save(tester);
      _expectDay(service.saved?.startAt, date);
      expect(service.saved?.memberIds, <int>[7]);
      expect(service.savedGroupId, 1);
    },
  );

  testWidgets(
    'existing picker manually replaces preloaded date and time before creation',
    (WidgetTester tester) async {
      final DateTime initial = _date(10);
      final DateTime changed = _date(40);
      await form(tester, CreateEventForm(initialStartDate: initial));
      await pick(
        tester,
        'Comienza',
        changed,
        const TimeOfDay(hour: 14, minute: 30),
      );
      expect(find.textContaining(_label(changed)), findsOneWidget);
      expect(find.textContaining(_label(initial)), findsNothing);
      await save(tester);
      _expectDay(service.saved?.startAt, changed);
      expect(service.saved?.startAt.hour, 14);
      expect(service.saved?.startAt.minute, 30);
      expect(
        service.saved?.toJson()['startAt'],
        AppTimezone.argentinaToUtc(
          DateTime(changed.year, changed.month, changed.day, 14, 30),
        ).toIso8601String(),
      );
    },
  );

  testWidgets('editing initialEvent has priority over initialStartDate', (
    WidgetTester tester,
  ) async {
    final DateTime date = _date(12);
    final EventResponseModel existing = EventResponseModel(
      id: 1,
      name: 'Existente',
      startAt: AppTimezone.argentinaToUtc(
        DateTime(date.year, date.month, date.day, 9, 45),
      ),
      memberIds: const <int>[7],
    );
    await form(
      tester,
      CreateEventForm(initialEvent: existing, initialStartDate: _date(30)),
    );
    expect(find.textContaining('${_label(date)} · 09:45'), findsOneWidget);
    expect(find.textContaining(_label(_date(30))), findsNothing);
    await tester.ensureVisible(find.byType(AppPrimaryButton));
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();
    expect(find.text('No hay cambios para guardar.'), findsOneWidget);
    expect(service.saved, isNull);
  });

  testWidgets(
    'past preloaded start remains visible but fails existing future validation',
    (WidgetTester tester) async {
      final DateTime past = _date(-2);
      await form(tester, CreateEventForm(initialStartDate: past));
      expect(find.textContaining(_label(past)), findsOneWidget);
      await save(tester);
      expect(
        find.text(
          'La fecha y hora de inicio deben ser posteriores a la fecha actual.',
        ),
        findsOneWidget,
      );
      expect(service.saved, isNull);
    },
  );

  testWidgets('today with future time can be created', (
    WidgetTester tester,
  ) async {
    final DateTime now = AppTimezone.now();
    // At the last minute there is no selectable future minute today.
    if (now.hour == 23 && now.minute >= 58) {
      markTestSkipped(
        'No future minute today with a safe test margin near midnight.',
      );
      return;
    }
    await form(tester, CreateEventForm(initialStartDate: now));
    await pick(tester, 'Comienza', now, const TimeOfDay(hour: 23, minute: 59));
    await save(tester);
    _expectDay(service.saved?.startAt, now);
    expect(service.saved?.startAt.hour, 23);
  });

  testWidgets(
    'end picker validates against preloaded start and accepts later end',
    (WidgetTester tester) async {
      final DateTime day = _date(10);
      await form(tester, CreateEventForm(initialStartDate: day));
      await pick(
        tester,
        'Finaliza (opcional)',
        day,
        const TimeOfDay(hour: 0, minute: 0),
      );
      expect(
        find.text(
          'La fecha y hora de finalización deben ser posteriores al inicio.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Cancelar'),
        ),
      );
      await tester.pumpAndSettle();
      await pick(
        tester,
        'Finaliza (opcional)',
        _date(11),
        const TimeOfDay(hour: 12, minute: 0),
      );
      await save(tester);
      expect(service.saved?.endAt?.isAfter(service.saved!.startAt), isTrue);
    },
  );

  testWidgets('preload alone is not an unsaved manual change', (
    WidgetTester tester,
  ) async {
    await form(tester, CreateEventForm(initialStartDate: _date(10)));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(find.byType(CreateEventForm), findsNothing);
  });

  testWidgets(
    'changing active group and refresh use current group without losing month selection',
    (WidgetTester tester) async {
      await mount(tester, const EventsScreen());
      final DateTime selected = _date(5);
      tester
          .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
          .onDaySelected(selected);
      await tester.pumpAndSettle();
      groups.switchTo(2);
      await tester.pumpAndSettle();
      expect(events.loadedGroups, [1, 2]);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(events.loadedGroups, [1, 2, 2]);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      _expectDay(
        tester
            .widget<CreateEventScreen>(find.byType(CreateEventScreen))
            .initialDate,
        selected,
      );
      await save(tester);
      expect(service.savedGroupId, 2);
    },
  );

  testWidgets('past calendar days remain selectable and event detail opens', (
    WidgetTester tester,
  ) async {
    final DateTime day = _date(-2);
    events.events = <EventResponseModel>[
      EventResponseModel(
        id: 1,
        name: 'Evento historico',
        startAt: AppTimezone.argentinaToUtc(day),
        memberIds: const <int>[],
      ),
    ];
    await mount(tester, const Scaffold(body: EventCalendar()));
    tester
        .widget<EventMonthCalendar>(find.byType(EventMonthCalendar))
        .onMonthChanged(day);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(EventMonthCalendar),
        matching: find.text(day.day.toString()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Evento historico'), findsOneWidget);
    await tester.tap(find.text('Evento historico'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailsModal), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailsModal), findsNothing);
  });
}
