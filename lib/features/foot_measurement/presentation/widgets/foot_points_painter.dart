import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart'; // Alias ajouté

class FootOverlayPainter extends CustomPainter {
  final Rect box;
  final ui.Size screenSize;

  FootOverlayPainter({
    required this.box,
    required this.screenSize,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()
      ..color = const ui.Color(0xFF00FF00)
      ..strokeWidth = 3
      ..style = ui.PaintingStyle.stroke;

    // Conversion des coordonnées relatives
    final scaledBox = Rect.fromLTWH(
      box.left * screenSize.width,
      box.top * screenSize.height,
      box.width * screenSize.width,
      box.height * screenSize.height,
    );

    canvas.drawRect(scaledBox, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}