import 'package:flutter/material.dart';
import 'package:inspection_app/services/features/checkpoint_service.dart';
import 'package:inspection_app/presentation/widgets/create_checkpoint_dialog.dart';
import 'package:inspection_app/presentation/widgets/checkpoint_history_dialog.dart';
import 'package:inspection_app/presentation/widgets/checkpoint_restore_dialog.dart';

class CheckpointDialogService {
  final BuildContext context;
  final CheckpointService checkpointService;
  final Function() onReloadData;
  
  CheckpointDialogService(
    this.context,
    this.checkpointService,
    this.onReloadData,
  );
  
  void showCreateCheckpointDialog(String inspectionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => CreateCheckpointDialog(
        inspectionId: inspectionId,
        onCheckpointCreated: onReloadData,
      ),
    );
  }
  
  void showCheckpointHistory(String inspectionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => CheckpointHistoryDialog(
        inspectionId: inspectionId,
        onRestore: (checkpoint) {
          _showRestoreConfirmationDialog(inspectionId, checkpoint);
        },
      ),
    );
  }
  
  void _showRestoreConfirmationDialog(String inspectionId, InspectionCheckpoint checkpoint) {
    showDialog(
      context: context,
      builder: (dialogContext) => CheckpointRestoreDialog(
        checkpoint: checkpoint,
        onConfirm: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restaurando checkpoint... Aguarde!'),
              duration: Duration(seconds: 3),
            ),
          );
          
          final success = await checkpointService.restoreCheckpoint(inspectionId, checkpoint.id);
          
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Checkpoint restaurado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
            onReloadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Falha ao restaurar checkpoint. Tente novamente.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}