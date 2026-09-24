import 'package:flutter/material.dart';

import '../models/event_reminder_model.response.dart';
import '../services/event_reminder_service.dart';

class EventReminderProvider extends ChangeNotifier {
  final EventReminderService _reminderService;

  EventReminderProvider(this._reminderService);

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  List<EventReminderModel> reminders = [];

  bool get hasReminders => reminders.isNotEmpty;

  Future<void> load({required int groupId, required int eventId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      reminders = await _reminderService.getReminders(
        groupId: groupId,
        eventId: eventId,
      );
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    required int groupId,
    required int eventId,
    required List<int> leadMinutes,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      reminders = await _reminderService.setReminders(
        groupId: groupId,
        eventId: eventId,
        leadMinutes: leadMinutes,
      );
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> clear({required int groupId, required int eventId}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _reminderService.deleteReminders(
        groupId: groupId,
        eventId: eventId,
      );
      reminders = [];
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
