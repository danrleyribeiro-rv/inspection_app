// lib/presentation/widgets/common/progress_circle.dart
import 'package:flutter/material.dart';

class ProgressCircle extends StatelessWidget {
  final double progress;
  final double size;
  final bool showPercentage;
  final Color? color;

  const ProgressCircle({
    super.key,
    required this.progress,
    this.size = 40,
    this.showPercentage = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Theme.of(context).primaryColor;
    final percentage = (progress * 100).round();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: displayColor.withAlpha((255 * 0.2).round()),
            valueColor: AlwaysStoppedAnimation<Color>(displayColor),
            strokeWidth: size / 10,
          ),
          if (showPercentage)
            Center(
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: size / 4,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}