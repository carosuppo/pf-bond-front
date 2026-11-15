sealed class GroupSocketEvent {
  const GroupSocketEvent();
}

class GroupSocketAuthenticated extends GroupSocketEvent {
  const GroupSocketAuthenticated();
}

class GroupsChanged extends GroupSocketEvent {
  final int groupId;
  final String reason;
  const GroupsChanged(this.groupId, this.reason);
}
