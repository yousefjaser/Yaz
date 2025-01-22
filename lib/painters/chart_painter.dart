import 'package:flutter/material.dart';
import 'dart:math' show pi, min;
import 'package:provider/provider.dart';
import 'package:yaz/providers/customers_provider.dart';
import 'package:yaz/services/database_service.dart';

class ChartPainter extends CustomPainter {
  final double totalDue;
  final double totalPaid;

  ChartPainter({required this.totalDue, required this.totalPaid});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.4;

    // رسم الدائرة الخارجية
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25;

    canvas.drawCircle(center, radius, bgPaint);

    final total = totalDue + totalPaid;
    if (total <= 0) return;

    // رسم قطاع الديون
    final duePaint = Paint()
      ..color = Colors.red[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.round;

    final dueAngle = (totalDue / total) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      dueAngle,
      false,
      duePaint,
    );

    // رسم قطاع المدفوعات
    final paidPaint = Paint()
      ..color = Colors.green[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.round;

    final paidAngle = (totalPaid / total) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + dueAngle,
      paidAngle,
      false,
      paidPaint,
    );

    // إضافة النصوص
    final textPainter = TextPainter(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );

    final duePercentage = ((totalDue / total) * 100).toStringAsFixed(1);
    final paidPercentage = ((totalPaid / total) * 100).toStringAsFixed(1);

    textPainter.text = TextSpan(
      text: '$duePercentage%\n$paidPercentage%',
      style: TextStyle(
        color: Colors.grey[800],
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) {
    return oldDelegate.totalDue != totalDue ||
        oldDelegate.totalPaid != totalPaid;
  }
}
