import 'package:flutter/material.dart';
import '../../models/detection.dart';

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size previewSize;

  DetectionPainter({
    required this.detections,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width;
    final double scaleY = size.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var det in detections) {
      // Pick color based on urgency
      Color color;
      if (det.urgency >= 4) {
        color = Colors.red;
      } else if (det.urgency >= 3) {
        color = Colors.orange;
      } else if (det.urgency >= 2) {
        color = Colors.yellow;
      } else {
        color = Colors.green;
      }

      paint.color = color;

      final rect = Rect.fromLTRB(
        det.xmin * scaleX,
        det.ymin * scaleY,
        det.xmax * scaleX,
        det.ymax * scaleY,
      );

      canvas.drawRect(rect, paint);

      // Draw label background
      final labelBgPaint = Paint()
        ..color = color.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      final label = "${det.label} ${(det.confidence * 100).toStringAsFixed(0)}%";
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      canvas.drawRect(
        Rect.fromLTWH(
          rect.left,
          rect.top - textPainter.height - 4,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        labelBgPaint,
      );

      textPainter.paint(
        canvas,
        Offset(rect.left + 4, rect.top - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
