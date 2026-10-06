import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/global_text_field.dart';
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

    _syncEvents();
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
    if (!mounted) {
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

    if (_isEventMode && _selectedEventId == null) {
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
                              _selectedMemberIds.clear();
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

    setState(() {
      _isEventMode = eventMode;
      _selectedEventId = null;
      _selectedMemberIds.clear();
    });
  }

  Future<void> _saveExpenseAccount() async {
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

    if (_isEventMode && _selectedEventId == null) {
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
    return _nameController.text.trim().isNotEmpty ||
        _manualGroupId != null ||
        _isEventMode ||
        _selectedEventId != null ||
        _selectedMemberIds.isNotEmpty;
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

  Widget _buildAppBar(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
      ),
    );
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
    final memberCount = detailsReady ? details!.members.length : 0;

    final selectedEvent = _selectedEvent(context);
    final visibleMembers = _visibleMembers(context);

    final isLoading =
        expenseAccountProvider.isLoading || groupProvider.isLoading;
    final isLoadingEvents = eventProvider.isEventsLoading;
    final canSave = !isLoading && _canSave(context);

    final theme = Theme.of(context);
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
            _buildAppBar(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Crear cuenta',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 20),

                            _GroupCard(
                              groupName: groupId == null
                                  ? null
                                  : _groupDisplayName(groupProvider, groupId),
                              memberCount: memberCount,
                              detailsReady: detailsReady,
                              enabled: !isLoading,
                              onTap: _openGroupSheet,
                            ),

                            const SizedBox(height: 20),

                            const _FieldHeader(label: 'Nombre de la cuenta *'),

                            const SizedBox(height: 8),

                            GlobalTextField(
                              controller: _nameController,
                              label: 'Ej: Gastos del viaje',
                              maxLength: _nameMaxLength,
                              enabled: !isLoading,
                            ),

                            const SizedBox(height: 20),

                            const _FieldHeader(label: 'Tipo de cuenta'),

                            const SizedBox(height: 8),

                            _TypeSegmented(
                              isEventMode: _isEventMode,
                              enabled: !isLoading,
                              onChanged: _switchMode,
                            ),

                            const SizedBox(height: 12),

                            _InfoLine(
                              text: _isEventMode
                                  ? 'Solo podés elegir miembros que ya pertenecen a este evento.'
                                  : 'No se vincula a ningún evento. Podés elegir miembros de todo el grupo.',
                            ),

                            if (_isEventMode) ...[
                              const SizedBox(height: 12),
                              _EventCard(
                                event: selectedEvent,
                                isLoadingEvents: isLoadingEvents,
                                enabled: !isLoading && groupId != null,
                                onTap: _openEventSheet,
                              ),
                            ],

                            const SizedBox(height: 20),

                            const _FieldHeader(label: 'Miembros'),

                            const SizedBox(height: 8),

                            _MembersSection(
                              groupId: groupId,
                              detailsReady: detailsReady,
                              detailsLoading: groupProvider.isLoading,
                              isEventMode: _isEventMode,
                              eventSelected: selectedEvent != null,
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
                                      members.map((m) => m.id),
                                    );
                                  } else {
                                    _selectedMemberIds.clear();
                                  }
                                });
                              },
                            ),

                            const SizedBox(height: 24),

                            AppPrimaryButton(
                              text: 'Crear cuenta',
                              loading: expenseAccountProvider.isLoading,
                              onPressed: canSave ? _saveExpenseAccount : null,
                            ),

                            const SizedBox(height: 12),

                            AppSecondaryButton(
                              text: 'Cancelar',
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.groupName,
    required this.memberCount,
    required this.detailsReady,
    required this.enabled,
    required this.onTap,
  });

  final String? groupName;
  final int memberCount;
  final bool detailsReady;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName ?? 'Seleccioná un grupo',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      groupName == null
                          ? 'Todavía no elegiste grupo'
                          : detailsReady
                          ? '$memberCount miembros · Grupo activo'
                          : 'Grupo activo',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSegmented extends StatelessWidget {
  const _TypeSegmented({
    required this.isEventMode,
    required this.enabled,
    required this.onChanged,
  });

  final bool isEventMode;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  Widget _option(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : AppColors.mutedText,
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _option(
            context,
            label: 'Cuenta general',
            selected: !isEventMode,
            onTap: enabled ? () => onChanged(false) : null,
          ),
          _option(
            context,
            label: 'De un evento',
            selected: isEventMode,
            onTap: enabled ? () => onChanged(true) : null,
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.mutedText, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.isLoadingEvents,
    required this.enabled,
    required this.onTap,
  });

  final EventResponseModel? event;
  final bool isLoadingEvents;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = event;

    return Material(
      color: AppColors.fieldColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: isLoadingEvents
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current?.name ?? 'Seleccioná un evento',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoadingEvents
                          ? 'Cargando eventos...'
                          : current == null
                          ? 'Ver eventos del grupo'
                          : '${EventDateFormatter.dayMonth(current.startAt)} · '
                                '${EventDateFormatter.time(current.startAt)}',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mutedText),
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

  Widget _emptyBox(String primary, [String? secondary]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.groups_outlined,
            color: AppColors.mutedText,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            primary,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text, fontSize: 14),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 4),
            Text(
              secondary,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return _emptyBox('Seleccioná un grupo para ver sus miembros.');
    }

    if (!widget.detailsReady) {
      return _emptyBox(
        widget.detailsLoading ? 'Cargando miembros...' : 'Miembros del grupo',
      );
    }

    if (widget.isEventMode && !widget.eventSelected) {
      return _emptyBox('Primero seleccioná un evento para ver sus miembros.');
    }

    if (widget.members.isEmpty) {
      return _emptyBox(
        'No hay miembros disponibles para asociar.',
        'Quedarás asociado automáticamente a la cuenta.',
      );
    }

    final filteredMembers = _query.isEmpty
        ? widget.members
        : widget.members
              .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          enabled: widget.enabled,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar miembros...',
            hintStyle: const TextStyle(color: AppColors.mutedText),
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.mutedText,
              size: 20,
            ),
            suffix: Text(
              '${widget.selectedIds.length}/${widget.members.length}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
            filled: true,
            fillColor: AppColors.fieldColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            _SelectAllToggle(
              selectedCount: widget.selectedIds.length,
              totalCount: widget.members.length,
              enabled: widget.enabled,
              onTap: (selectAll) =>
                  widget.onSelectAll(selectAll, widget.members),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(14),
          color: AppColors.fieldColor,
          child: filteredMembers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Sin resultados para tu búsqueda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                  ),
                )
              : Column(
                  children: [
                    for (final member in filteredMembers)
                      _MemberCheckTile(
                        member: member,
                        selected: widget.selectedIds.contains(member.id),
                        enabled: widget.enabled,
                        onChanged: (selected) =>
                            widget.onToggle(member.id, selected),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.mutedText, size: 16),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Quedarás asociado automáticamente a la cuenta.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Elegí a quiénes invitar a esta cuenta',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }
}

class _MemberCheckTile extends StatelessWidget {
  const _MemberCheckTile({
    required this.member,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final GetMemberResponseModel member;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  String get _initials {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!selected) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                _initials,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.name,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                key: ValueKey(selected),
                color: selected ? AppColors.primary : AppColors.mutedText,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectAllToggle extends StatelessWidget {
  const _SelectAllToggle({
    required this.selectedCount,
    required this.totalCount,
    required this.enabled,
    required this.onTap,
  });

  final int selectedCount;
  final int totalCount;
  final bool enabled;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) {
    final allSelected = totalCount > 0 && selectedCount == totalCount;

    return InkWell(
      onTap: enabled ? () => onTap(!allSelected) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          allSelected
              ? 'Deseleccionar todos ($selectedCount/$totalCount)'
              : 'Seleccionar todos ($selectedCount/$totalCount)',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
