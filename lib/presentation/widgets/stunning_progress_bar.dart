import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';

class StunningProgressBar extends StatefulWidget {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;

  const StunningProgressBar({
    super.key,
    required this.position,
    required this.bufferedPosition,
    required this.duration,
    this.onSeek,
  });

  @override
  State<StunningProgressBar> createState() => _StunningProgressBarState();
}

class _StunningProgressBarState extends State<StunningProgressBar> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<_FireParticle> _particles = [];
  final math.Random _random = math.Random();
  double _lastProgress = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    setState(() {
      // Update existing particles
      _particles.removeWhere((p) => p.life <= 0);
      for (var p in _particles) {
        p.update();
      }

      // Generate new particles at the thumb position
      final double totalMs = widget.duration.inMilliseconds.toDouble();
      final double progress = totalMs > 0 ? widget.position.inMilliseconds / totalMs : 0.0;
      
      // Add "fire" particles
      if (widget.duration > Duration.zero) {
        for (int i = 0; i < 3; i++) {
          _particles.add(_FireParticle(
            progress: progress,
            random: _random,
            color: AppColors.primary,
          ));
        }
      }
      _lastProgress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double totalMs = widget.duration.inMilliseconds.toDouble();
    final double currentMs = widget.position.inMilliseconds.toDouble().clamp(0, totalMs);
    final double bufferedMs = widget.bufferedPosition.inMilliseconds.toDouble().clamp(0, totalMs);

    final double progress = totalMs > 0 ? currentMs / totalMs : 0.0;
    final double bufferedProgress = totalMs > 0 ? bufferedMs / totalMs : 0.0;

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (details) => _handleSeek(context, details.localPosition.dx),
          onTapDown: (details) => _handleSeek(context, details.localPosition.dx),
          child: Container(
            height: 60.h, // Increased height for fire effect
            width: double.infinity,
            color: Colors.transparent,
            child: CustomPaint(
              painter: _FireProgressBarPainter(
                progress: progress,
                bufferedProgress: bufferedProgress,
                particles: _particles,
                activeColor: AppColors.primary,
                bufferedColor: Colors.white.withOpacity(0.15),
                inactiveColor: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.position),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _formatDuration(widget.duration),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleSeek(BuildContext context, double dx) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double width = box.size.width;
    final double percentage = (dx / width).clamp(0.0, 1.0);
    final Duration seekTo = Duration(milliseconds: (widget.duration.inMilliseconds * percentage).toInt());
    widget.onSeek?.call(seekTo);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}

class _FireParticle {
  double xOffset;
  double yOffset;
  double vx;
  double vy;
  double life;
  double maxLife;
  double size;
  final double progress;
  final Color color;

  _FireParticle({required this.progress, required math.Random random, required this.color})
      : xOffset = (random.nextDouble() - 0.5) * 10,
        yOffset = 0,
        vx = (random.nextDouble() - 0.5) * 1.5,
        vy = -random.nextDouble() * 3.0 - 1.0,
        maxLife = random.nextDouble() * 0.5 + 0.5,
        life = 1.0,
        size = random.nextDouble() * 15 + 5;

  void update() {
    xOffset += vx;
    yOffset += vy;
    life -= 0.02; // Fading speed
  }
}

class _FireProgressBarPainter extends CustomPainter {
  final double progress;
  final double bufferedProgress;
  final List<_FireParticle> particles;
  final Color activeColor;
  final Color bufferedColor;
  final Color inactiveColor;

  _FireProgressBarPainter({
    required this.progress,
    required this.bufferedProgress,
    required this.particles,
    required this.activeColor,
    required this.bufferedColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double trackHeight = 3.h;
    final double centerY = size.height * 0.7; // Lower track to give room for fire
    final double width = size.width;

    // --- 1. Draw Inactive/Buffered Track ---
    final Paint trackPaint = Paint()
      ..color = inactiveColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = trackHeight;

    canvas.drawLine(Offset(0, centerY), Offset(width, centerY), trackPaint);

    if (bufferedProgress > 0) {
      canvas.drawLine(
        Offset(0, centerY),
        Offset(width * bufferedProgress, centerY),
        Paint()
          ..color = bufferedColor
          ..strokeCap = StrokeCap.round
          ..strokeWidth = trackHeight,
      );
    }

    // --- 2. Draw Fire Effect ---
    for (var p in particles) {
      final double px = (width * p.progress) + p.xOffset;
      final double py = centerY + p.yOffset;
      
      // Fire gradient color based on life
      final Color particleColor = Color.lerp(
        Colors.white, 
        activeColor, 
        1.0 - p.life
      )!.withOpacity(p.life.clamp(0, 1));

      final Paint particlePaint = Paint()
        ..color = particleColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size / 2);

      canvas.drawCircle(Offset(px, py), p.size * p.life, particlePaint);
    }

    // --- 3. Draw Active Track (Glowing Plasma) ---
    if (progress > 0) {
      final Paint activePaint = Paint()
        ..color = activeColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = trackHeight;

      // Inner glow for the line
      canvas.drawLine(
        Offset(0, centerY),
        Offset(width * progress, centerY),
        Paint()
          ..color = activeColor.withOpacity(0.5)
          ..strokeWidth = trackHeight + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..strokeCap = StrokeCap.round,
      );

      canvas.drawLine(Offset(0, centerY), Offset(width * progress, centerY), activePaint);
    }

    // --- 4. Draw Thumb (The "Core") ---
    final double thumbX = width * progress;
    
    // Core Glow
    canvas.drawCircle(
      Offset(thumbX, centerY),
      12.r,
      Paint()
        ..color = activeColor.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // White center
    canvas.drawCircle(
      Offset(thumbX, centerY),
      6.r,
      Paint()..color = Colors.white,
    );

    // Primary ring
    canvas.drawCircle(
      Offset(thumbX, centerY),
      4.r,
      Paint()..color = activeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _FireProgressBarPainter oldDelegate) => true;
}
