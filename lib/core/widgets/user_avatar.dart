import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 22,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim();

    final diameter = radius * 2;
    final avatar = photo == null || photo.isEmpty
        ? _InitialAvatar(name: name, radius: radius)
        : ClipOval(
            child: Image.network(
              photo,
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _InitialAvatar(name: name, radius: radius),
            ),
          );

    if (borderColor == null || borderWidth <= 0) {
      return avatar;
    }

    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: borderWidth),
      ),
      child: avatar,
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const _InitialAvatar({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}
