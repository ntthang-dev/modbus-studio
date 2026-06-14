import 'package:flutter/cupertino.dart';

class HmiTankLevel extends StatelessWidget {
  final String title;
  final int value;
  final int minVal;
  final int maxVal;
  final Color accentColor;
  final VoidCallback? onConfigure;
  final ValueChanged<int>? onWriteValue;

  const HmiTankLevel({
    super.key,
    required this.title,
    required this.value,
    this.minVal = 0,
    this.maxVal = 1000,
    this.accentColor = CupertinoColors.systemBlue,
    this.onConfigure,
    this.onWriteValue,
  });

  @override
  Widget build(BuildContext context) {
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
          // Tank representation
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
                  // Outer tank body
                  Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2C2C35), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Fluid level filling from bottom
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 150 * percentage, // Assume height bounding
                            // In real layout, LayoutBuilder is better:
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha:0.6),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Centered reading label
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                          fontFamily: 'SF Mono',
                        ),
                      ),
                      Text(
                        '${(percentage * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.systemGrey.withValues(alpha:0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'min: $minVal / max: $maxVal',
            style: TextStyle(
              fontSize: 10,
              color: CupertinoColors.systemGrey.withValues(alpha:0.5),
            ),
            textAlign: TextAlign.center,
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
