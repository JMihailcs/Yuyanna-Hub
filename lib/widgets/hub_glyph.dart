import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class HubGlyph extends StatelessWidget {
  const HubGlyph({
    super.key,
    this.size = 96,
    this.lineColor = AppColors.red,
    this.monochrome = false,
  });

  final double size;
  final Color lineColor;
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    // Center evita que un padre con constraints "stretch" estire el glyph
    // a todo el ancho (lo mantiene cuadrado de tamaño [size]).
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _HubGlyphPainter(
            lineColor: lineColor,
            monochrome: monochrome,
          ),
        ),
      ),
    );
  }
}

class _HubGlyphPainter extends CustomPainter {
  _HubGlyphPainter({required this.lineColor, required this.monochrome});

  final Color lineColor;
  final bool monochrome;

  @override
  void paint(Canvas canvas, Size size) {
    // Usar la dimensión menor evita que el glyph se deforme/desborde si la
    // caja no es cuadrada.
    final double d = math.min(size.width, size.height);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = d * 0.34;
    final double stroke = d * 0.045;
    final double centerNode = d * 0.12;
    final double outerNode = d * 0.085;

    const List<double> angles = <double>[
      -math.pi / 2,
      math.pi / 6,
      5 * math.pi / 6,
    ];

    final List<Color> nodeColors = monochrome
        ? <Color>[lineColor, lineColor, lineColor]
        : <Color>[AppColors.redFill, AppColors.blueFill, AppColors.goldFill];

    final Paint linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final List<Offset> nodes = angles
        .map<Offset>(
          (double a) => center +
              Offset(math.cos(a) * radius, math.sin(a) * radius),
        )
        .toList();

    for (final Offset node in nodes) {
      canvas.drawLine(center, node, linePaint);
    }

    for (int i = 0; i < nodes.length; i++) {
      canvas.drawCircle(
        nodes[i],
        outerNode,
        Paint()..color = nodeColors[i],
      );
    }

    canvas.drawCircle(
      center,
      centerNode,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HubGlyphPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.monochrome != monochrome;
  }
}
