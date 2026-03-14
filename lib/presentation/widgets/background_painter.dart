import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Background base - using solid background as requested "no gradient" for structure
    // but a very subtle deep variation for the painter itself to feel "elegant"
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), 
        Paint()..color = AppColors.background);

    // Decorative shape 1 - Soft Top Left Organic Shape
    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.15,
        size.width * 0.6,
        0,
      )
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      path1,
      paint..color = AppColors.taupeDark.withOpacity(0.04),
    );

    // Decorative shape 2 - Soft Bottom Right Organic Shape
    final path2 = Path()
      ..moveTo(size.width, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.8,
        size.width * 0.3,
        size.height,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path2,
      paint..color = AppColors.primary.withOpacity(0.03),
    );

    // Elegant thin line accents
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset(size.width, 0), size.width * 0.4, linePaint);
    canvas.drawCircle(Offset(0, size.height), size.width * 0.6, linePaint);
    
    // Modern Soft Orbs for depth
    _drawOrb(canvas, Offset(size.width * 0.8, size.height * 0.2), 120, 
        AppColors.taupeLight.withOpacity(0.03));
    _drawOrb(canvas, Offset(size.width * 0.1, size.height * 0.8), 180, 
        AppColors.primary.withOpacity(0.02));
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
