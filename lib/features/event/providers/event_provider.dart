import 'package:flutter/material.dart';

import '../models/create_event_model.request.dart';
import '../models/create_event_model.response.dart';
import '../services/event_service.dart';

class EventProvider extends ChangeNotifier {
  final EventService _eventService;

  EventProvider(this._eventService);

  bool isLoading = false;
  String? errorMessage;
  CreateEventResponseModel? event;

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
