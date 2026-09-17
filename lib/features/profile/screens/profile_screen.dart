import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(_loadProfile);
  }

  Future<void> _loadProfile() async {
    final profileProvider = context.read<ProfileProvider>();

    await profileProvider.loadProfileAndGroups();

    if (!mounted) {
      return;
    }

    setState(() {
      _hasLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Mi perfil',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(child: _buildBody(profileProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ProfileProvider profileProvider) {
    if (!_hasLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final user = profileProvider.user;

    if (user == null) {
      return _buildError(profileProvider);
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppColors.primary,
      backgroundColor: AppColors.cardColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        children: [
          _ProfileHeader(name: user.name, email: user.email),
          const SizedBox(height: 32),
          const Text(
            'Mis grupos',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (profileProvider.groups.isEmpty)
            const _EmptyGroupsMessage()
          else
            ..._buildGroupItems(profileProvider),
        ],
      ),
    );
  }

  Widget _buildError(ProfileProvider profileProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              profileProvider.errorMessage ?? 'No se pudo cargar tu perfil.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadProfile,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupItems(ProfileProvider profileProvider) {
    final items = <Widget>[];

    for (var index = 0; index < profileProvider.groups.length; index++) {
      if (index > 0) {
        items.add(const SizedBox(height: 10));
      }

      items.add(_GroupTile(name: profileProvider.groups[index].name));
    }

    return items;
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primary,
          child: Text(
            _initial,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 15),
        ),
      ],
    );
  }

  String get _initial {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return '?';
    }

    return trimmedName[0].toUpperCase();
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroupsMessage extends StatelessWidget {
  const _EmptyGroupsMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.mutedText),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todavía no pertenecés a ningún grupo.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
