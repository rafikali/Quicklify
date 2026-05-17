import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/flux_theme.dart';

/// Animated rain/matrix-style vertical lines background.
class RainBackground extends StatefulWidget {
  final Widget child;
  final int lineCount;

  const RainBackground({
    super.key,
    required this.child,
    this.lineCount = 60,
  });

  @override
  State<RainBackground> createState() => _RainBackgroundState();
}

class _RainBackgroundState extends State<RainBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_RainLine> _lines;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _lines = List.generate(widget.lineCount, (_) => _generateLine());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  _RainLine _generateLine() {
    return _RainLine(
      x: _random.nextDouble(),
      y: _random.nextDouble() * 2 - 1, // start off-screen top
      length: 20 + _random.nextDouble() * 80,
      speed: 0.15 + _random.nextDouble() * 0.4,
      opacity: 0.03 + _random.nextDouble() * 0.12,
      width: 0.5 + _random.nextDouble() * 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Rain layer
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _RainPainter(
                  lines: _lines,
                  tick: _controller.value,
                ),
              );
            },
          ),
        ),
        // Content on top
        widget.child,
      ],
    );
  }
}

class _RainLine {
  double x;
  double y;
  final double length;
  final double speed;
  final double opacity;
  final double width;

  _RainLine({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
    required this.width,
  });
}

class _RainPainter extends CustomPainter {
  final List<_RainLine> lines;
  final double tick;
  double _lastTick = -1;

  _RainPainter({required this.lines, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final dt = _lastTick < 0 ? 0.016 : ((tick - _lastTick) % 1.0);
    _lastTick = tick;

    for (final line in lines) {
      // Move down
      line.y += line.speed * dt * 3;

      // Reset when off bottom
      if (line.y * size.height > size.height + line.length) {
        line.y = -line.length / size.height;
        line.x = Random().nextDouble();
      }

      final x = line.x * size.width;
      final yStart = line.y * size.height;
      final yEnd = yStart + line.length;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FluxColors.cyan.withValues(alpha: 0),
            FluxColors.cyan.withValues(alpha: line.opacity),
            FluxColors.cyan.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(x, yStart, x + 1, yEnd))
        ..strokeWidth = line.width
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), paint);
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => true;
}
