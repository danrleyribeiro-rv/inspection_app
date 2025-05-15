// lib/presentation/widgets/checkpoint_restore_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';

class CheckpointRestoreDialog extends StatelessWidget {
  final InspectionCheckpoint checkpoint;
  final VoidCallback onConfirm;

  const CheckpointRestoreDialog({
    super.key,
    required this.checkpoint,
    required this.onConfirm,
  });

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

Widget _buildDialogContent(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(0),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.restore, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Restaurar Inspeção',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Conteúdo com scroll
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tem certeza que deseja restaurar esta inspeção para o estado deste checkpoint?',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Detalhes do checkpoint
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Data e criador
                        Row(
                          children: [
                            const Icon(Icons.history, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Checkpoint: ${_formatDate(checkpoint.createdAt)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        
                        // Mensagem
                        if (checkpoint.message != null && checkpoint.message!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Mensagem:',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              checkpoint.message!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                        
                        // Informações do snapshot
                        const SizedBox(height: 12),
                        if (checkpoint.data != null) ...[
                          _buildSnapshotInfo(checkpoint.data!),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Aviso
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade800),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Esta ação substituirá o estado atual da inspeção pelo estado salvo neste checkpoint. Alterações feitas após este checkpoint serão perdidas.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Botões
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade600),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Restaurar'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  
Widget _buildSnapshotInfo(Map<String, dynamic> data) {
  // Extrair informações resumidas do snapshot
  final rooms = data['rooms'] as List<dynamic>? ?? [];
  
  int itemsCount = 0;
  int detailsCount = 0;
  
  for (final room in rooms) {
    final items = room['items'] as List<dynamic>? ?? [];
    itemsCount += items.length;
    
    for (final item in items) {
      // A chave correta deve ser 'details', não 'details'
      final details = item['details'] as List<dynamic>? ?? [];
      detailsCount += details.length;
    }
  }
  
  final nonConformities = data['non_conformities'] as List<dynamic>? ?? [];
  final media = data['media'] as List<dynamic>? ?? [];
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Conteúdo do checkpoint:',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 8),
      
      // Informações do snapshot em chips
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildInfoChip(
            icon: Icons.topic_outlined,
            label: '${rooms.length} tópicos',
            color: Colors.blue,
          ),
          _buildInfoChip(
            icon: Icons.list_alt,
            label: '$itemsCount itens',
            color: Colors.teal,
          ),
          _buildInfoChip(
            icon: Icons.details,
            label: '$detailsCount detalhes',
            color: Colors.purple,
          ),
          _buildInfoChip(
            icon: Icons.warning_amber,
            label: '${nonConformities.length} NCs',
            color: Colors.orange,
          ),
          _buildInfoChip(
            icon: Icons.photo_library,
            label: '${media.length} mídias',
            color: Colors.indigo,
          ),
        ],
      ),
    ],
  );
}
  
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}