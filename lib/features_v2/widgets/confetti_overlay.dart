import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/flux_theme.dart';

/// Confetti particle overlay for the completion screen.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  static const _colors = [
    FluxColors.cyan,
    FluxColors.success,
    Color(0xFF00B8D4),
    Color(0xFF00E676),
    Color(0xFF40C4FF),
    Color(0xFF69F0AE),
  ];

  @override
  void initState() {
    super.initState();
    _particles = List.generate(80, (_) => _makeParticle());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  _Particle _makeParticle() {
    return _Particle(
      x: _random.nextDouble(),
      y: -_random.nextDouble() * 0.5,
      vx: (_random.nextDouble() - 0.5) * 0.3,
      vy: 0.2 + _random.nextDouble() * 0.5,
      size: 3 + _random.nextDouble() * 5,
      rotation: _random.nextDouble() * pi * 2,
      rotSpeed: (_random.nextDouble() - 0.5) * 4,
      color: _colors[_random.nextInt(_colors.length)],
      opacity: 0.5 + _random.nextDouble() * 0.5,
      shape: _random.nextInt(3), // 0=square, 1=circle, 2=line
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              particles: _particles,
              tick: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  double x, y, vx, vy, size, rotation, rotSpeed, opacity;
  final Color color;
  final int shape;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotSpeed,
    required this.color,
    required this.opacity,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double tick;
  double _lastTick = -1;

  _ConfettiPainter({required this.particles, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final dt = _lastTick < 0 ? 0.016 : ((tick - _lastTick) % 1.0);
    _lastTick = tick;

    for (final p in particles) {
      p.x += p.vx * dt * 2;
      p.y += p.vy * dt * 2;
      p.rotation += p.rotSpeed * dt * 2;
      p.vy += dt * 0.3; // gravity
      p.opacity = (p.opacity - dt * 0.1).clamp(0.0, 1.0);

      // Reset when off screen
      if (p.y > 1.2 || p.opacity <= 0) {
        p.x = Random().nextDouble();
        p.y = -0.05;
        p.vy = 0.2 + Random().nextDouble() * 0.5;
        p.vx = (Random().nextDouble() - 0.5) * 0.3;
        p.opacity = 0.5 + Random().nextDouble() * 0.5;
      }

      final px = p.x * size.width;
      final py = p.y * size.height;
      final paint = Paint()..color = p.color.withValues(alpha: p.opacity);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case 0: // square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
          break;
        case 1: // circle
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case 2: // line
          canvas.drawLine(
            Offset(-p.size, 0),
            Offset(p.size, 0),
            paint..strokeWidth = 2,
          );
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
