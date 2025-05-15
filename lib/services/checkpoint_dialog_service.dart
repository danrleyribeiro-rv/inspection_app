import 'package:flutter/material.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';
import 'package:inspection_app/presentation/widgets/create_checkpoint_dialog.dart';
import 'package:inspection_app/presentation/widgets/checkpoint_history_dialog.dart';
import 'package:inspection_app/presentation/widgets/checkpoint_restore_dialog.dart';

class CheckpointDialogService {
  final BuildContext context;
  final InspectionCheckpointService checkpointService;
  final Function() onReloadData;
  
  CheckpointDialogService(
    this.context,
    this.checkpointService,
    this.onReloadData,
  );
  
  // Show the create checkpoint dialog
  void showCreateCheckpointDialog(String inspectionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => CreateCheckpointDialog(
        inspectionId: inspectionId,
        onCheckpointCreated: () {
          // Reload data if needed
          onReloadData();
        },
      ),
    );
  }
  
  // Show the checkpoint history dialog
  void showCheckpointHistory(String inspectionId) {
    showDialog(
      context: context,
      builder: (dialogContext) => CheckpointHistoryDialog(
        inspectionId: inspectionId,
        onRestore: (checkpoint) {
          // Show restore confirmation dialog
          showRestoreConfirmationDialog(inspectionId, checkpoint);
        },
      ),
    );
  }
  
  // Show the restore confirmation dialog
  void showRestoreConfirmationDialog(String inspectionId, InspectionCheckpoint checkpoint) {
    showDialog(
      context: context,
      builder: (dialogContext) => CheckpointRestoreDialog(
        checkpoint: checkpoint,
        onConfirm: () async {
          // Show loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restaurando checkpoint... Aguarde!'),
              duration: Duration(seconds: 3),
            ),
          );
          
          // Restore the checkpoint
          final success = await checkpointService.restoreCheckpoint(
            inspectionId,
            checkpoint.id,
          );
          
          if (success) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Checkpoint restaurado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Reload data
            onReloadData();
          } else {
            // Show error message
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