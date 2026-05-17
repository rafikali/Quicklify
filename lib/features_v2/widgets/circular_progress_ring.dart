import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/flux_theme.dart';

/// Large circular progress ring with percentage and speed display.
class CircularProgressRing extends StatelessWidget {
  final int progress;
  final String speedText;
  final double size;

  const CircularProgressRing({
    super.key,
    required this.progress,
    this.speedText = '',
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CustomPaint(
            size: Size(size, size),
            painter: _RingBgPainter(),
          ),
          // Progress arc
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressArcPainter(progress: progress / 100),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$progress%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: FluxColors.textPrimary,
                  height: 1,
                ),
              ),
              if (speedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    speedText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: FluxColors.cyan,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final paint = Paint()
      ..color = FluxColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressArcPainter extends CustomPainter {
  final double progress;

  _ProgressArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * pi * progress;

    // Gradient arc
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: const [FluxColors.cyan, FluxColors.progressEnd],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);

    canvas.drawArc(rect, -pi / 2, sweepAngle, false, paint);

    // Glow dot at tip
    final tipAngle = -pi / 2 + sweepAngle;
    final tipX = center.dx + radius * cos(tipAngle);
    final tipY = center.dy + radius * sin(tipAngle);
    final glowPaint = Paint()
      ..color = FluxColors.progressEnd.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(tipX, tipY), 5, glowPaint);
    canvas.drawCircle(
      Offset(tipX, tipY),
      3,
      Paint()..color = FluxColors.progressEnd,
    );
  }

  @override
  bool shouldRepaint(_ProgressArcPainter old) => old.progress != progress;
}
