import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../event/formatters/event_date_formatter.dart';
import '../../event/models/event_model.response.dart';
import '../../event/providers/event_provider.dart';
import '../../group/models/get_groups_model.response.dart';
import '../../group/models/get_member_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../providers/expense_account_provider.dart';

class CreateExpenseAccountForm extends StatefulWidget {
  final int? groupId;

  const CreateExpenseAccountForm({super.key, this.groupId});

  @override
  State<CreateExpenseAccountForm> createState() =>
      _CreateExpenseAccountFormState();
}

class _CreateExpenseAccountFormState extends State<CreateExpenseAccountForm> {
  static const int _nameMaxLength = 100;

  final _nameController = TextEditingController();

  int? _manualGroupId;
  bool _isEventMode = false;
  int? _selectedEventId;
  final Set<int> _selectedMemberIds = {};
  final Set<int> _initialSelectedMemberIds = {};
  int? _initialGroupId;
  bool _initialSelectionCaptured = false;

  int? _eventsGroupId;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    if (widget.groupId != null) {
      _manualGroupId = widget.groupId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureReady());
  }

  Future<void> _ensureReady() async {
    if (!mounted) {
      return;
    }

    await context.read<GroupProvider>().initialize();

    if (!mounted) {
      return;
    }

    setState(_captureInitialSelection);
    _syncEvents();
  }

  void _captureInitialSelection() {
    if (_initialSelectionCaptured || _isEventMode) {
      return;
    }

    final groupId = _effectiveGroupId(context);
    _initialGroupId = groupId;
    _initialSelectionCaptured = true;
    if (groupId == null) {
      return;
    }

    final details = context.read<GroupProvider>().groupDetails;
    if (details?.id != groupId) {
      return;
    }

    _selectedMemberIds.addAll(
      _visibleMembers(context).map((member) => member.id),
    );
    _initialSelectedMemberIds.addAll(_selectedMemberIds);
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  int? _effectiveGroupId(BuildContext context) {
    return _manualGroupId ??
        widget.groupId ??
        context.read<GroupProvider>().activeGroup?.id;
  }

  String? _groupDisplayName(GroupProvider groupProvider, int groupId) {
    for (final group in groupProvider.groups) {
      if (group.id == groupId) {
        return group.name;
      }
    }

    final activeGroup = groupProvider.activeGroup;

    if (activeGroup != null && activeGroup.id == groupId) {
      return activeGroup.name;
    }

    return null;
  }

  void _syncEvents() {
    if (!mounted || !_isEventMode) {
      return;
    }

    final groupId = _effectiveGroupId(context);

    if (groupId == null || groupId == _eventsGroupId) {
      return;
    }

    final eventProvider = context.read<EventProvider>();

    if (eventProvider.isEventsLoading) {
      return;
    }

    _eventsGroupId = groupId;
    eventProvider.loadEvents(groupId: groupId);
  }

  EventResponseModel? _selectedEvent(BuildContext context) {
    final eventId = _selectedEventId;

    if (eventId == null) {
      return null;
    }

    final events = context.read<EventProvider>().events;

    for (final event in events) {
      if (event.id == eventId) {
        return event;
      }
    }

    return null;
  }

  List<GetMemberResponseModel> _visibleMembers(BuildContext context) {
    final groupId = _effectiveGroupId(context);
    final groupProvider = context.read<GroupProvider>();
    final details = groupProvider.groupDetails;

    if (groupId == null || details == null || details.id != groupId) {
      return const [];
    }

    final currentUserId = context.read<AuthProvider>().authResponse?.user.id;

    final withoutSelf = details.members
        .where((member) => member.idUser != currentUserId)
        .toList(growable: false);

    if (!_isEventMode) {
      return withoutSelf;
    }

    final event = _selectedEvent(context);

    if (event == null) {
      return const [];
    }

    final eventMemberIds = event.memberIds.toSet();

    return withoutSelf
        .where((member) => eventMemberIds.contains(member.id))
        .toList(growable: false);
  }

  bool _canSave(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      return false;
    }

    if (_effectiveGroupId(context) == null) {
      return false;
    }

    if (_selectedMemberIds.isEmpty) {
      return false;
    }

    if (_isEventMode && _selectedEvent(context) == null) {
      return false;
    }

    return true;
  }

  Future<void> _openGroupSheet() async {
    FocusScope.of(context).unfocus();

    final groupProvider = context.read<GroupProvider>();
    await groupProvider.loadGroups();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final groups = context.watch<GroupProvider>().groups;
        final effectiveGroupId = _effectiveGroupId(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mutedText.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seleccioná un grupo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No pertenecés a ningún grupo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (_, index) {
                        final group = groups[index];
                        final selected = group.id == effectiveGroupId;

                        return _SheetTile(
                          title: group.name,
                          selected: selected,
                          onTap: () => _onGroupChosen(group),
                        );
                      },
                    ),
                  ),
                if (groups.isEmpty) ...[
                  const SizedBox(height: 8),
                  AppPrimaryButton(
                    text: 'Crear un grupo',
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.createGroup);
                      if (!mounted) {
                        return;
                      }
                      await context.read<GroupProvider>().loadGroups();
                    },
                  ),
                  const SizedBox(height: 12),
                  AppSecondaryButton(
                    text: 'Unirme a un grupo',
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.joinGroup);
                      if (!mounted) {
                        return;
                      }
                      await context.read<GroupProvider>().loadGroups();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onGroupChosen(GetGroupsResponseModel group) async {
    Navigator.of(context).pop();

    setState(() {
      _manualGroupId = group.id;
      _selectedEventId = null;
      _selectedMemberIds.clear();
    });

    await context.read<GroupProvider>().selectGroup(group);

    if (!mounted) {
      return;
    }

    if (!_isEventMode) {
      setState(() {
        _selectedMemberIds.addAll(
          _visibleMembers(context).map((member) => member.id),
        );
      });
    }

    _syncEvents();
  }

  Future<void> _openEventSheet() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final events = context.watch<EventProvider>().events;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.mutedText.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seleccioná un evento',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Este grupo todavía no tiene eventos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: events.length,
                      itemBuilder: (_, index) {
                        final event = events[index];

                        return _SheetTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          title: event.name,
                          subtitle:
                              '${EventDateFormatter.dayMonth(event.startAt)} · '
                              '${EventDateFormatter.time(event.startAt)}',
                          selected: event.id == _selectedEventId,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            setState(() {
                              _selectedEventId = event.id;
                              _selectedMemberIds
                                ..clear()
                                ..addAll(
                                  _visibleMembers(
                                    context,
                                  ).map((member) => member.id),
                                );
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _switchMode(bool eventMode) {
    if (_isEventMode == eventMode) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isEventMode = eventMode;
      _selectedEventId = null;
      _selectedMemberIds.clear();
      if (!eventMode) {
        _selectedMemberIds.addAll(
          _visibleMembers(context).map((member) => member.id),
        );
      }
    });
  }

  Future<void> _saveExpenseAccount() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final groupId = _effectiveGroupId(context);

    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un grupo para la cuenta.')),
      );

      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la cuenta es obligatorio.')),
      );

      return;
    }

    if (_isEventMode && _selectedEvent(context) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un evento para la cuenta.')),
      );

      return;
    }

    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes asociar al menos un miembro a la cuenta.'),
        ),
      );

      return;
    }

    final expenseAccountProvider = context.read<ExpenseAccountProvider>();

    final success = await expenseAccountProvider.createExpenseAccount(
      groupId: groupId,
      name: name,
      memberIds: _selectedMemberIds.toList(),
      eventId: _isEventMode ? _selectedEventId : null,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expenseAccountProvider.errorMessage ?? 'Error al crear la cuenta.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  bool get _hasChanges {
    final groupId = _effectiveGroupId(context);
    return _nameController.text.trim().isNotEmpty ||
        groupId != _initialGroupId ||
        _isEventMode ||
        _selectedEventId != null ||
        _selectedMemberIds.length != _initialSelectedMemberIds.length ||
        !_selectedMemberIds.containsAll(_initialSelectedMemberIds);
  }

  Future<void> _handleBack() async {
    if (!_hasChanges) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      return;
    }

    final shouldDiscard = await showDiscardChangesDialog(context);

    if (!mounted || !shouldDiscard) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    _syncEvents();

    final groupProvider = context.watch<GroupProvider>();
    final eventProvider = context.watch<EventProvider>();
    final expenseAccountProvider = context.watch<ExpenseAccountProvider>();

    final groupId = _effectiveGroupId(context);
    final details = groupProvider.groupDetails;
    final detailsReady = groupId != null && details?.id == groupId;

    final selectedEvent = _selectedEvent(context);
    final visibleMembers = _visibleMembers(context);

    final isLoading =
        expenseAccountProvider.isLoading || groupProvider.isLoading;
    final isLoadingEvents = eventProvider.isEventsLoading;
    final canSave =
        !isLoading && (!_isEventMode || !isLoadingEvents) && _canSave(context);

    final screenWidth = MediaQuery.of(context).size.width;

    final maxContentWidth = screenWidth > 600 ? 480.0 : double.infinity;
    final horizontalPadding = screenWidth > 600 ? 32.0 : 24.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(title: 'Crear cuenta', onBack: _handleBack),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  4,
                  horizontalPadding,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GroupSelector(
                          groupName: groupId == null
                              ? null
                              : _groupDisplayName(groupProvider, groupId),
                          enabled: !isLoading,
                          onTap: _openGroupSheet,
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        const Text(
                          'Nombre de la cuenta',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextField(
                          controller: _nameController,
                          enabled: !isLoading,
                          maxLength: _nameMaxLength,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: AppColors.primary,
                          decoration: const InputDecoration(
                            hintText: 'Ej. Gastos del viaje',
                            hintStyle: TextStyle(
                              color: AppColors.placeholder,
                              fontSize: 20,
                            ),
                            counterText: '',
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        InkWell(
                          onTap: !isLoading && groupId != null
                              ? () => _switchMode(!_isEventMode)
                              : null,
                          child: SizedBox(
                            height: 48,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_available_outlined,
                                  color: AppColors.mutedText,
                                  size: 19,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Vincular a un evento',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _isEventMode,
                                  onChanged: !isLoading && groupId != null
                                      ? _switchMode
                                      : null,
                                  activeThumbColor: AppColors.onPrimary,
                                  activeTrackColor: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isEventMode) ...[
                          _EventPicker(
                            event: selectedEvent,
                            isLoadingEvents: isLoadingEvents,
                            hasEvents: eventProvider.events.isNotEmpty,
                            enabled:
                                !isLoading &&
                                !isLoadingEvents &&
                                groupId != null &&
                                eventProvider.events.isNotEmpty,
                            onTap: _openEventSheet,
                          ),
                        ],
                        const Divider(height: 20, color: AppColors.border),
                        _MembersSection(
                          groupId: groupId,
                          detailsReady: detailsReady,
                          detailsLoading: groupProvider.isLoading,
                          isEventMode: _isEventMode,
                          eventSelected: selectedEvent != null,
                          eventsLoading: isLoadingEvents,
                          eventsAvailable: eventProvider.events.isNotEmpty,
                          members: visibleMembers,
                          selectedIds: _selectedMemberIds,
                          enabled: !isLoading,
                          onToggle: (memberId, selected) {
                            setState(() {
                              if (selected) {
                                _selectedMemberIds.add(memberId);
                              } else {
                                _selectedMemberIds.remove(memberId);
                              }
                            });
                          },
                          onSelectAll: (selectAll, members) {
                            setState(() {
                              if (selectAll) {
                                _selectedMemberIds.addAll(
                                  members.map((member) => member.id),
                                );
                              } else {
                                _selectedMemberIds.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: AppPrimaryButton(
                    text: 'Crear cuenta',
                    loading: expenseAccountProvider.isLoading,
                    onPressed: canSave ? _saveExpenseAccount : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groupName,
    required this.enabled,
    required this.onTap,
  });

  final String? groupName;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                color: AppColors.primary,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  groupName ?? 'Seleccionar un grupo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                groupName == null ? 'Elegir' : 'Cambiar',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventPicker extends StatelessWidget {
  const _EventPicker({
    required this.event,
    required this.isLoadingEvents,
    required this.hasEvents,
    required this.enabled,
    required this.onTap,
  });

  final EventResponseModel? event;
  final bool isLoadingEvents;
  final bool hasEvents;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = event;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 4, 8),
          child: Row(
            children: [
              if (isLoadingEvents)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                Icon(
                  current == null
                      ? Icons.calendar_month_outlined
                      : Icons.event_available_outlined,
                  color: current == null
                      ? AppColors.mutedText
                      : AppColors.primary,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoadingEvents
                          ? 'Cargando eventos…'
                          : current?.name ??
                                (hasEvents
                                    ? 'Seleccionar evento'
                                    : 'No hay eventos en este grupo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: current != null || hasEvents
                            ? AppColors.text
                            : AppColors.mutedText,
                        fontSize: 14,
                        fontWeight: current == null
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    if (current != null)
                      Text(
                        '${EventDateFormatter.dayMonth(current.startAt)} · '
                        '${EventDateFormatter.time(current.startAt)}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasEvents)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedText,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersSection extends StatefulWidget {
  const _MembersSection({
    required this.groupId,
    required this.detailsReady,
    required this.detailsLoading,
    required this.isEventMode,
    required this.eventSelected,
    required this.eventsLoading,
    required this.eventsAvailable,
    required this.members,
    required this.selectedIds,
    required this.enabled,
    required this.onToggle,
    required this.onSelectAll,
  });

  final int? groupId;
  final bool detailsReady;
  final bool detailsLoading;
  final bool isEventMode;
  final bool eventSelected;
  final bool eventsLoading;
  final bool eventsAvailable;
  final List<GetMemberResponseModel> members;
  final Set<int> selectedIds;
  final bool enabled;
  final void Function(int memberId, bool selected) onToggle;
  final void Function(bool selectAll, List<GetMemberResponseModel> members)
  onSelectAll;

  @override
  State<_MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends State<_MembersSection> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _message(String text, {bool loading = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (loading) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return _message('Elegí un grupo para ver sus miembros.');
    }

    if (!widget.detailsReady) {
      return _message(
        widget.detailsLoading
            ? 'Cargando miembros…'
            : 'No se pudieron cargar los miembros.',
        loading: widget.detailsLoading,
      );
    }

    if (widget.isEventMode && !widget.eventSelected) {
      if (widget.eventsLoading) {
        return const SizedBox.shrink();
      }
      return widget.eventsAvailable
          ? _message('Seleccioná un evento para ver sus miembros.')
          : const SizedBox.shrink();
    }

    if (widget.members.isEmpty) {
      return _message('Se requiere al menos un miembro disponible.');
    }

    final filteredMembers = _query.isEmpty
        ? widget.members
        : widget.members
              .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    final selectedCount = widget.members
        .where((member) => widget.selectedIds.contains(member.id))
        .length;
    final allSelected = selectedCount == widget.members.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Miembros',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$selectedCount/${widget.members.length}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
            if (!allSelected) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: widget.enabled
                    ? () => widget.onSelectAll(true, widget.members)
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Incluir todos'),
              ),
            ],
          ],
        ),
        if (widget.members.length > 5) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _searchController,
            enabled: widget.enabled,
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(color: AppColors.text, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar miembro',
              hintStyle: const TextStyle(color: AppColors.mutedText),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.mutedText,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.fieldColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (filteredMembers.isEmpty)
          _message('No hay coincidencias.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final member in filteredMembers)
                _AccountMemberChip(
                  member: member,
                  selected: widget.selectedIds.contains(member.id),
                  enabled: widget.enabled,
                  onTap: (selected) => widget.onToggle(member.id, selected),
                ),
            ],
          ),
      ],
    );
  }
}

class _AccountMemberChip extends StatelessWidget {
  const _AccountMemberChip({
    required this.member,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final GetMemberResponseModel member;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onTap;

  String get _initials {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = member.profilePhoto?.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, maxWidth: 240),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? AppColors.primary
                : AppColors.border.withValues(alpha: 0.8),
            width: selected ? 1 : 0.7,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? () => onTap(!selected) : null,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photo != null && photo.isNotEmpty)
                  UserAvatar(name: member.name, photoUrl: photo, radius: 13)
                else
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: selected
                        ? AppColors.primary
                        : AppColors.surface,
                    child: Text(
                      _initials,
                      style: TextStyle(
                        color: selected ? Colors.black : AppColors.mutedText,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  color: selected ? AppColors.primary : AppColors.mutedText,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.mutedText,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
