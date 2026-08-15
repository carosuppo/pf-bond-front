import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../location/models/map_route_arguments.dart';
import '../providers/group_provider.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadGroups();
    });
  }

  Future<void> _createGroup() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.createGroup,
    );

    if (!mounted) {
      return;
    }

    await context.read<GroupProvider>().loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis grupos'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(GroupProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: provider.loadGroups,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.group_outlined,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Todavía no pertenecés a ningún grupo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _createGroup,
                icon: const Icon(Icons.add),
                label: const Text('Crear grupo'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadGroups,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: provider.groups.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final group = provider.groups[index];

          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.group),
            ),
            title: Text(group.name),
            subtitle:
                group.description != null && group.description!.isNotEmpty
                ? Text(group.description!)
                : null,
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.map,
                arguments: MapRouteArguments(
                  groupId: int.parse(group.id),
                  groupName: group.name,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
