// lib/services/utils/checkpoint_dialog_service.dart
import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection_checkpoint.dart';
import 'package:inspection_app/services/features/checkpoint_service.dart';
import 'package:inspection_app/presentation/widgets/dialogs/create_checkpoint_dialog.dart';
import 'package:inspection_app/presentation/widgets/dialogs/checkpoint_history_dialog.dart';
import 'package:inspection_app/presentation/widgets/dialogs/checkpoint_restore_dialog.dart';

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
          // A navegação para fechar o diálogo de histórico acontece aqui.
          Navigator.of(dialogContext).pop();
          _showRestoreConfirmationDialog(inspectionId, checkpoint);
        },
      ),
    );
  }

  void _showRestoreConfirmationDialog(
      String inspectionId, InspectionCheckpoint checkpoint) {
    showDialog(
      context: context,
      // Usamos um Builder para obter um novo `context` que podemos usar com segurança
      builder: (dialogContext) => CheckpointRestoreDialog(
        checkpoint: checkpoint,
        onConfirm: () async {
          // Capturamos o ScaffoldMessenger do contexto principal (que ainda pode estar vivo)
          // mas só o usamos se o diálogo ainda estiver montado.
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          // Fecha o diálogo de confirmação ANTES de iniciar a operação demorada.
          Navigator.of(dialogContext).pop();

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Restaurando checkpoint... Aguarde!'),
              duration: Duration(seconds: 3),
            ),
          );

          // O `await` que cria a async gap.
          final success = await checkpointService.restoreCheckpoint(
              inspectionId, checkpoint.id);

          // Após o gap, não temos mais um `context` garantido.
          // Mas podemos usar o `scaffoldMessenger` que capturamos antes.
          // O `onReloadData` é um callback para o widget pai, que é responsável por sua própria segurança (verificar `mounted`).
          if (success) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Checkpoint restaurado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
            // Chama o callback para o widget pai recarregar os dados.
            onReloadData();
          } else {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content:
                    Text('Falha ao restaurar checkpoint. Tente novamente.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}
