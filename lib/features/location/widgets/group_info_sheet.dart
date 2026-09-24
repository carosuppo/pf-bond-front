import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../group/models/get_group_model.response.dart';
import '../../group/models/get_member_info_model.response.dart';
import '../../group/widgets/group_info_bottom_sheet.dart';
import '../../group/widgets/member_info_bottom_sheet.dart';

enum _GroupSheetSection { overview, members, points }

class GroupInfoSheet extends StatefulWidget {
  static const minChildSize = 0.215;
  static const maxChildSize = 0.5;

  final DraggableScrollableController controller;
  final GetGroupResponseModel group;
  final GetMemberInfoResponseModel? memberInfo;
  final bool memberInfoLoading;
  final Widget pointsContent;
  final int pointsCount;
  final ValueChanged<ScrollController> onScrollControllerChanged;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;
  final ValueChanged<bool>? onPointsSectionChanged;

  const GroupInfoSheet({
    super.key,
    required this.controller,
    required this.group,
    required this.memberInfo,
    required this.memberInfoLoading,
    required this.pointsContent,
    required this.pointsCount,
    required this.onScrollControllerChanged,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onPointsSectionChanged,
  });

  @override
  State<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<GroupInfoSheet> {
  _GroupSheetSection _section = _GroupSheetSection.overview;

  @override
  void didUpdateWidget(covariant GroupInfoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.group.id != widget.group.id) {
      _section = _GroupSheetSection.overview;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: widget.controller,
        initialChildSize: GroupInfoSheet.minChildSize,
        minChildSize: GroupInfoSheet.minChildSize,
        maxChildSize: GroupInfoSheet.maxChildSize,
        snap: true,
        snapSizes: const [
          GroupInfoSheet.minChildSize,
          GroupInfoSheet.maxChildSize,
        ],
        builder: (context, scrollController) {
          widget.onScrollControllerChanged(scrollController);

          return Material(
            color: AppColors.background,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: widget.onDragUpdate,
                  onVerticalDragEnd: widget.onDragEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 14),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.mutedText,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: widget.memberInfoLoading
                      ? MemberInfoLoading(
                          scrollController: scrollController,
                          bottomContent: widget.pointsContent,
                        )
                      : widget.memberInfo != null
                      ? MemberInfoBottomSheet(
                          memberInfo: widget.memberInfo!,
                          scrollController: scrollController,
                          bottomContent: widget.pointsContent,
                        )
                      : _buildSection(scrollController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(ScrollController scrollController) {
    switch (_section) {
      case _GroupSheetSection.overview:
        return GroupInfoBottomSheet(
          group: widget.group,
          scrollController: scrollController,
          showMembersSection: false,
          bottomContent: _GroupSectionMenu(
            membersCount: widget.group.members.length,
            pointsCount: widget.pointsCount,
            onMembersTap: () {
              setState(() {
                _section = _GroupSheetSection.members;
              });
            },
            onPointsTap: () {
              widget.onPointsSectionChanged?.call(true);
              setState(() {
                _section = _GroupSheetSection.points;
              });
            },
          ),
        );
      case _GroupSheetSection.members:
        return _GroupSectionPage(
          title: 'Miembros',
          icon: Icons.group_rounded,
          count: widget.group.members.length,
          onBack: _showOverview,
          child: GroupMembersBottomSheet(
            group: widget.group,
            scrollController: scrollController,
          ),
        );
      case _GroupSheetSection.points:
        return _GroupSectionPage(
          title: 'Puntos de interés',
          icon: Icons.flag_rounded,
          count: widget.pointsCount,
          onBack: _showOverview,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
            child: widget.pointsContent,
          ),
        );
    }
  }

  void _showOverview() {
    widget.onPointsSectionChanged?.call(false);
    setState(() {
      _section = _GroupSheetSection.overview;
    });
  }
}

class _GroupSectionMenu extends StatelessWidget {
  final int membersCount;
  final int pointsCount;
  final VoidCallback onMembersTap;
  final VoidCallback onPointsTap;

  const _GroupSectionMenu({
    required this.membersCount,
    required this.pointsCount,
    required this.onMembersTap,
    required this.onPointsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.group_rounded, color: AppColors.primary),
          title: Row(
            children: [
              const Text('Miembros'),
              const SizedBox(width: 8),
              _CountBadge(count: membersCount),
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onMembersTap,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_rounded, color: AppColors.primary),
          title: Row(
            children: [
              const Text('Puntos de interés'),
              const SizedBox(width: 8),
              _CountBadge(count: pointsCount),
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onPointsTap,
        ),
      ],
    );
  }
}

class _GroupSectionPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final VoidCallback onBack;
  final Widget child;

  const _GroupSectionPage({
    required this.title,
    required this.icon,
    required this.count,
    required this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 20, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _CountBadge(count: count),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
