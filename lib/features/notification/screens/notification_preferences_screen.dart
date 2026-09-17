import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../models/notification_preferences.dart';
import '../providers/notification_preferences_provider.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationPreferencesProvider>();
    final data = state.preferences;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Notificaciones',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : data == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.errorMessage ??
                                'No se pudieron cargar las preferencias.',
                          ),
                          TextButton(
                            onPressed: state.load,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: state.load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (state.isSaving) const LinearProgressIndicator(),
                          if (state.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                state.errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          SwitchListTile(
                            title: const Text('Notificaciones de Bond'),
                            subtitle: const Text(
                              'Permite recibir notificaciones de tus grupos.',
                            ),
                            value: data.enabled,
                            onChanged: state.isSaving ? null : state.setGlobal,
                          ),
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Notificaciones por grupo'),
                          ),
                          if (data.groups.isEmpty)
                            const ListTile(
                              title: Text(
                                'No perteneces a ningún grupo activo.',
                              ),
                            ),
                          for (final group in data.groups)
                            ListTile(
                              title: Text(group.groupName),
                              subtitle: Text(
                                !group.enabled
                                    ? 'Silenciadas'
                                    : group.types.values.every((value) => value)
                                    ? 'Todas habilitadas'
                                    : 'Personalizadas',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              enabled: data.enabled && !state.isSaving,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChangeNotifierProvider.value(
                                      value: state,
                                      child: GroupNotificationPreferencesScreen(
                                        groupId: group.groupId,
                                      ),
                                    ),
                                  ),
                                );
                                if (context.mounted) await state.load();
                              },
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
}

class GroupNotificationPreferencesScreen extends StatelessWidget {
  final int groupId;
  const GroupNotificationPreferencesScreen({super.key, required this.groupId});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationPreferencesProvider>();
    final groups = state.preferences?.groups.where(
      (group) => group.groupId == groupId,
    );
    final GroupNotificationPreferences? group = groups == null || groups.isEmpty
        ? null
        : groups.first;
    final enabled =
        state.preferences?.enabled == true &&
        !state.isSaving &&
        !state.isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Text(group?.groupName ?? 'Notificaciones del grupo'),
      ),
      body: group == null
          ? const Center(child: Text('Este grupo ya no está disponible.'))
          : ListView(
              children: [
                if (state.isSaving) const LinearProgressIndicator(),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Notificaciones de este grupo'),
                  value: group.enabled,
                  onChanged: enabled
                      ? (value) => state.setGroup(group, value)
                      : null,
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tipos de notificación'),
                ),
                for (final entry in notificationTypeLabels.entries)
                  SwitchListTile(
                    title: Text(entry.value),
                    value: group.types[entry.key] ?? true,
                    onChanged: enabled && group.enabled
                        ? (value) => state.setType(group, entry.key, value)
                        : null,
                  ),
              ],
            ),
    );
  }
}
