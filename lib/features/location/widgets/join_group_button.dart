import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';

class JoinGroupButton extends StatelessWidget {
  const JoinGroupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ingresar a un grupo',

      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),

        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pushNamed(AppRoutes.joinGroup);
          },

          child: const SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(painter: _PlusPainter()),
          ),
        ),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onPrimary
      ..style = PaintingStyle.fill;

    final thickness = size.width * 0.16;
    final length = size.width * 0.56;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = Radius.circular(thickness / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: length, height: thickness),
        radius,
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: thickness, height: length),
        radius,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlusPainter oldDelegate) => false;
}
