// Exemplo de como usar o InspectionCard com sincronização que mostra loading
// Copie este código para sua tela que usa InspectionCard

import 'package:flutter/material.dart';
import 'package:lince_inspecoes/presentation/widgets/common/inspection_card.dart';
import 'package:lince_inspecoes/services/native_sync_service.dart';
import 'package:lince_inspecoes/models/sync_progress.dart';

class ExampleInspectionList extends StatefulWidget {
  @override
  _ExampleInspectionListState createState() => _ExampleInspectionListState();
}

class _ExampleInspectionListState extends State<ExampleInspectionList> {
  // IMPORTANTE: Estes mapas controlam o estado de sincronização de cada inspeção
  Map<String, bool> syncingStatus = {}; // Se está sincronizando
  Map<String, bool> verifiedStatus = {}; // Se foi verificado
  
  @override
  void initState() {
    super.initState();
    
    // CRUCIAL: Escutar o stream de progresso de sincronização
    NativeSyncService.instance.syncProgressStream.listen((progress) {
      if (mounted) {
        setState(() {
          final inspectionId = progress.inspectionId;
          
          // Debug logs para verificar se o stream está funcionando
          print('🔄 Sync Progress: ID=$inspectionId, Phase=${progress.phase}');
          
          switch (progress.phase) {
            case SyncPhase.starting:
            case SyncPhase.uploading:
            case SyncPhase.downloading:
            case SyncPhase.verifying:
              // AQUI definimos isSyncing = true
              syncingStatus[inspectionId] = true;
              verifiedStatus[inspectionId] = false;
              print('✅ Set syncing=true for $inspectionId');
              break;
              
            case SyncPhase.completed:
              // AQUI definimos isSyncing = false e verified = true
              syncingStatus[inspectionId] = false;
              verifiedStatus[inspectionId] = true;
              print('✅ Set syncing=false, verified=true for $inspectionId');
              break;
              
            case SyncPhase.error:
              // AQUI definimos isSyncing = false em caso de erro
              syncingStatus[inspectionId] = false;
              verifiedStatus[inspectionId] = false;
              print('❌ Set syncing=false, verified=false for $inspectionId');
              break;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inspeções')),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: sampleInspections.length,
        itemBuilder: (context, index) {
          final inspection = sampleInspections[index];
          final inspectionId = inspection['id'] as String;
          
          // IMPORTANTE: Usar os valores dos mapas de status
          final isSyncing = syncingStatus[inspectionId] ?? false;
          final isVerified = verifiedStatus[inspectionId] ?? false;
          
          // Debug log para ver os valores sendo passados
          print('🎯 Building card for $inspectionId: syncing=$isSyncing, verified=$isVerified');
          
          return InspectionCard(
            inspection: inspection,
            onViewDetails: () {
              print('Visualizar inspeção $inspectionId');
            },
            onSync: () async {
              print('🚀 Iniciando sincronização de $inspectionId');
              
              // IMPORTANTE: NÃO definir manualmente syncingStatus aqui
              // O stream listener vai cuidar disso automaticamente
              
              try {
                await NativeSyncService.instance.startInspectionSync(inspectionId);
              } catch (e) {
                print('❌ Erro na sincronização: $e');
                // Em caso de erro, resetar o status manualmente
                if (mounted) {
                  setState(() {
                    syncingStatus[inspectionId] = false;
                    verifiedStatus[inspectionId] = false;
                  });
                }
              }
            },
            googleMapsApiKey: 'YOUR_GOOGLE_MAPS_API_KEY',
            isFullyDownloaded: inspection['isDownloaded'] ?? false,
            needsSync: inspection['needsSync'] ?? false,
            hasConflicts: inspection['hasConflicts'] ?? false,
            
            // CRUCIAL: Passar os valores corretos aqui
            isSyncing: isSyncing, // ← Este é o parâmetro que controla o loading!
            isVerified: isVerified,
            
            pendingImagesCount: inspection['pendingImages'] as int?,
          );
        },
      ),
    );
  }
}

// Dados de exemplo
final List<Map<String, dynamic>> sampleInspections = [
  {
    'id': 'inspection_1',
    'title': 'Inspeção de Estrutura - Edifício A',
    'cod': 'EST-001',
    'scheduled_date': DateTime.now().toIso8601String(),
    'isDownloaded': true,
    'needsSync': true,
    'hasConflicts': false,
    'pendingImages': 3,
  },
  {
    'id': 'inspection_2',
    'title': 'Inspeção Elétrica - Prédio B',
    'cod': 'ELE-002',
    'scheduled_date': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
    'isDownloaded': true,
    'needsSync': true,
    'hasConflicts': false,
    'pendingImages': 1,
  },
];