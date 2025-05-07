// lib/presentation/widgets/inspection_checkpoint_bar.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InspectionCheckpointBar extends StatelessWidget {
  static const double HEIGHT = 72.0; // Aumentado para acomodar mais informações
  final DateTime? lastCheckpointAt;
  final String? lastCheckpointMessage;
  final double? lastCheckpointCompletion;
  final VoidCallback onAddCheckpoint;
  final VoidCallback onViewHistory;
  
  // Novos campos para exibir progresso detalhado
  final int? completedItems;
  final int? totalItems;
  final int? itemsWithMedia;
  final int? totalItemsForMedia;
  final double? detailsScore;
  final double? mediaScore;

  const InspectionCheckpointBar({
    super.key,
    this.lastCheckpointAt,
    this.lastCheckpointMessage,
    this.lastCheckpointCompletion,
    required this.onAddCheckpoint,
    required this.onViewHistory,
    this.completedItems,
    this.totalItems,
    this.itemsWithMedia,
    this.totalItemsForMedia,
    this.detailsScore,
    this.mediaScore,
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
  
  /// Retorna uma classificação do progresso baseada na porcentagem
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
    // Calcular o progresso atual - pode ser o último checkpoint ou o valor atual
    final currentCompletion = (completedItems != null && totalItems != null && totalItems! > 0)
        ? ((completedItems! / totalItems!) * 100)
        : (lastCheckpointCompletion ?? 0.0);
        
    // Calcular progresso de mídia
    final mediaProgress = (itemsWithMedia != null && totalItemsForMedia != null && totalItemsForMedia! > 0)
        ? ((itemsWithMedia! / totalItemsForMedia!) * 100)
        : 0.0;

    // Exibir progresso de mídia no console (ou use conforme necessário)
    debugPrint('Media Progress: $mediaProgress');
    
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
                              ? Colors.blue.shade800.withOpacity(0.9)
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
                            if (hasLastCheckpoint && lastCheckpointMessage != null && lastCheckpointMessage!.isNotEmpty)
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  color: _getProgressColor(currentCompletion).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getProgressColor(currentCompletion)),
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
              if (completedItems != null && totalItems != null)
                Text(
                  '$completedItems/$totalItems detalhes',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 11,
                  ),
                ),
                
              const SizedBox(width: 8),
              
              // Progresso de mídia
              if (itemsWithMedia != null && totalItemsForMedia != null)
                Text(
                  '$itemsWithMedia/$totalItemsForMedia com mídia',
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
                if (detailsScore != null)
                  Flexible(
                    flex: (detailsScore! * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                
                // Progresso de mídia
                if (mediaScore != null)
                  Flexible(
                    flex: (mediaScore! * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                
                // Espaço restante
                Flexible(
                  flex: 100 - (detailsScore != null ? (detailsScore! * 100).round() : 0) 
                          - (mediaScore != null ? (mediaScore! * 100).round() : 0),
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