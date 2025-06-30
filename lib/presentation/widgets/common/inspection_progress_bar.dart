// lib/presentation/widgets/inspection_progress_bar.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/utils/progress_calculation_service.dart';

class InspectionProgressBar extends StatelessWidget {
  final double progress;
  final Map<String, int>? stats;

  const InspectionProgressBar({
    super.key,
    required this.progress,
    this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = ProgressCalculationService.getProgressColor(progress);
    final progressLabel = ProgressCalculationService.getProgressLabel(progress);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Progresso: ${ProgressCalculationService.getFormattedProgress(progress)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: progressColor.withAlpha((255 * 0.2).round()),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: progressColor),
                ),
                child: Text(
                  progressLabel,
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (stats != null) ...[
                Text(
                  '${stats!['filledDetails']}/${stats!['totalDetails']} detalhes',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${stats!['totalMedia']} mídias',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}
