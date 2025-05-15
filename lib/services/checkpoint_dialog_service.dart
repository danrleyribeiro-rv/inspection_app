// lib/services/checkpoint_dialog_service.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';
import 'package:inspection_app/presentation/widgets/create_checkpoint_dialog.dart';
import 'package:inspection_app/presentation/widgets/checkpoint_history_dialog.dart';
import 'package:inspection_app/presentation/widgets/checkpoint_restore_dialog.dart';

/// Serviço para gerenciar os diálogos relacionados a checkpoints
class CheckpointDialogService {
  final BuildContext _context;
  final InspectionCheckpointService _checkpointService;
  final VoidCallback _onDataReloaded;

  CheckpointDialogService(
    this._context, 
    this._checkpointService,
    this._onDataReloaded,
  );

  /// Exibe o diálogo para criar um novo checkpoint
  void showCreateCheckpointDialog(String inspectionId) {
    showDialog(
      context: _context,
      builder: (context) => CreateCheckpointDialog(
        inspectionId: inspectionId,
        onCheckpointCreated: () {
          // Recarregar inspeção após criar checkpoint
          _onDataReloaded();
        },
      ),
    );
  }

  /// Exibe o diálogo com o histórico de checkpoints
  void showCheckpointHistory(String inspectionId) {
    showDialog(
      context: _context,
      builder: (context) => CheckpointHistoryDialog(
        inspectionId: inspectionId,
        onRestore: _showCheckpointRestoreConfirmation,
      ),
    );
  }

  /// Exibe o diálogo de confirmação para restaurar um checkpoint
  void _showCheckpointRestoreConfirmation(InspectionCheckpoint checkpoint) {
    showDialog(
      context: _context,
      builder: (context) => CheckpointRestoreDialog(
        checkpoint: checkpoint,
        onConfirm: () => _restoreFromCheckpoint(checkpoint),
      ),
    );
  }

  /// Restaura os dados da inspeção a partir de um checkpoint
  Future<void> _restoreFromCheckpoint(InspectionCheckpoint checkpoint) async {
    // Exibir o snackbar de processo iniciado
    ScaffoldMessenger.of(_context).showSnackBar(
      const SnackBar(
        content: Text('Restaurando a inspeção a partir do checkpoint...'),
        duration: Duration(seconds: 3),
      ),
    );
    
    try {
      // Chamar o serviço para restaurar
      final success = await _checkpointService.restoreFromCheckpoint(checkpoint);
      
      if (success) {
        // Recarregar todos os dados
        _onDataReloaded();
        
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(
            content: Text('Inspeção restaurada com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(_context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao restaurar a inspeção.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('Erro ao restaurar inspeção: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}