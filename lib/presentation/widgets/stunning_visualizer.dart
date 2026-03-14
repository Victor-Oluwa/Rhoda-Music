  import 'dart:math' as math;
  import 'dart:ui';
  import 'package:flutter/material.dart';
  import 'package:flutter_screenutil/flutter_screenutil.dart';

  class StunningVisualizer extends StatefulWidget {
    final bool isPlaying;
    final Color color;

    const StunningVisualizer({
      super.key,
      required this.isPlaying,
      required this.color,
    });

    @override
    State<StunningVisualizer> createState() => _StunningVisualizerState();
  }

  class _StunningVisualizerState extends State<StunningVisualizer> with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    final math.Random _random = math.Random();
  final List<_QuantumParticle> _particles = List.generate(40, (i) => _QuantumParticle(math.Random()));

  double _energyLevel = 0.0;
  double _totalRotation = 0.0; // Continuous rotation to prevent skipping

    @override
    void initState() {
      super.initState();
    // Shorter duration for high-frequency updates
      _controller = AnimationController(
        vsync: this,
      duration: const Duration(seconds: 1),
      )..addListener(_onTick);
    _controller.repeat();
    }

    void _onTick() {
      if (!mounted) return;
      setState(() {
      final double speed = widget.isPlaying ? 1.0 : 0.2;

      // PRODUCTION FIX: Increased increment to 0.03 to restore the "mind-blowing" speed
      // while maintaining the skip-free continuous rotation logic.
      _totalRotation += 0.03 * speed;

      // Simulate dynamic audio energy
      final double targetEnergy = widget.isPlaying ? 0.4 + _random.nextDouble() * 0.6 : 0.05;
      _energyLevel = _energyLevel + (targetEnergy - _energyLevel) * 0.1;

      for (var p in _particles) {
        p.update(_energyLevel, widget.isPlaying);
        }
      });
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
    return Container(
      height: 280.h,
        width: double.infinity,
        child: CustomPaint(
        painter: _QuantumSingularityPainter(
          particles: _particles,
          energy: _energyLevel,
          themeColor: widget.color,
          rotation: _totalRotation,
            isPlaying: widget.isPlaying,
          ),
        ),
      );
    }
  }

  class _QuantumParticle {
  double angle;
  double radius;
  double speed;
    double size;
  double opacity;
  double jitter;

  _QuantumParticle(math.Random random)
      : angle = random.nextDouble() * 2 * math.pi,
        radius = 40.0 + random.nextDouble() * 100.0,
        speed = 0.01 + random.nextDouble() * 0.03,
        size = 1.0 + random.nextDouble() * 3.0,
        opacity = 0.1 + random.nextDouble() * 0.5,
        jitter = 0.0;

  void update(double energy, bool isPlaying) {
    angle += speed * (1.0 + energy * 2);
    jitter = math.sin(angle * 5) * (energy * 15);
    if (isPlaying) {
      opacity = (0.2 + energy * 0.8).clamp(0.0, 1.0);
    } else {
      opacity = (opacity * 0.95).clamp(0.05, 1.0);
    }
    }
  }

  class _QuantumSingularityPainter extends CustomPainter {
  final List<_QuantumParticle> particles;
  final double energy;
  final Color themeColor;
  final double rotation;
    final bool isPlaying;

  _QuantumSingularityPainter({
    required this.particles,
    required this.energy,
    required this.themeColor,
    required this.rotation,
      required this.isPlaying,
    });

    @override
    void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw Chromatic Background Aura
    for (int i = 0; i < 2; i++) {
      final double auraRadius = (100.r + (i * 20.r)) * (1.0 + energy * 0.2);
      final auraPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            (i == 0 ? themeColor : Colors.white).withOpacity((0.2 - i * 0.1).clamp(0.0, 1.0)),
            themeColor.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: auraRadius));
      canvas.drawCircle(center, auraRadius, auraPaint);
      }

    // 2. Draw Harmonic Resonance Paths (Seamlessly Rotating at original fast speed)
    _drawHarmonicPath(canvas, center, 3, 0.8, rotation * 1.5, Colors.white.withOpacity(0.8));
    _drawHarmonicPath(canvas, center, 5, 1.2, -rotation, themeColor.withOpacity(0.4));
    _drawHarmonicPath(canvas, center, 2, 1.5, rotation * 2.0, themeColor.withOpacity(0.2));

    // 3. Draw Quantum Particles
    for (var p in particles) {
      final double x = center.dx + math.cos(p.angle) * (p.radius + p.jitter);
      final double y = center.dy + math.sin(p.angle) * (p.radius + p.jitter);

      final particlePaint = Paint()
        ..color = Color.lerp(themeColor, Colors.white, energy)!
            .withOpacity(p.opacity.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, energy * 4 + 1);

      canvas.drawCircle(Offset(x, y), p.size * (1.0 + energy), particlePaint);

      if (energy > 0.7) {
        canvas.drawLine(
          center,
          Offset(x, y),
          Paint()
            ..color = themeColor.withOpacity((energy - 0.7).clamp(0.0, 0.2))
            ..strokeWidth = 0.5
        );
      }
    }

    // 4. Draw The Core Singularity
    final coreGlowPaint = Paint()
      ..color = Colors.white.withOpacity((0.8 * (1.0 + energy * 0.2)).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, 15.r * (1.0 + energy * 0.5), coreGlowPaint);

    canvas.drawCircle(center, 8.r, Paint()..color = Colors.white);
    canvas.drawCircle(center, 4.r, Paint()..color = themeColor);
  }

  void _drawHarmonicPath(Canvas canvas, Offset center, int lobes, double scale, double currentRotation, Color color) {
    final path = Path();
    final double baseRadius = 60.r * scale;

    for (double i = 0; i <= 2 * math.pi; i += 0.05) {
      final double r = baseRadius + (20.r * energy * math.sin(i * lobes + currentRotation));
      final double x = center.dx + math.cos(i) * r;
      final double y = center.dy + math.sin(i) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        }
      }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + energy * 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, energy * 5)
    );
    }

    @override
  bool shouldRepaint(covariant _QuantumSingularityPainter oldDelegate) => true;
  }
