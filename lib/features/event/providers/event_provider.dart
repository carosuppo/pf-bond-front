import 'package:flutter/material.dart';

import '../../../core/timezone/app_timezone.dart';
import '../models/event_model.response.dart';
import '../services/event_service.dart';

class EventProvider extends ChangeNotifier {
  final EventService _eventService;

  EventProvider(this._eventService);

  bool isLoading = false;
  String? errorMessage;
  List<EventResponseModel> events = [];

  List<EventResponseModel> get todayEvents {
    final now = AppTimezone.now();
    final today = DateTime(now.year, now.month, now.day);

    return events
        .where((event) => _isActiveOn(event, today))
        .toList(growable: false);
  }

  Future<void> loadEvents({required int groupId}) async {
    isLoading = true;
    errorMessage = null;
    events = [];

    notifyListeners();

    try {
      events = await _eventService.getEvents(groupId: groupId);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
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
