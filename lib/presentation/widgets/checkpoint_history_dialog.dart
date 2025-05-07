// lib/presentation/widgets/checkpoint_history_dialog.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CheckpointHistoryDialog extends StatefulWidget {
  final String inspectionId;

  const CheckpointHistoryDialog({
    super.key,
    required this.inspectionId,
  });

  @override
  State<CheckpointHistoryDialog> createState() => _CheckpointHistoryDialogState();
}

class _CheckpointHistoryDialogState extends State<CheckpointHistoryDialog> {
  final _checkpointService = InspectionCheckpointService();
  final _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  List<InspectionCheckpoint> _checkpoints = [];
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadCheckpoints();
  }

  Future<void> _loadCheckpoints() async {
    setState(() => _isLoading = true);

    try {
      // Carregar checkpoints
      final checkpoints = await _checkpointService.getCheckpoints(widget.inspectionId);
      
      // Recuperar nomes de usuários
      final userIds = checkpoints.map((c) => c.createdBy).toSet().toList();
      
      for (final userId in userIds) {
        try {
          final userDoc = await _firestore.collection('inspectors').doc(userId).get();
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
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ContentBox(
        checkpoints: _checkpoints,
        isLoading: _isLoading,
        getUserName: _getUserName,
        onRefresh: _loadCheckpoints,
      ),
    );
  }
}

class ContentBox extends StatelessWidget {
  final List<InspectionCheckpoint> checkpoints;
  final bool isLoading;
  final String Function(String) getUserName;
  final VoidCallback onRefresh;

  const ContentBox({
    super.key,
    required this.checkpoints,
    required this.isLoading,
    required this.getUserName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
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
                      fontSize: 18,
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
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  
                                  // Informações de progresso
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: checkpoint.completionPercentage / 100,
                                    backgroundColor: Colors.grey.shade700,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getProgressColor(checkpoint.completionPercentage),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Progresso: ${checkpoint.completionPercentage.toStringAsFixed(1)}% (${checkpoint.completedItems}/${checkpoint.totalItems} itens)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  
                                  // Mensagem do checkpoint
                                  if (checkpoint.message != null && checkpoint.message!.isNotEmpty) ...[
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

  Color _getProgressColor(double percentage) {
    if (percentage < 30) {
      return Colors.red;
    } else if (percentage < 70) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}