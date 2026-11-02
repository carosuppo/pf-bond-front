import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/get_member_info_model.response.dart';
import '../models/member_report_request.dart';
import '../services/group_service.dart';

class MemberInfoBottomSheet extends StatelessWidget {
  final GetMemberInfoResponseModel memberInfo;
  final ScrollController scrollController;

  const MemberInfoBottomSheet({
    super.key,
    required this.memberInfo,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  UserAvatar(
                    name: memberInfo.name,
                    photoUrl: memberInfo.profilePhoto,
                    radius: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    memberInfo.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.fieldColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.update_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Última actualización de ubicación',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatLastSeenAt(memberInfo.lastSeenAt),
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reportMember(context),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Denunciar usuario'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _blockMember(context),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Bloquear'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportMember(BuildContext context) async {
    final report = await showDialog<MemberReportRequest>(
      context: context,
      builder: (_) => _ReportMemberDialog(memberName: memberInfo.name),
    );
    if (report == null || !context.mounted) return;

    try {
      await context.read<GroupService>().reportMember(
        memberId: memberInfo.memberId,
        request: report,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recibimos la denuncia y la revisaremos.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _blockMember(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: Text(
          'Al bloquear a ${memberInfo.name}, ambos dejarán de ver el perfil y la ubicación del otro en los grupos que comparten. Ninguno será expulsado y los grupos y su contenido se conservarán para sus miembros. No podrán incorporarse a nuevos grupos donde ya esté la otra persona. Podés deshacer el bloqueo desde Configuración > Usuarios bloqueados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<GroupService>().blockMember(
        memberId: memberInfo.memberId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuario bloqueado.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }
}

class _ReportMemberDialog extends StatefulWidget {
  const _ReportMemberDialog({required this.memberName});

  final String memberName;

  @override
  State<_ReportMemberDialog> createState() => _ReportMemberDialogState();
}

class _ReportMemberDialogState extends State<_ReportMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  MemberReportReason? _reason;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      MemberReportRequest(
        reason: _reason!,
        details: _detailsController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Denunciar usuario'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Contanos qué problema tuviste con ${widget.memberName}. La denuncia se enviará al equipo de Bond para su revisión.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MemberReportReason>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: MemberReportReason.values
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (reason) => setState(() => _reason = reason),
                validator: (reason) =>
                    reason == null ? 'Seleccioná un motivo.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsController,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detalles (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enviar denuncia')),
      ],
    );
  }
}

class MemberInfoLoading extends StatelessWidget {
  final ScrollController scrollController;

  const MemberInfoLoading({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        child: Column(
          children: [
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLastSeenAt(DateTime? lastSeenAt) {
  if (lastSeenAt == null) {
    return 'Sin actualización registrada';
  }

  final localDate = lastSeenAt.toLocal();
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  final dateLabel = _isSameDay(localDate, now)
      ? 'Hoy'
      : _isSameDay(localDate, yesterday)
      ? 'Ayer'
      : '${localDate.day.toString().padLeft(2, '0')}/'
            '${localDate.month.toString().padLeft(2, '0')}/'
            '${localDate.year}';

  final time =
      '${localDate.hour.toString().padLeft(2, '0')}:'
      '${localDate.minute.toString().padLeft(2, '0')}';

  return '$dateLabel, $time';
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
