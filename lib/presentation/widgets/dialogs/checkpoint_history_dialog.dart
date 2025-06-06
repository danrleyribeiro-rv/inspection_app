// lib/presentation/widgets/checkpoint_history_dialog.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection_checkpoint.dart';
import 'package:inspection_app/services/features/checkpoint_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckpointHistoryDialog extends StatefulWidget {
  final String inspectionId;
  final Function(InspectionCheckpoint) onRestore; // Callback para restauração

  const CheckpointHistoryDialog({
    super.key,
    required this.inspectionId,
    required this.onRestore,
  });

  @override
  State<CheckpointHistoryDialog> createState() =>
      _CheckpointHistoryDialogState();
}

class _CheckpointHistoryDialogState extends State<CheckpointHistoryDialog> {
  final _checkpointService = CheckpointService();
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<InspectionCheckpoint> _checkpoints = [];
  Map<String, String> _userNames = {};
  Map<String, Map<String, dynamic>> _comparisons = {};

  @override
  void initState() {
    super.initState();
    _loadCheckpoints();
  }

  Future<void> _loadCheckpoints() async {
    setState(() => _isLoading = true);

    try {
      // Carregar checkpoints
      final checkpoints =
          await _checkpointService.getCheckpoints(widget.inspectionId);

      // Recuperar nomes de usuários
      final userIds = checkpoints.map((c) => c.createdBy).toSet().toList();

      for (final userId in userIds) {
        try {
          final userDoc =
              await _firestore.collection('inspectors').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final firstName = userData['name'] ?? '';
            final lastName = userData['last_name'] ?? '';
            _userNames[userId] = '$firstName $lastName'.trim();
          }
        } catch (e) {
          print('Erro ao buscar usuário $userId: $e');
          _userNames[userId] = 'Usuário não encontrado';
        }
      }

      // Para cada checkpoint, obter comparação com o estado atual
      for (final checkpoint in checkpoints) {
        try {
          final comparison = await _checkpointService.compareWithCheckpoint(
              widget.inspectionId, checkpoint.id);
          _comparisons[checkpoint.id] = comparison;
        } catch (e) {
          print('Erro ao comparar checkpoint ${checkpoint.id}: $e');
        }
      }

      setState(() {
        _checkpoints = checkpoints;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar checkpoints: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar checkpoints: $e')),
        );
      }
    }
  }

  String _getUserName(String userId) {
    return _userNames[userId] ?? 'Usuário';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ContentBox(
        checkpoints: _checkpoints,
        isLoading: _isLoading,
        getUserName: _getUserName,
        comparisons: _comparisons,
        onRefresh: _loadCheckpoints,
        onRestore: widget.onRestore,
      ),
    );
  }
}

class ContentBox extends StatelessWidget {
  final List<InspectionCheckpoint> checkpoints;
  final bool isLoading;
  final String Function(String) getUserName;
  final Map<String, Map<String, dynamic>> comparisons;
  final VoidCallback onRefresh;
  final Function(InspectionCheckpoint) onRestore;

  const ContentBox({
    super.key,
    required this.checkpoints,
    required this.isLoading,
    required this.getUserName,
    required this.comparisons,
    required this.onRefresh,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
              color: Colors.blue.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Histórico de Checkpoints',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: onRefresh,
                  tooltip: 'Atualizar',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),

          // Conteúdo
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              minHeight: 200,
            ),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                : checkpoints.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Nenhum checkpoint registrado',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: checkpoints.length,
                        itemBuilder: (context, index) {
                          final checkpoint = checkpoints[index];
                          final userName = getUserName(checkpoint.createdBy);
                          final comparison = comparisons[checkpoint.id];

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade700),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cabeçalho
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          userName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        checkpoint.formattedDate,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Mensagem do checkpoint
                                  if (checkpoint.message != null &&
                                      checkpoint.message!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.2),
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

                                  // Informações de comparação
                                  if (comparison != null) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        _buildComparisonChip(
                                            'Tópicos',
                                            comparison['topics']?['current'] ??
                                                0,
                                            comparison['topics']
                                                    ?['checkpoint'] ??
                                                0),
                                        _buildComparisonChip(
                                            'Itens',
                                            comparison['items']?['current'] ??
                                                0,
                                            comparison['items']
                                                    ?['checkpoint'] ??
                                                0),
                                        _buildComparisonChip(
                                            'Detalhes',
                                            comparison['details']?['current'] ??
                                                0,
                                            comparison['details']
                                                    ?['checkpoint'] ??
                                                0),
                                        _buildComparisonChip(
                                            'Mídias',
                                            comparison['media']?['current'] ??
                                                0,
                                            comparison['media']
                                                    ?['checkpoint'] ??
                                                0),
                                        _buildComparisonChip(
                                            'NCs',
                                            comparison['non_conformities']
                                                    ?['current'] ??
                                                0,
                                            comparison['non_conformities']
                                                    ?['checkpoint'] ??
                                                0),
                                      ],
                                    ),
                                  ],

                                  // Botão de restauração
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context)
                                              .pop(); // Fecha o diálogo atual
                                          onRestore(
                                              checkpoint); // Chama callback de restauração
                                        },
                                        icon:
                                            const Icon(Icons.restore, size: 16),
                                        label: const Text('Restaurar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          textStyle:
                                              const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChip(String label, int current, int checkpoint) {
    final diff = current - checkpoint;
    final Color color = diff > 0
        ? Colors.green
        : diff < 0
            ? Colors.red
            : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$current / $checkpoint',
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (diff != 0) ...[
            const SizedBox(width: 3),
            Icon(
              diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
              size: 10,
              color: color,
            ),
            Text(
              '${diff.abs()}',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
