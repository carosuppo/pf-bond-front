import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/get_member_info_model.response.dart';

class MemberInfoBottomSheet extends StatelessWidget {
  final GetMemberInfoResponseModel memberInfo;
  final ScrollController scrollController;
  final Widget? bottomContent;

  const MemberInfoBottomSheet({
    super.key,
    required this.memberInfo,
    required this.scrollController,
    this.bottomContent,
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
            if (bottomContent != null) ...[
              const SizedBox(height: 24),
              bottomContent!,
            ],
          ],
        ),
      ),
    );
  }
}

class MemberInfoLoading extends StatelessWidget {
  final ScrollController scrollController;
  final Widget? bottomContent;

  const MemberInfoLoading({
    super.key,
    required this.scrollController,
    this.bottomContent,
  });

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
            if (bottomContent != null) ...[
              const SizedBox(height: 24),
              bottomContent!,
            ],
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
