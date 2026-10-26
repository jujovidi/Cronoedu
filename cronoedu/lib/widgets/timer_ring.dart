import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Anillo del temporizador. [dashed] dibuja el anillo punteado del estado
/// "en pausa"; [gradient] el degradado morado→azul del enfoque.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
    this.gradient,
    this.dashed = false,
    this.size = 240,
  });

  final double progress;
  final Color color;
  final List<Color>? gradient;
  final bool dashed;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: color,
          gradient: gradient,
          dashed: dashed,
          track: color.withValues(alpha: .15),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track, this.gradient, this.dashed = false});

  final double progress;
  final Color color;
  final Color track;
  final List<Color>? gradient;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (dashed) {
      paint
        ..color = color
        ..strokeCap = StrokeCap.butt;
      const dashes = 28;
      const sweep = 2 * math.pi / dashes;
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(arcRect, i * sweep, sweep * .55, false, paint);
      }
      return;
    }

    paint.color = track;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, paint);

    if (progress <= 0) return;
    if (gradient != null) {
      paint.shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: gradient!,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    } else {
      paint.color = color;
    }
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.dashed != dashed;
}
