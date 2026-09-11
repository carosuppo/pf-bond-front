import 'package:flutter/material.dart';

import '../models/create_event_model.request.dart';
import '../models/create_event_model.response.dart';
import '../services/event_service.dart';

class EventProvider extends ChangeNotifier {
  final EventService _eventService;

  EventProvider(this._eventService);

  bool isLoading = false;
  bool isEventsLoading = false;
  String? errorMessage;
  CreateEventResponseModel? event;
  List<CreateEventResponseModel> events = [];
  int? _eventsGroupId;
  int _eventsLoadVersion = 0;

  Future<void> loadEvents({required int groupId}) async {
    final loadVersion = ++_eventsLoadVersion;
    _eventsGroupId = groupId;
    events = [];
    isEventsLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final loadedEvents = await _eventService.getEvents(groupId: groupId);

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
    _eventsLoadVersion++;
    _eventsGroupId = null;
    events = [];
    isEventsLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> createEvent({
    required int groupId,
    required String name,
    String? description,
    required DateTime startAt,
    DateTime? endAt,
    required List<int> memberIds,
  }) async {
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

      event = await _eventService.createEvent(
        groupId: groupId,
        request: request,
      );

      if (_eventsGroupId == groupId) {
        events = [...events, event!]
          ..sort((first, second) => first.startAt.compareTo(second.startAt));
      }

      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
