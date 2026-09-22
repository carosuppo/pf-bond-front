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

  List<EventResponseModel> get todayEvents {
    final now = AppTimezone.now();
    final today = DateTime(now.year, now.month, now.day);

    return events
        .where((event) => _isActiveOn(event, today))
        .toList(growable: false);
  }

  Future<void> loadEvents({required int groupId}) async {
    final loadVersion = ++_eventsLoadVersion;
    _eventsGroupId = groupId;
    events = [];
    isEventsLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final now = AppTimezone.now();
      final loadedEvents = await _eventService.getEvents(
        groupId: groupId,
        year: now.year,
      );

      if (_eventsGroupId == groupId && _eventsLoadVersion == loadVersion) {
        events = loadedEvents;
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

  void clearEvents() {
    _sessionVersion++;
    _eventsLoadVersion++;
    _eventsGroupId = null;
    event = null;
    events = [];
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
