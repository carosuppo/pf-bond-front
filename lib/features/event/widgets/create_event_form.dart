import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/timezone/app_timezone.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/global_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../group/models/get_member_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../models/event_model.response.dart';
import '../models/update_event_model.request.dart';
import '../providers/event_provider.dart';
import 'event_date_time_picker.dart';

class CreateEventForm extends StatefulWidget {
  final EventResponseModel? initialEvent;
  final int? groupId;

  const CreateEventForm({super.key, this.initialEvent, this.groupId});

  @override
  State<CreateEventForm> createState() => _CreateEventFormState();
}

class _CreateEventFormState extends State<CreateEventForm> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _startAt;
  DateTime? _endAt;

  final Set<int> _selectedMemberIds = {};

  String _initialName = '';
  String _initialDescription = '';
  DateTime? _initialStartAt;
  DateTime? _initialEndAt;
  final Set<int> _initialMemberIds = {};

  bool get _isEditing => widget.initialEvent != null;

  @override
  void initState() {
    super.initState();

    final initialEvent = widget.initialEvent;

    if (initialEvent != null) {
      _nameController.text = initialEvent.name;
      _descriptionController.text = initialEvent.description ?? '';

      _startAt = AppTimezone.fromUtc(initialEvent.startAt);
      _endAt = initialEvent.endAt != null
          ? AppTimezone.fromUtc(initialEvent.endAt!)
          : null;

      _initialName = initialEvent.name.trim();
      _initialDescription = (initialEvent.description ?? '').trim();
      _initialStartAt = _startAt;
      _initialEndAt = _endAt;

      final selfMemberId = _selfMemberId();
      _selectedMemberIds.addAll(
        initialEvent.memberIds.where((id) => id != selfMemberId),
      );
      _initialMemberIds.addAll(_selectedMemberIds);
    }
  }

  int? _selfMemberId() {
    final currentUserId = context.read<AuthProvider>().authResponse?.user.id;
    final members = context.read<GroupProvider>().groupDetails?.members ?? [];

    for (final member in members) {
      if (member.idUser == currentUserId) {
        return member.id;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _selectStartDateTime() async {
    FocusScope.of(context).unfocus();

    final result = await showEventDateTimePicker(
      context: context,
      type: EventDateTimePickerType.start,
      initialDateTime: _startAt,
    );

    if (!mounted || result == null) {
      return;
    }

    final selectedDateTime = result.dateTime;

    setState(() {
      _startAt = selectedDateTime;

      if (_endAt != null && !_endAt!.isAfter(selectedDateTime)) {
        _endAt = null;
      }
    });
  }

  Future<void> _selectEndDateTime() async {
    FocusScope.of(context).unfocus();

    if (_startAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debes seleccionar la fecha y hora de inicio.'),
        ),
      );

      return;
    }

    final result = await showEventDateTimePicker(
      context: context,
      type: EventDateTimePickerType.end,
      initialDateTime: _endAt ?? _startAt,
      startDateTime: _startAt,
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _endAt = result.dateTime;
    });
  }

  void _clearEndDateTime() {
    FocusScope.of(context).unfocus();

    setState(() {
      _endAt = null;
    });
  }

  Future<void> _saveEvent() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del evento es obligatorio.')),
      );

      return;
    }

    if (_startAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y hora de inicio son obligatorias.'),
        ),
      );

      return;
    }

    final startChanged = !_isEditing || _startAt != _initialStartAt;

    if (startChanged && !_startAt!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha y hora de inicio deben ser posteriores a la fecha actual.',
          ),
        ),
      );

      return;
    }

    if (_endAt != null && !_endAt!.isAfter(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha y hora de finalización deben ser posteriores al inicio.',
          ),
        ),
      );

      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final eventProvider = context.read<EventProvider>();

    final groupId = widget.groupId ?? groupProvider.activeGroup?.id;

    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un grupo activo seleccionado.')),
      );

      return;
    }

    if (_isEditing) {
      await _updateEvent(groupId, eventProvider, name, description);
      return;
    }

    final success = await eventProvider.createEvent(
      groupId: groupId,
      name: name,
      description: description.isEmpty ? null : description,
      startAt: _startAt!,
      endAt: _endAt,
      memberIds: _selectedMemberIds.toList(),
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eventProvider.errorMessage ?? 'Error al crear el evento.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _updateEvent(
    int groupId,
    EventProvider eventProvider,
    String name,
    String description,
  ) async {
    final request = UpdateEventRequestModel(
      name: name == _initialName ? null : name,
      description: description == _initialDescription ? null : description,
      clearDescription: description.isEmpty && _initialDescription.isNotEmpty,
      startAt: _startAt == _initialStartAt ? null : _startAt,
      endAt: _endAt == _initialEndAt ? null : _endAt,
      clearEndAt: _endAt == null && _initialEndAt != null,
      memberIds: _sameMemberIds ? null : _selectedMemberIds.toList(),
    );

    if (request.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios para guardar.')),
      );
      return;
    }

    final success = await eventProvider.updateEvent(
      groupId: groupId,
      eventId: widget.initialEvent!.id,
      request: request,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eventProvider.errorMessage ?? 'Error al actualizar el evento.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  bool get _sameMemberIds =>
      _selectedMemberIds.length == _initialMemberIds.length &&
      _selectedMemberIds.containsAll(_initialMemberIds);

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Seleccionar';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }

  bool get _hasChanges {
    if (_isEditing) {
      return _nameController.text.trim() != _initialName ||
          _descriptionController.text.trim() != _initialDescription ||
          _startAt != _initialStartAt ||
          _endAt != _initialEndAt ||
          !_sameMemberIds;
    }

    return _nameController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _startAt != null ||
        _endAt != null ||
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
    final groupProvider = context.watch<GroupProvider>();
    final eventProvider = context.watch<EventProvider>();
    final authProvider = context.watch<AuthProvider>();

    final currentUserId = authProvider.authResponse?.user.id;

    final members = (groupProvider.groupDetails?.members ?? [])
        .where((member) => member.idUser != currentUserId)
        .toList();
    final isLoading = eventProvider.isLoading;

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
                            const SizedBox(height: 20),

                            Text(
                              _isEditing ? 'Editar evento' : 'Crear evento',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 24),

                            GlobalTextField(
                              controller: _nameController,
                              label: 'Nombre del evento',
                            ),

                            const SizedBox(height: 16),

                            GlobalTextField(
                              controller: _descriptionController,
                              label: 'Descripción (opcional)',
                            ),

                            const SizedBox(height: 16),

                            _DateTimeField(
                              label: 'Comienza',
                              value: _formatDateTime(_startAt),
                              onTap: isLoading ? null : _selectStartDateTime,
                            ),

                            const SizedBox(height: 16),

                            _DateTimeField(
                              label: 'Finaliza (opcional)',
                              value: _formatDateTime(_endAt),
                              onTap: isLoading ? null : _selectEndDateTime,
                              onClear: isLoading || _endAt == null
                                  ? null
                                  : _clearEndDateTime,
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Text(
                                  'Asociar miembros',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_selectedMemberIds.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_selectedMemberIds.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                if (members.isNotEmpty)
                                  _SelectAllToggle(
                                    allSelected: members.every(
                                      (m) => _selectedMemberIds.contains(m.id),
                                    ),
                                    enabled: !isLoading,
                                    onTap: (selectAll) {
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
                              ],
                            ),

                            const SizedBox(height: 4),

                            Text(
                              'Elegí a quiénes invitar a este evento',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedText,
                              ),
                            ),

                            const SizedBox(height: 12),

                            if (members.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.fieldColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'No hay miembros disponibles para asociar.',
                                  style: TextStyle(color: AppColors.mutedText),
                                ),
                              )
                            else
                              _MemberAssociationSection(
                                members: members,
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
                              ),

                            const SizedBox(height: 24),

                            AppPrimaryButton(
                              text: _isEditing
                                  ? 'Guardar cambios'
                                  : 'Crear evento',
                              loading: isLoading,
                              onPressed: _saveEvent,
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

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.fieldColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.mutedText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedText),
            if (onClear != null)
              InkWell(
                onTap: onTap == null ? null : onClear,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.mutedText,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberAssociationSection extends StatefulWidget {
  const _MemberAssociationSection({
    required this.members,
    required this.selectedIds,
    required this.enabled,
    required this.onToggle,
  });

  final List<GetMemberResponseModel> members;
  final Set<int> selectedIds;
  final bool enabled;
  final void Function(int memberId, bool selected) onToggle;

  @override
  State<_MemberAssociationSection> createState() =>
      _MemberAssociationSectionState();
}

class _MemberAssociationSectionState extends State<_MemberAssociationSection> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = _query.isEmpty
        ? widget.members
        : widget.members
              .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(14),
      color: AppColors.fieldColor,
      child: Column(
        children: [
          if (widget.members.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _searchController,
                enabled: widget.enabled,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: AppColors.text, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar miembro...',
                  hintStyle: const TextStyle(color: AppColors.mutedText),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.mutedText,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.03),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          if (filteredMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Sin resultados para tu búsqueda.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 13),
              ),
            )
          else
            for (final member in filteredMembers)
              _MemberAvatarTile(
                member: member,
                selected: widget.selectedIds.contains(member.id),
                enabled: widget.enabled,
                onChanged: (selected) => widget.onToggle(member.id, selected),
              ),
        ],
      ),
    );
  }
}

class _MemberAvatarTile extends StatelessWidget {
  const _MemberAvatarTile({
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
    required this.allSelected,
    required this.enabled,
    required this.onTap,
  });

  final bool allSelected;
  final bool enabled;
  final ValueChanged<bool> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onTap(!allSelected) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          allSelected ? 'Deseleccionar todos' : 'Seleccionar todos',
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
