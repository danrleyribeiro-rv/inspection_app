import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InspectionCheckpointBar extends StatelessWidget {
  static const double height = 72.0;
  final DateTime? lastCheckpointAt;
  final String? lastCheckpointMessage;
  final double? lastCheckpointCompletion;
  final VoidCallback onAddCheckpoint;
  final VoidCallback onViewHistory;

  // Novos campos para exibir progresso detalhado
  final int? completedDetails;
  final int? totalDetails;
  final int? totalMedia;
  final double? overallCompletion;

  const InspectionCheckpointBar({
    super.key,
    this.lastCheckpointAt,
    this.lastCheckpointMessage,
    this.lastCheckpointCompletion,
    required this.onAddCheckpoint,
    required this.onViewHistory,
    this.completedDetails,
    this.totalDetails,
    this.totalMedia,
    this.overallCompletion,
  });

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Color _getProgressColor(double percentage) {
    if (percentage < 30) {
      return Colors.red;
    } else if (percentage < 70) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getProgressLabel(double percentage) {
    if (percentage < 5) return 'Início';
    if (percentage < 20) return 'Fase inicial';
    if (percentage < 40) return 'Em andamento';
    if (percentage < 60) return 'Avançando';
    if (percentage < 80) return 'Fase final';
    if (percentage < 95) return 'Quase concluído';
    return 'Concluído';
  }

  @override
  Widget build(BuildContext context) {
    bool hasLastCheckpoint = lastCheckpointAt != null;
    final currentCompletion =
        overallCompletion ?? lastCheckpointCompletion ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Informação do último checkpoint
              Expanded(
                child: GestureDetector(
                  onTap: hasLastCheckpoint ? onViewHistory : null,
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: hasLastCheckpoint
                              ? Colors.blue.shade800.withAlpha((255 * 0.9).round())
                              : Colors.grey.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasLastCheckpoint ? Icons.history : Icons.flag,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasLastCheckpoint
                                  ? 'Checkpoint: ${_formatDate(lastCheckpointAt!)}'
                                  : 'Nenhum checkpoint registrado',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasLastCheckpoint &&
                                lastCheckpointMessage != null &&
                                lastCheckpointMessage!.isNotEmpty)
                              Text(
                                lastCheckpointMessage!,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Botões de ação
              Row(
                children: [
                  // Botão de ver histórico
                  if (hasLastCheckpoint)
                    IconButton(
                      onPressed: onViewHistory,
                      icon: const Icon(Icons.history, color: Colors.white),
                      tooltip: 'Ver histórico',
                    ),

                  // Botão de adicionar checkpoint
                  ElevatedButton.icon(
                    onPressed: onAddCheckpoint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Checkpoint'),
                  ),
                ],
              ),
            ],
          ),

          // Barra de progresso detalhada
          const SizedBox(height: 4),
          Row(
            children: [
              // Indicador de status de progresso
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getProgressColor(currentCompletion).withAlpha((255 * 0.2).round()),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: _getProgressColor(currentCompletion)),
                ),
                child: Text(
                  _getProgressLabel(currentCompletion),
                  style: TextStyle(
                    color: _getProgressColor(currentCompletion),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Detalhes numéricos do progresso
              if (completedDetails != null && totalDetails != null)
                Text(
                  '$completedDetails/$totalDetails detalhes',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 11,
                  ),
                ),

              const SizedBox(width: 8),

              // Total de mídias
              if (totalMedia != null)
                Text(
                  '$totalMedia mídias',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 11,
                  ),
                ),

              const Spacer(),

              // Porcentagem de conclusão
              Text(
                '${currentCompletion.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _getProgressColor(currentCompletion),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Barra de progresso
          const SizedBox(height: 4),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                // Progresso de detalhes
                Flexible(
                  flex: currentCompletion.round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getProgressColor(currentCompletion),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Espaço restante
                Flexible(
                  flex: (100 - currentCompletion).round(),
                  child: Container(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
