import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../notification/services/push_notification_service.dart';
import '../formatters/event_date_formatter.dart';
import '../providers/event_reminder_provider.dart';
import '../utils/event_reminder_options.dart';

class EventReminderSheet extends StatefulWidget {
  final int groupId;
  final int eventId;
  final String eventName;
  final DateTime eventStartAt;

  const EventReminderSheet({
    super.key,
    required this.groupId,
    required this.eventId,
    required this.eventName,
    required this.eventStartAt,
  });

  @override
  State<EventReminderSheet> createState() => _EventReminderSheetState();
}

class _EventReminderSheetState extends State<EventReminderSheet> {
  late Set<int> _saved;
  bool _adding = false;
  int? _draftPreset;
  bool _customOpen = false;
  final _customController = TextEditingController();
  ReminderUnit _customUnit = ReminderUnit.hour;
  String? _formError;
  bool? _systemPermissionGranted;
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _saved = context
        .read<EventReminderProvider>()
        .reminders
        .map((reminder) => reminder.leadMinutes)
        .toSet();
    _adding = _saved.isEmpty;
    _customController.addListener(_onCustomDraftChanged);
    _checkSystemPermission();
  }

  void _onCustomDraftChanged() {
    if (!mounted || !_customOpen) return;
    setState(() {});
  }

  int? _previewLead() {
    if (!_adding) return null;
    if (_customOpen) {
      return EventReminderOptions.customToLeadMinutes(
        _customController.text,
        _customUnit,
      );
    }
    return _draftPreset;
  }

  Future<void> _checkSystemPermission() async {
    try {
      final status = await context
          .read<PushNotificationService>()
          .getPermissionStatus();
      if (!mounted) return;
      setState(() {
        _systemPermissionGranted =
            status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _systemPermissionGranted = null);
    }
  }

  Future<void> _askSystemPermission() async {
    setState(() => _requestingPermission = true);
    try {
      final status = await context
          .read<PushNotificationService>()
          .requestPermission();
      if (!mounted) return;
      setState(() {
        _systemPermissionGranted =
            status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
      });
    } catch (_) {
      // Se mantiene el aviso visible ante cualquier fallo.
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  @override
  void dispose() {
    _customController.removeListener(_onCustomDraftChanged);
    _customController.dispose();
    super.dispose();
  }

  Map<int, DateTime> _remindAts() {
    final reminders = context.read<EventReminderProvider>().reminders;
    return {
      for (final reminder in reminders) reminder.leadMinutes: reminder.remindAt,
    };
  }

  void _syncSaved() {
    _saved = context
        .read<EventReminderProvider>()
        .reminders
        .map((reminder) => reminder.leadMinutes)
        .toSet();
  }

  String? _validateLead(int lead) {
    final remindAt = widget.eventStartAt.subtract(Duration(minutes: lead));
    if (!remindAt.isAfter(DateTime.now())) {
      return '${EventReminderOptions.formatLeadMinutes(lead)} ya pasó: el evento empieza antes.';
    }
    return null;
  }

  Future<void> _delete(int lead) async {
    final provider = context.read<EventReminderProvider>();
    final remaining = _saved.where((item) => item != lead).toList();
    final ok = await provider.save(
      groupId: widget.groupId,
      eventId: widget.eventId,
      leadMinutes: remaining,
    );
    if (!ok || !mounted) return;
    setState(() {
      _syncSaved();
      _adding = _saved.isEmpty;
    });
  }

  Future<void> _saveNew() async {
    final int? lead;
    if (_customOpen) {
      final parsed = EventReminderOptions.customToLeadMinutes(
        _customController.text,
        _customUnit,
      );
      if (parsed == null) {
        setState(() {
          _formError =
              'Ingresá un valor de 1 en adelante (máximo 4 semanas en total).';
        });
        return;
      }
      lead = parsed;
    } else {
      lead = _draftPreset;
    }

    if (lead == null) {
      setState(() {
        _formError = 'Elegí una anticipación.';
      });
      return;
    }

    if (_saved.contains(lead)) {
      setState(() {
        _formError = 'Esa anticipación ya está agregada.';
      });
      return;
    }

    final invalid = _validateLead(lead);
    if (invalid != null) {
      setState(() => _formError = invalid);
      return;
    }

    setState(() => _formError = null);

    final provider = context.read<EventReminderProvider>();
    final ok = await provider.save(
      groupId: widget.groupId,
      eventId: widget.eventId,
      leadMinutes: [..._saved, lead],
    );
    if (!ok || !mounted) return;
    setState(() {
      _syncSaved();
      _adding = false;
      _draftPreset = null;
      _customOpen = false;
      _customController.clear();
    });
  }

  void _cancelAdding() {
    setState(() {
      _adding = _saved.isEmpty;
      _draftPreset = null;
      _customOpen = false;
      _formError = null;
      _customController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventReminderProvider>();
    final remindAts = _remindAts();
    final sorted = _saved.toList(growable: false)..sort();
    final availablePresets = EventReminderOptions.presets
        .where((preset) => !_saved.contains(preset))
        .toList(growable: false);
    final previewLead = _previewLead();
    final previewRemindAt = previewLead == null
        ? null
        : widget.eventStartAt.subtract(Duration(minutes: previewLead));
    final previewInvalid = previewLead == null
        ? null
        : _validateLead(previewLead);
    final previewDuplicated =
        previewLead != null && _saved.contains(previewLead);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recordatorios',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: AppColors.text),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
            Text(
              '${widget.eventName} · '
              '${EventDateFormatter.fullDayDateTime(widget.eventStartAt)}',
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (_systemPermissionGranted == false) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: AppColors.fieldColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Las notificaciones del sistema están desactivadas: '
                        'los recordatorios no se van a mostrar.',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _requestingPermission
                          ? null
                          : _askSystemPermission,
                      child: _requestingPermission
                          ? const AppLoadingIndicator(size: 16)
                          : const Text('Activar'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final lead in sorted) ...[
              _ReminderCard(
                title: EventReminderOptions.presetLabel(lead),
                subtitle:
                    'Se enviará el ${EventDateFormatter.weekdayTime(remindAts[lead] ?? widget.eventStartAt)}',
                busy: provider.isSaving,
                onDelete: () => _delete(lead),
              ),
              const SizedBox(height: 12),
            ],
            if (_saved.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: provider.isSaving
                      ? null
                      : () {
                          setState(() {
                            _adding = true;
                            _formError = null;
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.mutedText),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '+ Agregar recordatorio',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (_adding) ...[
              const Divider(height: 32, color: AppColors.border),
              const Text(
                'Nuevo recordatorio',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Puedes agregar más de uno para este evento.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 14),
              ),
              const SizedBox(height: 12),
              for (final preset in availablePresets) ...[
                _OptionCard(
                  label: EventReminderOptions.presetLabel(preset),
                  selected: _draftPreset == preset && !_customOpen,
                  onTap: provider.isSaving
                      ? null
                      : () {
                          setState(() {
                            _draftPreset = preset;
                            _customOpen = false;
                            _formError = null;
                          });
                        },
                ),
                const SizedBox(height: 10),
              ],
              _OptionCard(
                label: 'Personalizar',
                selected: _customOpen,
                onTap: provider.isSaving
                    ? null
                    : () {
                        setState(() {
                          _customOpen = !_customOpen;
                          if (_customOpen) _draftPreset = null;
                          _formError = null;
                        });
                      },
              ),
              if (_customOpen) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.text),
                        decoration: const InputDecoration(
                          hintText: '2',
                          hintStyle: TextStyle(color: AppColors.placeholder),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<ReminderUnit>(
                        initialValue: _customUnit,
                        items: [
                          for (final unit in ReminderUnit.values)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                        ],
                        onChanged: (unit) {
                          if (unit != null) {
                            setState(() => _customUnit = unit);
                          }
                        },
                        style: const TextStyle(color: AppColors.text),
                        dropdownColor: AppColors.surface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'antes del evento',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (previewLead != null && previewRemindAt != null) ...[
                const SizedBox(height: 12),
                _PreviewBanner(
                  remindAt: previewRemindAt,
                  invalidMessage: previewInvalid,
                  duplicated: previewDuplicated,
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: provider.isSaving ? null : _cancelAdding,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.mutedText),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: provider.isSaving ? null : _saveNew,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: provider.isSaving
                          ? const AppLoadingIndicator(
                              size: 22,
                              color: Colors.black,
                            )
                          : const Text(
                              'Guardar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onDelete,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.fieldColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  final DateTime remindAt;
  final String? invalidMessage;
  final bool duplicated;

  const _PreviewBanner({
    required this.remindAt,
    required this.invalidMessage,
    required this.duplicated,
  });

  @override
  Widget build(BuildContext context) {
    final hasProblem = invalidMessage != null || duplicated;
    final borderColor = hasProblem ? AppColors.error : AppColors.primary;
    final icon = hasProblem
        ? Icons.warning_amber_outlined
        : Icons.schedule_outlined;

    final String message;
    if (invalidMessage != null) {
      message = invalidMessage!;
    } else if (duplicated) {
      message = 'Esa anticipación ya está agregada. Todavía no se guardó nada.';
    } else {
      message =
          'Se enviaría el ${EventDateFormatter.fullDayDateTime(remindAt)}.\nTodavía no se guardó: revisá y tocá Guardar.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
