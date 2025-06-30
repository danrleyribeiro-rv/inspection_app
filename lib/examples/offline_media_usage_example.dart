// lib/examples/offline_media_usage_example.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/services/features/media_service.dart';
import 'package:inspection_app/models/offline_media.dart';

/// Exemplo de como usar o novo fluxo offline-first para mídia
class OfflineMediaUsageExample {
  static final MediaService _mediaService = ServiceFactory().mediaService;

  /// Exemplo 1: Capturar e processar uma imagem offline-first
  static Future<void> captureImageExample({
    required String imagePath,
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
  }) async {
    try {
      // 1. Capturar e processar mídia - será salva localmente imediatamente
      final offlineMedia = await _mediaService.captureAndProcessMedia(
        inputPath: imagePath,
        inspectionId: inspectionId,
        type: 'image',
        topicId: topicId,
        itemId: itemId,
        detailId: detailId,
        metadata: {
          'captured_at': DateTime.now().toIso8601String(),
          'device_info': 'Example Device',
        },
      );

      debugPrint('Mídia capturada e salva localmente: ${offlineMedia.id}');
      debugPrint('Arquivo local: ${offlineMedia.localPath}');
      debugPrint('Status processado: ${offlineMedia.isProcessed}');
      debugPrint('Status uploaded: ${offlineMedia.isUploaded}');

      // 2. Escutar eventos de upload
      _mediaService.uploadEventStream.listen((event) {
        if (event.mediaId == offlineMedia.id) {
          switch (event.status) {
            case UploadStatus.processed:
              debugPrint('Mídia processada: ${event.message}');
              break;
            case UploadStatus.uploading:
              debugPrint('Fazendo upload: ${event.message}');
              break;
            case UploadStatus.completed:
              debugPrint('Upload concluído: ${event.downloadUrl}');
              break;
            case UploadStatus.error:
              debugPrint('Erro: ${event.message}');
              break;
            default:
              debugPrint('Status: ${event.status} - ${event.message}');
          }
        }
      });
    } catch (e) {
      debugPrint('Erro ao capturar mídia: $e');
    }
  }

  /// Exemplo 2: Verificar status de mídias pendentes
  static void checkPendingMediaExample(String inspectionId) {
    // Obter todas as mídias pendentes para uma inspeção
    final pendingMedia = _mediaService.getPendingMediaForInspection(inspectionId);
    
    debugPrint('Mídias pendentes para inspeção $inspectionId:');
    for (final media in pendingMedia) {
      debugPrint('- ID: ${media.id}');
      debugPrint('  Arquivo: ${media.fileName}');
      debugPrint('  Tipo: ${media.type}');
      debugPrint('  Processado: ${media.isProcessed}');
      debugPrint('  Enviado: ${media.isUploaded}');
      debugPrint('  Tentativas: ${media.retryCount}');
      if (media.hasError) {
        debugPrint('  Erro: ${media.errorMessage}');
      }
    }
  }

  /// Exemplo 3: Forçar retry de uma mídia com erro
  static Future<void> retryFailedMediaExample(String mediaId) async {
    try {
      await _mediaService.retryMediaUpload(mediaId);
      debugPrint('Retry iniciado para mídia: $mediaId');
    } catch (e) {
      debugPrint('Erro ao tentar retry: $e');
    }
  }

  /// Exemplo 4: Obter estatísticas de mídia offline
  static void getMediaStatsExample() {
    final stats = _mediaService.getOfflineMediaStats();
    
    debugPrint('Estatísticas de mídia offline:');
    debugPrint('- Total: ${stats['total']}');
    debugPrint('- Pendentes: ${stats['pending']}');
    debugPrint('- Enviadas: ${stats['uploaded']}');
    debugPrint('- Com erro: ${stats['errors']}');
  }

  /// Exemplo 5: Limpeza de mídias antigas
  static Future<void> cleanupOldMediaExample() async {
    try {
      // Limpar mídias enviadas há mais de 7 dias
      await _mediaService.cleanupOldMedia(daysOld: 7);
      debugPrint('Limpeza de mídias antigas concluída');
    } catch (e) {
      debugPrint('Erro na limpeza: $e');
    }
  }

  /// Exemplo 6: Widget para mostrar status de upload em tempo real
  static Widget buildUploadStatusWidget(String mediaId) {
    return StreamBuilder<OfflineMediaUploadEvent>(
      stream: _mediaService.uploadEventStream
          .where((event) => event.mediaId == mediaId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final event = snapshot.data!;
        IconData icon;
        Color color;
        String message = event.message;

        switch (event.status) {
          case UploadStatus.processing:
            icon = Icons.settings;
            color = Colors.orange;
            break;
          case UploadStatus.processed:
            icon = Icons.check_circle_outline;
            color = Colors.blue;
            break;
          case UploadStatus.uploading:
            icon = Icons.cloud_upload;
            color = Colors.blue;
            break;
          case UploadStatus.completed:
            icon = Icons.cloud_done;
            color = Colors.green;
            break;
          case UploadStatus.error:
            icon = Icons.error;
            color = Colors.red;
            break;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              message,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  /// Exemplo 7: Lista de mídias offline com status
  static Widget buildOfflineMediaList(String inspectionId) {
    final allMedia = _mediaService.getAllMediaForInspection(inspectionId);
    
    return ListView.builder(
      itemCount: allMedia.length,
      itemBuilder: (context, index) {
        final media = allMedia[index];
        
        return ListTile(
          leading: Icon(
            media.type == 'image' ? Icons.image : Icons.videocam,
          ),
          title: Text(media.fileName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Criado em: ${media.createdAt}'),
              buildUploadStatusWidget(media.id),
            ],
          ),
          trailing: media.hasError
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => retryFailedMediaExample(media.id),
                )
              : null,
        );
      },
    );
  }
}

/// Como usar em uma tela:
/// 
/// ```dart
/// class ExampleScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Mídia Offline')),
///       body: Column(
///         children: [
///           ElevatedButton(
///             onPressed: () {
///               // Exemplo de captura
///               OfflineMediaUsageExample.captureImageExample(
///                 imagePath: '/caminho/para/imagem.jpg',
///                 inspectionId: 'inspection_123',
///                 topicId: 'topic_456',
///               );
///             },
///             child: Text('Capturar Imagem'),
///           ),
///           Expanded(
///             child: OfflineMediaUsageExample.buildOfflineMediaList('inspection_123'),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```