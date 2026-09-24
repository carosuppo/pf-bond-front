import 'package:flutter/material.dart';

import '../../../core/timezone/app_timezone.dart';
import '../models/create_event_model.request.dart';
import '../models/event_model.response.dart';
import '../models/update_event_model.request.dart';
import '../services/event_service.dart';

class EventProvider extends ChangeNotifier {
  final EventService _eventService;

  EventProvider(this._eventService);

  bool isLoading = false;
  bool isEventsLoading = false;
  String? errorMessage;
  EventResponseModel? event;
  List<EventResponseModel> events = [];
  int? _eventsGroupId;
  int _eventsLoadVersion = 0;
  int _sessionVersion = 0;
  final Set<int> _loadedYears = {};
  final Set<String> _loadedMonths = {};

  List<EventResponseModel> get todayEvents {
    final now = AppTimezone.now();
    final today = DateTime(now.year, now.month, now.day);

    return eventsForDay(today);
  }

  List<EventResponseModel> eventsForDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);

    final matches =
        events
            .where((event) => _isActiveOn(event, target))
            .toList(growable: false)
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return matches;
  }

  bool hasEventsOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);

    return events.any((event) => _isActiveOn(event, target));
  }

  bool isMultiDayEvent(EventResponseModel event) {
    if (event.endAt == null) return false;

    final start = AppTimezone.fromUtc(event.startAt);
    final end = AppTimezone.fromUtc(event.endAt!);

    return start.year != end.year ||
        start.month != end.month ||
        start.day != end.day;
  }

  Future<void> loadEvents({required int groupId, int? year, int? month}) async {
    final now = AppTimezone.now();
    final targetYear = year ?? now.year;
    final targetMonth = month;
    final loadVersion = ++_eventsLoadVersion;
    _eventsGroupId = groupId;
    events = [];
    _loadedYears.clear();
    _loadedMonths.clear();
    isEventsLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedEvents = await _eventService.getEvents(
        groupId: groupId,
        year: targetYear,
        month: targetMonth,
      );

      if (_eventsGroupId == groupId && _eventsLoadVersion == loadVersion) {
        events = loadedEvents;
        if (targetMonth == null) {
          _loadedYears.add(targetYear);
        } else {
          _loadedMonths.add(_monthKey(targetYear, targetMonth));
        }
      }
    } catch (error) {
      if (_eventsGroupId == groupId && _eventsLoadVersion == loadVersion) {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (_eventsGroupId == groupId && _eventsLoadVersion == loadVersion) {
        isEventsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> ensureMonthLoaded({
    required int groupId,
    required int year,
    required int month,
  }) async {
    if (_eventsGroupId != groupId) return;
    if (_loadedYears.contains(year)) return;
    if (_loadedMonths.contains(_monthKey(year, month))) return;

    try {
      final loadedEvents = await _eventService.getEvents(
        groupId: groupId,
        year: year,
        month: month,
      );

      if (_eventsGroupId != groupId) return;

      final byId = {for (final event in events) event.id: event};
      for (final event in loadedEvents) {
        byId[event.id] = event;
      }
      events = byId.values.toList(growable: false)
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      _loadedMonths.add(_monthKey(year, month));
      notifyListeners();
    } catch (_) {
      // La navegación del calendario no debe romper la pantalla;
      // el refresh principal muestra los errores.
    }
  }

  String _monthKey(int year, int month) => '$year-$month';

  void clearEvents() {
    _sessionVersion++;
    _eventsLoadVersion++;
    _eventsGroupId = null;
    event = null;
    events = [];
    _loadedYears.clear();
    _loadedMonths.clear();
    isEventsLoading = false;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  void resetSessionState() => clearEvents();

  Future<bool> createEvent({
    required int groupId,
    required String name,
    String? description,
    required DateTime startAt,
    DateTime? endAt,
    required List<int> memberIds,
  }) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;
    event = null;

    notifyListeners();

    try {
      final request = CreateEventRequestModel(
        name: name,
        description: description,
        startAt: startAt,
        endAt: endAt,
        memberIds: memberIds,
      );

      final createdEvent = await _eventService.createEvent(
        groupId: groupId,
        request: request,
      );
      if (sessionVersion != _sessionVersion) return false;
      event = createdEvent;

      if (_eventsGroupId == groupId) {
        events = [...events, event!]
          ..sort((first, second) => first.startAt.compareTo(second.startAt));
      }

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateEvent({
    required int groupId,
    required int eventId,
    required UpdateEventRequestModel request,
  }) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final updatedEvent = await _eventService.updateEvent(
        groupId: groupId,
        eventId: eventId,
        request: request,
      );
      if (sessionVersion != _sessionVersion) return false;

      final index = events.indexWhere((event) => event.id == eventId);

      if (index != -1) {
        events[index] = updatedEvent;
        events.sort((first, second) => first.startAt.compareTo(second.startAt));
      }

      if (event?.id == eventId) {
        event = updatedEvent;
      }

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> cancelEvent({required int groupId, required int eventId}) async {
    final sessionVersion = _sessionVersion;
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await _eventService.cancelEvent(groupId: groupId, eventId: eventId);
      if (sessionVersion != _sessionVersion) return false;

      events = events
          .where((event) => event.id != eventId)
          .toList(growable: false);

      if (event?.id == eventId) {
        event = null;
      }

      return true;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return false;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      if (sessionVersion == _sessionVersion) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<EventResponseModel?> setEventLocation({
    required int groupId,
    required int eventId,
    required double latitude,
    required double longitude,
  }) async {
    final sessionVersion = _sessionVersion;
    try {
      final updatedEvent = await _eventService.setEventLocation(
        groupId: groupId,
        eventId: eventId,
        latitude: latitude,
        longitude: longitude,
      );
      if (sessionVersion != _sessionVersion) return null;

      final index = events.indexWhere((event) => event.id == eventId);

      if (index != -1) {
        events[index] = updatedEvent;
      }

      if (event?.id == eventId) {
        event = updatedEvent;
      }

      notifyListeners();
      return updatedEvent;
    } catch (error) {
      if (sessionVersion != _sessionVersion) return null;
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  bool _isActiveOn(EventResponseModel event, DateTime today) {
    final start = AppTimezone.fromUtc(event.startAt);
    final end = event.endAt != null ? AppTimezone.fromUtc(event.endAt!) : start;

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    return !today.isBefore(startDay) && !today.isAfter(endDay);
  }
}
