class PendingEventReminder {
  final int groupId;
  final int eventId;

  const PendingEventReminder({required this.groupId, required this.eventId});
}

bool _appReady = false;
PendingEventReminder? _pending;

bool get isAppReady => _appReady;

void markAppReady() {
  _appReady = true;
}

void stashPendingEventReminder({required int groupId, required int eventId}) {
  _pending = PendingEventReminder(groupId: groupId, eventId: eventId);
}

PendingEventReminder? takePendingEventReminder() {
  final pending = _pending;
  _pending = null;
  return pending;
}
