import 'dart:math' as math;
import 'package:flutter/cupertino.dart';

class HmiRadialGauge extends StatelessWidget {
  final String title;
  final int value;
  final int minVal;
  final int maxVal;
  final Color accentColor;
  final VoidCallback? onConfigure;
  final ValueChanged<int>? onWriteValue;

  const HmiRadialGauge({
    super.key,
    required this.title,
    required this.value,
    this.minVal = 0,
    this.maxVal = 1000,
    this.accentColor = CupertinoColors.systemTeal,
    this.onConfigure,
    this.onWriteValue,
  });

  @override
  Widget build(BuildContext context) {
    // Prevent division by zero
    final range = (maxVal - minVal) <= 0 ? 1000 : (maxVal - minVal);
    final clampedValue = value.clamp(minVal, maxVal);
    final percentage = (clampedValue - minVal) / range;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF23232C)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha:0.03),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.systemGrey2,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onConfigure != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                  onPressed: onConfigure,
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
                    color: CupertinoColors.systemGrey2.withValues(alpha:0.8),
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Custom Painter Gauge
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (onWriteValue != null) {
                  _showWriteDialog(context);
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: _GaugePainter(
                      percentage: percentage,
                      accentColor: accentColor,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                          fontFamily: 'SF Mono',
                        ),
                      ),
                      Text(
                        'min: $minVal / max: $maxVal',
                        style: TextStyle(
                          fontSize: 9,
                          color: CupertinoColors.systemGrey.withValues(alpha:0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWriteDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toString());
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text('Write to register'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: CupertinoTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              placeholder: 'Enter register value',
              style: const TextStyle(color: CupertinoColors.white),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Write'),
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null) {
                  onWriteValue?.call(val);
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final Color accentColor;

  _GaugePainter({required this.percentage, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // Standard starting and sweeping angles (radial gauge arc)
    const startAngle = 3 * math.pi / 4;
    const sweepAngle = 3 * math.pi / 2;

    // Draw background track
    final trackPaint = Paint()
      ..color = const Color(0xFF1E1E24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Draw active progress
    final activePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * percentage,
      false,
      activePaint,
    );

    // Draw needle
    final needleAngle = startAngle + sweepAngle * percentage;
    final needleEnd = Offset(
      center.dx + (radius - 12) * math.cos(needleAngle),
      center.dy + (radius - 12) * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = CupertinoColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw center pin
    final centerPinPaint = Paint()..color = accentColor;
    canvas.drawCircle(center, 5, centerPinPaint);
    final centerPinOuter = Paint()
      ..color = CupertinoColors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 5, centerPinOuter);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.accentColor != accentColor;
  }
}
