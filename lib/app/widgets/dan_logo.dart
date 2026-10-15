import 'package:flutter/material.dart';

/// Theme-aware vector rendering of the Dan sunrise mark.
class DanLogo extends StatelessWidget {
  /// Creates a Dan logo.
  const DanLogo({
    required this.color,
    required this.semanticLabel,
    this.size = 96,
    super.key,
  });

  /// Foreground color of the mark.
  final Color color;

  /// Accessible name announced for the mark.
  final String semanticLabel;

  /// Width and height of the square drawing area.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: CustomPaint(
        size: Size.square(size),
        painter: _DanLogoPainter(color),
      ),
    );
  }
}

class _DanLogoPainter extends CustomPainter {
  const _DanLogoPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side * 0.322;
    final strokeWidth = side * 0.024;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas
      ..drawCircle(center, radius, paint)
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      )
      ..drawLine(
        Offset(0, side * 0.62),
        Offset(size.width, side * 0.62),
        paint,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_DanLogoPainter oldDelegate) => oldDelegate.color != color;
}
