import 'package:bond_front/core/network/api_client.dart';
import 'package:bond_front/core/storage/session_storage_service.dart';
import 'package:bond_front/core/timezone/app_timezone.dart';
import 'package:bond_front/features/event/models/create_event_model.request.dart';
import 'package:bond_front/features/event/models/event_model.response.dart';
import 'package:bond_front/features/event/providers/event_provider.dart';
import 'package:bond_front/features/event/services/event_service.dart';
import 'package:bond_front/features/event/widgets/event_recurrence_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEvents extends EventService {
  FakeEvents() : super(ApiClient(SessionStorageService()));
  bool created = false;
  EventResponseModel occurrence(int day) => EventResponseModel(
    id: day,
    name: 'Serie',
    startAt: DateTime.utc(2090, 1, day, 15),
    memberIds: const <int>[1, 2],
    recurrenceId: 1,
  );

  @override
  Future<List<EventResponseModel>> getEvents({
    required int groupId,
    required int year,
    int? month,
  }) async => created
      ? <EventResponseModel>[occurrence(2), occurrence(3)]
      : <EventResponseModel>[];

  @override
  Future<EventResponseModel> createEvent({
    required int groupId,
    required CreateEventRequestModel request,
  }) async {
    created = true;
    return occurrence(2);
  }
}

void main() {
  setUpAll(AppTimezone.initialize);

  test(
    'serializes normal events and every recurrence frequency in Bond timezone',
    () {
      final DateTime start = DateTime(2090, 1, 2, 12);
      expect(
        CreateEventRequestModel(
          name: 'Normal',
          startAt: start,
          memberIds: const <int>[],
        ).toJson().containsKey('recurrence'),
        isFalse,
      );
      for (final EventRecurrenceFrequency frequency
          in EventRecurrenceFrequency.values) {
        final EventRecurrenceRequest recurrence = EventRecurrenceRequest(
          frequency: frequency,
        );
        expect(recurrence.toJson(), <String, String?>{
          'frequency': frequency.value,
          'until': null,
        });
        expect(
          CreateEventRequestModel(
            name: 'Serie',
            startAt: start,
            memberIds: const <int>[1],
            recurrence: recurrence,
          ).toJson()['recurrence'],
          recurrence.toJson(),
        );
      }
      expect(
        EventRecurrenceRequest(
          frequency: EventRecurrenceFrequency.daily,
          until: start,
        ).toJson()['until'],
        '2090-01-02T15:00:00.000Z',
      );
    },
  );

  test('validates recurrence end after a changed start date', () {
    final DateTime start = DateTime(2090, 1, 2);
    expect(
      EventRecurrenceRequest(
        frequency: EventRecurrenceFrequency.daily,
        until: start,
      ).validateFor(start),
      isNotNull,
    );
    expect(
      EventRecurrenceRequest(
        frequency: EventRecurrenceFrequency.daily,
        until: start,
      ).validateFor(DateTime(2090, 1, 3)),
      isNotNull,
    );
    expect(
      const EventRecurrenceRequest(
        frequency: EventRecurrenceFrequency.daily,
      ).validateFor(start),
      isNull,
    );
  });

  test(
    'refreshes all loaded occurrences and keeps chronological calendar results',
    () async {
      final EventProvider provider = EventProvider(FakeEvents());
      await provider.loadEvents(groupId: 1, year: 2090);
      expect(
        await provider.createEvent(
          groupId: 1,
          name: 'Serie',
          startAt: DateTime(2090, 1, 2),
          memberIds: const <int>[2],
          recurrence: const EventRecurrenceRequest(
            frequency: EventRecurrenceFrequency.daily,
          ),
        ),
        isTrue,
      );
      expect(provider.events.map((EventResponseModel event) => event.id), <int>[
        2,
        3,
      ]);
      expect(provider.eventsForDay(DateTime(2090, 1, 3)).single.id, 3);
      provider.dispose();
    },
  );

  testWidgets(
    'toggles recurrence, selects frequency, selects and clears optional until',
    (WidgetTester tester) async {
      EventRecurrenceRequest? value;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) =>
                  EventRecurrenceFields(
                    value: value,
                    startAt: DateTime(2090, 1, 2),
                    enabled: true,
                    onChanged: (EventRecurrenceRequest? next) =>
                        setState(() => value = next),
                  ),
            ),
          ),
        ),
      );
      expect(find.text('Periodicidad'), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(value!.frequency, EventRecurrenceFrequency.weekly);
      expect(find.textContaining('Sin fecha final'), findsOneWidget);
      await tester.tap(
        find.byType(DropdownButtonFormField<EventRecurrenceFrequency>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mensualmente').last);
      await tester.pumpAndSettle();
      expect(value!.frequency, EventRecurrenceFrequency.monthly);
      await tester.tap(find.text('Repetir hasta (opcional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(value!.until!.day, 3);
      await tester.tap(find.byTooltip('Quitar fecha final'));
      await tester.pumpAndSettle();
      expect(value!.until, isNull);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(value, isNull);
    },
  );
}
