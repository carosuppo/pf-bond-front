import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/get_groups_model.response.dart';
import '../providers/group_provider.dart';

class GroupSelectorButton extends StatefulWidget {
  const GroupSelectorButton({super.key});

  @override
  State<GroupSelectorButton> createState() => _GroupSelectorButtonState();
}

class _GroupSelectorButtonState extends State<GroupSelectorButton> {
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;

  bool get _isOpen => _overlayEntry != null;

  @override
  void dispose() {
    _removeOverlay(rebuild: false);
    super.dispose();
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final groupProvider = context.read<GroupProvider>();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              width: 250,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,

                targetAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topCenter,
                offset: Offset.zero,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: 250,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _GroupList(
                        groups: groupProvider.groups,
                        activeGroupId: groupProvider.activeGroup?.id,
                        onGroupSelected: (group) async {
                          await groupProvider.selectGroup(group);

                          if (mounted) {
                            _removeOverlay();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);

    setState(() {});
  }

  void _removeOverlay({bool rebuild = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (rebuild && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (_isOpen) {
          _removeOverlay();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Center(
          child: SizedBox(
            width: 250,
            child: FilledButton(
              onPressed: _toggleOverlay,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cardColor,
                foregroundColor: AppColors.text,
                elevation: 0,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: AppColors.border, width: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      groupProvider.activeGroup?.name ?? 'Seleccionar grupo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  final List<GetGroupsResponseModel> groups;
  final int? activeGroupId;
  final Future<void> Function(GetGroupsResponseModel group) onGroupSelected;

  const _GroupList({
    required this.groups,
    required this.activeGroupId,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  color: AppColors.mutedText,
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No pertenecés a ningún grupo.',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];

                return _GroupListItem(
                  group: group,
                  isSelected: group.id == activeGroupId,
                  onTap: () => onGroupSelected(group),
                );
              },
            ),
          ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Divider(height: 1, color: AppColors.divider),
        ),

        InkWell(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.createGroup);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                _ActionIcon(icon: Icons.add_rounded),
                SizedBox(width: 12),
                Text(
                  'Crear grupo',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.joinGroup);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                _ActionIcon(icon: Icons.group_add_rounded),
                SizedBox(width: 12),
                Text(
                  'Unirse a grupo',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupListItem extends StatelessWidget {
  final GetGroupsResponseModel group;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupListItem({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.fieldColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.fieldColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.mutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;

  const _ActionIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.fieldColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );
  }
}
