import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Background base
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.background,
          const Color(0xFF1A1A1A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Decorative shape 1 - Top Left
    final path1 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.8,
        0,
      )
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      path1,
      paint..color = AppColors.taupeDark.withOpacity(0.08),
    );

    // Decorative shape 2 - Bottom Right
    final path2 = Path()
      ..moveTo(size.width, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.85,
        size.width * 0.1,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path2,
      paint..color = AppColors.taupeBase.withOpacity(0.06),
    );

    // Modern Glassmorphism Orbs
    _drawOrb(canvas, Offset(size.width * 0.85, size.height * 0.15), 140, 
        AppColors.taupeLight.withOpacity(0.04));
    _drawOrb(canvas, Offset(size.width * 0.05, size.height * 0.9), 220, 
        AppColors.primary.withOpacity(0.03));
    _drawOrb(canvas, Offset(size.width * 0.6, size.height * 0.5), 110, 
        AppColors.greyBase.withOpacity(0.02));
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
