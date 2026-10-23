import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../group/models/group_join_request.dart';
import '../models/group_inbox_item.dart';
import '../providers/group_inbox_provider.dart';

class GroupInboxScreen extends StatefulWidget {
  const GroupInboxScreen({super.key});

  @override
  State<GroupInboxScreen> createState() => _GroupInboxScreenState();
}

class _GroupInboxScreenState extends State<GroupInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<GroupInboxProvider>().load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupInboxProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Buzón de entrada',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: provider.isLoading && provider.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: provider.load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (provider.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                provider.errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          if (provider.items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 72),
                              child: Center(
                                child: Text(
                                  'No hay notificaciones de tus grupos.',
                                  style: TextStyle(color: AppColors.mutedText),
                                ),
                              ),
                            ),
                          for (final item in provider.items)
                            _InboxTile(
                              item: item,
                              onTap: () => _openItem(context, provider, item),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openItem(
    BuildContext context,
    GroupInboxProvider provider,
    GroupInboxItem item,
  ) async {
    final request = item.joinRequest;
    if (request != null) {
      await _showJoinRequest(context, provider, request);
      return;
    }

    final marked = await provider.markRead(item);
    if (!marked && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'No se pudo actualizar.'),
        ),
      );
    }
  }

  Future<void> _showJoinRequest(
    BuildContext context,
    GroupInboxProvider provider,
    GroupJoinRequest request,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Solicitud para ${request.groupName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              name: request.requesterName,
              photoUrl: request.requesterProfilePhoto,
              radius: 34,
            ),
            const SizedBox(height: 16),
            Text(
              '${request.requesterName} quiere ingresar al grupo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Rechazar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (accepted == null || !context.mounted) return;

    final success = await provider.respondToRequest(
      requestId: request.id,
      accept: accepted,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? accepted
                    ? 'Solicitud aceptada.'
                    : 'Solicitud rechazada.'
              : provider.errorMessage ?? 'No se pudo resolver la solicitud.',
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.onTap});

  final GroupInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = item.isJoinRequest
        ? Icons.person_add_alt_1_rounded
        : switch (item.type) {
            'POINT_OF_INTEREST_ENTERED' => Icons.login_rounded,
            'POINT_OF_INTEREST_EXITED' => Icons.logout_rounded,
            'EVENT_REMINDER' => Icons.event_available_rounded,
            'EVENT_CANCELLED' => Icons.event_busy_rounded,
            _ => Icons.notifications_none_rounded,
          };

    return Card(
      color: AppColors.cardColor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.fieldColor,
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(item.title),
        subtitle: Text('${item.body}\n${item.groupName}'),
        isThreeLine: true,
        trailing: item.isRead
            ? null
            : const Icon(Icons.circle, color: AppColors.primary, size: 10),
      ),
    );
  }
}
