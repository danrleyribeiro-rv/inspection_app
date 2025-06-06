// lib/presentation/widgets/progress_circle.dart
import 'package:flutter/material.dart';

class ProgressCircle extends StatelessWidget {
  final double progress;
  final double size;
  final bool showPercentage;
  final Color? backgroundColor;
  final Color? progressColor;

  const ProgressCircle({
    super.key,
    required this.progress,
    this.size = 32,
    this.showPercentage = true,
    this.backgroundColor,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    Color getProgressColor() {
      if (progressColor != null) return progressColor!;
      
      if (progress < 30) {
        return Colors.red;
      } else if (progress < 70) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: progress / 100,
            backgroundColor: backgroundColor ?? Colors.grey[600],
            valueColor: AlwaysStoppedAnimation<Color>(getProgressColor()),
            strokeWidth: size * 0.09, // Proportional stroke width
          ),
          if (showPercentage)
            Center(
              child: Text(
                '${progress.toInt()}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.31, // Proportional font size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}