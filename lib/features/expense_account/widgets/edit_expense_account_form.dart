import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/buttons/app_primary_button.dart';
import '../../../core/widgets/buttons/app_secondary_button.dart';
import '../../../core/widgets/discard_changes_dialog.dart';
import '../../../core/widgets/global_text_field.dart';
import '../../event/formatters/event_date_formatter.dart';
import '../../event/models/event_model.response.dart';
import '../../event/providers/event_provider.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/models/get_member_model.response.dart';
import '../../group/providers/group_provider.dart';
import '../models/expense_account_detail_model.response.dart';
import '../models/update_expense_account_model.request.dart';
import '../providers/expense_account_provider.dart';
import 'member_check_tile.dart';

class EditExpenseAccountForm extends StatefulWidget {
  const EditExpenseAccountForm({super.key, required this.accountId});

  final int accountId;

  @override
  State<EditExpenseAccountForm> createState() => _EditExpenseAccountFormState();
}

class _EditExpenseAccountFormState extends State<EditExpenseAccountForm> {
  static const int _nameMaxLength = 100;

  final TextEditingController _nameController = TextEditingController();
  final Set<int> _selectedMemberIds = {};
  final Set<int> _initialMemberIds = {};

  late final ExpenseAccountProvider _expenseAccountProvider;
  ExpenseAccountDetailResponseModel? _initialDetail;
  GetGroupResponseModel? _groupDetails;
  List<EventResponseModel> _events = [];
  EventResponseModel? _selectedEvent;
  int? _initialEventId;
  int? _selectedEventId;
  bool _isInitializing = true;
  bool _isLoadingEvents = false;
  String? _loadError;
  String? _eventsError;
  String? _memberSearch;

  @override
  void initState() {
    super.initState();
    _expenseAccountProvider = context.read<ExpenseAccountProvider>();
    _nameController.addListener(_onNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    final groupProvider = context.read<GroupProvider>();

    setState(() {
      _isInitializing = true;
      _loadError = null;
    });

    try {
      var detail = _expenseAccountProvider.accountDetail;
      if (detail?.id != widget.accountId) {
        await _expenseAccountProvider.loadAccountDetail(
          accountId: widget.accountId,
          force: true,
        );
        detail = _expenseAccountProvider.accountDetail;
      }

      if (detail == null || detail.id != widget.accountId) {
        throw StateError(
          _expenseAccountProvider.detailErrorMessage ??
              'No se pudo cargar la cuenta.',
        );
      }

      _initialDetail = detail;
      _nameController.text = detail.name;
      _initialEventId = detail.eventId;
      _selectedEventId = detail.eventId;
      _initialMemberIds
        ..clear()
        ..addAll(detail.members.map((member) => member.memberId));
      _selectedMemberIds
        ..clear()
        ..addAll(_initialMemberIds);

      final groupDetails = await groupProvider.getGroupDetailsForAccount(
        groupId: detail.groupId,
      );
      if (!mounted) return;
      if (groupDetails == null || groupDetails.id != detail.groupId) {
        throw StateError('No se pudieron cargar los miembros del grupo.');
      }
      _groupDetails = groupDetails;
      await _reloadEvents();
    } catch (error) {
      if (!mounted) return;
      _loadError = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _reloadEvents() async {
    final detail = _initialDetail;
    if (detail == null) return;

    setState(() {
      _isLoadingEvents = true;
      _eventsError = null;
    });

    final eventProvider = context.read<EventProvider>();
    await eventProvider.loadEvents(groupId: detail.groupId);
    if (!mounted) return;

    final events = [...eventProvider.events];
    String? eventsError = eventProvider.errorMessage;
    final selectedEventId = _selectedEventId;
    EventResponseModel? selectedEvent;

    for (final event in events) {
      if (event.id == selectedEventId) {
        selectedEvent = event;
        break;
      }
    }

    if (selectedEventId != null && selectedEvent == null) {
      try {
        selectedEvent = await eventProvider.getEventById(
          groupId: detail.groupId,
          eventId: selectedEventId,
        );
        if (!events.any((event) => event.id == selectedEventId)) {
          events.add(selectedEvent);
        }
      } catch (error) {
        eventsError ??= error.toString().replaceFirst('Exception: ', '');
      }
    }

    if (!mounted) return;
    setState(() {
      _events = events..sort((a, b) => a.startAt.compareTo(b.startAt));
      _selectedEvent = selectedEvent;
      _eventsError = eventsError;
      _isLoadingEvents = false;
    });
  }

  bool get _eventChanged => _selectedEventId != _initialEventId;

  bool get _hasChanges {
    final detail = _initialDetail;
    if (detail == null) return false;

    final sameMembers =
        _selectedMemberIds.length == _initialMemberIds.length &&
        _selectedMemberIds.containsAll(_initialMemberIds);

    return _nameController.text.trim() != detail.name ||
        !sameMembers ||
        _eventChanged;
  }

  Set<int> get _selectedMembersOutsideEvent {
    final event = _selectedEvent;
    if (_selectedEventId == null || event == null) return const {};

    final eventMemberIds = event.memberIds.toSet();
    return _selectedMemberIds
        .where((memberId) => !eventMemberIds.contains(memberId))
        .toSet();
  }

  bool get _canSave {
    final detail = _initialDetail;
    if (detail == null ||
        _isInitializing ||
        _expenseAccountProvider.isUpdatingExpenseAccount ||
        !_hasChanges ||
        _nameController.text.trim().isEmpty ||
        _nameController.text.trim().length > _nameMaxLength ||
        _selectedMemberIds.isEmpty) {
      return false;
    }

    if (_eventChanged && _selectedEventId != null && _selectedEvent == null) {
      return false;
    }

    if (_selectedMembersOutsideEvent.isNotEmpty) return false;
    return true;
  }

  Future<void> _openEventPicker() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
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
                'Evento de la cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _EventChoiceTile(
                      title: 'Sin evento',
                      subtitle: 'Quitar la asociación con un evento',
                      selected: _selectedEventId == null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        setState(() {
                          _selectedEventId = null;
                          _selectedEvent = null;
                        });
                      },
                    ),
                    if (_eventsError != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _InlineMessage(
                          message: _eventsError!,
                          isError: true,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _reloadEvents();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar carga de eventos'),
                      ),
                    ],
                    if (_events.isEmpty && _eventsError == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Este grupo todavía no tiene otros eventos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ),
                    for (final event in _events)
                      _EventChoiceTile(
                        title: event.name,
                        subtitle:
                            '${EventDateFormatter.dayMonth(event.startAt)} · '
                            '${EventDateFormatter.time(event.startAt)}',
                        selected: event.id == _selectedEventId,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          setState(() {
                            _selectedEventId = event.id;
                            _selectedEvent = event;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final detail = _initialDetail;
    if (detail == null || !_canSave) return;

    final request = UpdateExpenseAccountRequestModel(
      name: _nameController.text.trim(),
      memberIds: _selectedMemberIds.toList(growable: false),
      eventId: _selectedEventId,
      updateEvent: _eventChanged,
    );

    final success = await _expenseAccountProvider.updateExpenseAccount(
      accountId: widget.accountId,
      request: request,
    );
    if (!mounted) return;

    if (!success) {
      final message =
          _expenseAccountProvider.updateExpenseAccountErrorMessage ??
          'No se pudo actualizar la cuenta.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta actualizada correctamente.')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _handleBack() async {
    if (_expenseAccountProvider.isUpdatingExpenseAccount) return;
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showDiscardChangesDialog(context);
    if (mounted && discard) Navigator.of(context).pop();
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.mutedText,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'No se pudieron cargar los datos de la cuenta.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _initialize,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(ExpenseAccountDetailResponseModel detail) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.groupName,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'El grupo de la cuenta no se puede cambiar.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, color: AppColors.mutedText, size: 18),
        ],
      ),
    );
  }

  Widget _buildEventCard(ExpenseAccountDetailResponseModel detail) {
    final selected = _selectedEvent;
    final isUnloadedCurrentEvent =
        _selectedEventId != null && selected == null && !_eventChanged;
    final title =
        selected?.name ??
        (isUnloadedCurrentEvent
            ? detail.eventName ?? 'Evento actual'
            : 'Sin evento');
    final subtitle = selected != null
        ? '${EventDateFormatter.dayMonth(selected.startAt)} · '
              '${EventDateFormatter.time(selected.startAt)}'
        : isUnloadedCurrentEvent
        ? 'No se pudo cargar la información del evento actual.'
        : 'La cuenta no está asociada a un evento.';

    return Material(
      color: AppColors.fieldColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap:
            _isLoadingEvents || _expenseAccountProvider.isUpdatingExpenseAccount
            ? null
            : _openEventPicker,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: _isLoadingEvents
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
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

  Widget _buildMembers(GetGroupResponseModel groupDetails) {
    final query = (_memberSearch ?? '').trim().toLowerCase();
    final members = groupDetails.members
        .where((member) => member.name.toLowerCase().contains(query))
        .toList(growable: false);
    final event = _selectedEvent;
    final eventMemberIds = event?.memberIds.toSet() ?? const <int>{};
    final incompatibleIds = _selectedMembersOutsideEvent;

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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${_selectedMemberIds.length}/${groupDetails.members.length}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'El servidor valida que los miembros que quites no tengan obligaciones pendientes.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        if (incompatibleIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _InlineMessage(
            message:
                'Hay miembros seleccionados que no pertenecen al evento. Quitalos de la selección o elegí otro evento.',
            isError: true,
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          enabled: !_expenseAccountProvider.isUpdatingExpenseAccount,
          onChanged: (value) => setState(() => _memberSearch = value),
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar miembros...',
            hintStyle: const TextStyle(color: AppColors.mutedText),
            prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
            filled: true,
            fillColor: AppColors.fieldColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.fieldColor,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: members.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No hay miembros que coincidan con la búsqueda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedText, fontSize: 13),
                  ),
                )
              : Column(
                  children: [
                    for (final member in members)
                      _buildMemberTile(member, event, eventMemberIds),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(
    GetMemberResponseModel member,
    EventResponseModel? event,
    Set<int> eventMemberIds,
  ) {
    final selected = _selectedMemberIds.contains(member.id);
    final belongsToEvent =
        _selectedEventId == null ||
        (event != null && eventMemberIds.contains(member.id));
    final canChange =
        !_expenseAccountProvider.isUpdatingExpenseAccount &&
        (selected || belongsToEvent);

    return MemberCheckTile(
      name: member.name,
      photoUrl: member.profilePhoto,
      selected: selected,
      enabled: canChange,
      trailing: event != null && !belongsToEvent
          ? Text(
              selected ? 'Fuera del evento' : 'No pertenece al evento',
              style: TextStyle(
                color: selected ? AppColors.error : AppColors.mutedText,
                fontSize: 11,
              ),
            )
          : null,
      onChanged: (value) {
        setState(() {
          if (value) {
            _selectedMemberIds.add(member.id);
          } else {
            _selectedMemberIds.remove(member.id);
          }
        });
      },
    );
  }

  Widget _buildChangeSummary() {
    final detail = _initialDetail!;
    final addedCount = _selectedMemberIds
        .difference(_initialMemberIds)
        .length;
    final removedCount = _initialMemberIds
        .difference(_selectedMemberIds)
        .length;
    final changes = <String>[];

    if (_nameController.text.trim() != detail.name) {
      changes.add('Se actualizará el nombre de la cuenta.');
    }
    if (addedCount > 0) {
      changes.add(
        'Se agregarán $addedCount ${addedCount == 1 ? 'miembro' : 'miembros'}.',
      );
    }
    if (removedCount > 0) {
      changes.add(
        'Se quitarán $removedCount ${removedCount == 1 ? 'miembro' : 'miembros'}; '
        'el servidor comprobará que no tengan obligaciones pendientes.',
      );
    }
    if (_eventChanged) {
      changes.add(
        _selectedEventId == null
            ? 'Se quitará la asociación con el evento.'
            : 'El evento cambiará a ${_selectedEvent?.name ?? 'otro evento'}.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cambios',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (changes.isEmpty)
            const Text(
              'Todavía no modificaste la cuenta.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            )
          else
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '• $change',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final detail = _initialDetail!;
    final groupDetails = _groupDetails!;
    final provider = context.watch<ExpenseAccountProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            detail.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Nombre de la cuenta',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GlobalTextField(
            controller: _nameController,
            label: 'Nombre de la cuenta',
            maxLength: _nameMaxLength,
            enabled: !provider.isUpdatingExpenseAccount,
          ),
          const SizedBox(height: 18),
          const Text(
            'Grupo',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildGroupCard(detail),
          const SizedBox(height: 18),
          const Text(
            'Evento',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildEventCard(detail),
          if (_eventsError != null) ...[
            const SizedBox(height: 8),
            _InlineMessage(message: _eventsError!, isError: true),
          ],
          const SizedBox(height: 20),
          _buildMembers(groupDetails),
          const SizedBox(height: 14),
          _buildChangeSummary(),
          if (provider.updateExpenseAccountErrorMessage != null) ...[
            const SizedBox(height: 14),
            _InlineMessage(
              message: provider.updateExpenseAccountErrorMessage!,
              isError: true,
            ),
          ],
          const SizedBox(height: 24),
          AppPrimaryButton(
            text: 'Guardar cambios',
            onPressed: _canSave ? _save : null,
            loading: provider.isUpdatingExpenseAccount,
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            text: 'Cancelar',
            onPressed: provider.isUpdatingExpenseAccount ? null : _handleBack,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseAccountProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _handleBack();
      },
      child: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Editar cuenta',
              onBack: provider.isUpdatingExpenseAccount ? null : _handleBack,
            ),
            Expanded(
              child: _isInitializing
                  ? _buildLoading()
                  : _loadError != null || _initialDetail == null
                  ? _buildLoadError()
                  : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventChoiceTile extends StatelessWidget {
  const _EventChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.mutedText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
