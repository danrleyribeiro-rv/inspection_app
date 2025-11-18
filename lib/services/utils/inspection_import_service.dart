// lib/services/utils/inspection_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/storage/database_helper.dart';
import 'package:http/http.dart' as http;

class InspectionImportService {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  /// Importa dados do arquivo .tar e substitui na inspeção atual
  /// Se currentInspectionId for null, cria uma nova inspeção com o ID exportado
  Future<bool> importInspection({
    required BuildContext context,
    required String filePath,
    String? currentInspectionId,
  }) async {
    try {
      debugPrint('Starting import from: $filePath');
      if (currentInspectionId != null) {
        debugPrint('Importing into existing inspection: $currentInspectionId');
      } else {
        debugPrint('Creating new inspection from export');
      }

      // Verificar se o arquivo existe
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Arquivo não encontrado: $filePath');
      }

      // Ler o arquivo .tar
      final bytes = await file.readAsBytes();

      // Decodificar o arquivo .tar
      Archive archive;
      try {
        archive = TarDecoder().decodeBytes(bytes);
      } catch (e) {
        throw Exception('Formato de arquivo inválido. Use apenas arquivo .tar');
      }

      // Encontrar e ler o arquivo hive_data.json
      final jsonFile = archive.files.firstWhere(
        (file) => file.name == 'hive_data.json',
        orElse: () => throw Exception('Arquivo hive_data.json não encontrado no .tar'),
      );

      final jsonString = utf8.decode(jsonFile.content as List<int>);
      final Map<String, dynamic> hiveData = jsonDecode(jsonString);

      // Verificar inspection_id
      final exportedInspectionId = hiveData['inspection_id'] as String?;
      if (exportedInspectionId == null) {
        throw Exception('inspection_id não encontrado nos dados exportados');
      }

      debugPrint('Exported inspection_id: $exportedInspectionId');

      // VALIDAÇÃO: Se currentInspectionId foi fornecido, deve ser o MESMO do arquivo exportado
      if (currentInspectionId != null && currentInspectionId != exportedInspectionId) {
        throw Exception(
          'Erro: Esta inspeção não pode ser importada aqui.\n'
          'ID da inspeção atual: $currentInspectionId\n'
          'ID da inspeção exportada: $exportedInspectionId\n\n'
          'Para importar esta inspeção, você deve:\n'
          '1. Abrir a inspeção correta ($exportedInspectionId), ou\n'
          '2. Criar uma nova inspeção a partir deste backup'
        );
      }

      // Determinar qual ID usar: se não foi passado um ID atual, usar o exportado
      final targetInspectionId = currentInspectionId ?? exportedInspectionId;
      debugPrint('Target inspection_id: $targetInspectionId');

      // Remover dados antigos apenas se estivermos substituindo uma inspeção existente
      if (currentInspectionId != null) {
        await _clearCurrentInspectionData(currentInspectionId);
        debugPrint('Cleared old data for inspection: $currentInspectionId');
      }

      // Importar Inspeção (usando o ID de destino)
      if (hiveData['inspection'] != null) {
        final inspectionMap = hiveData['inspection'] as Map<String, dynamic>;
        // Substituir o ID pelo de destino (pode ser o atual ou o exportado)
        inspectionMap['id'] = targetInspectionId;
        final inspection = Inspection.fromMap(inspectionMap);
        await _serviceFactory.dataService.saveInspection(inspection);
        debugPrint('Inspection imported: ${inspection.id}');
      }

      // Importar Topics
      if (hiveData['topics'] != null) {
        final topicsList = hiveData['topics'] as List<dynamic>;
        for (final topicData in topicsList) {
          final topicMap = topicData as Map<String, dynamic>;
          // Atualizar inspection_id para o de destino
          topicMap['inspection_id'] = targetInspectionId;
          final topic = Topic.fromMap(topicMap);
          await _serviceFactory.dataService.saveTopic(topic);
          debugPrint('Topic imported: ${topic.id}');
        }
      }

      // Importar Items
      if (hiveData['items'] != null) {
        final itemsList = hiveData['items'] as List<dynamic>;
        for (final itemData in itemsList) {
          final itemMap = itemData as Map<String, dynamic>;
          // Atualizar inspection_id para o de destino
          itemMap['inspection_id'] = targetInspectionId;
          final item = Item.fromMap(itemMap);
          await _serviceFactory.dataService.saveItem(item);
          debugPrint('Item imported: ${item.id}');
        }
      }

      // Importar Details
      if (hiveData['details'] != null) {
        final detailsList = hiveData['details'] as List<dynamic>;
        for (final detailData in detailsList) {
          final detailMap = detailData as Map<String, dynamic>;
          // Atualizar inspection_id para o de destino
          detailMap['inspection_id'] = targetInspectionId;
          final detail = Detail.fromMap(detailMap);
          await _serviceFactory.dataService.saveDetail(detail);
          debugPrint('Detail imported: ${detail.id}');
        }
      }

      // Importar NonConformities
      if (hiveData['non_conformities'] != null) {
        final ncsList = hiveData['non_conformities'] as List<dynamic>;
        for (final ncData in ncsList) {
          final ncMap = ncData as Map<String, dynamic>;
          // Atualizar inspection_id para o de destino
          ncMap['inspection_id'] = targetInspectionId;
          final nc = NonConformity.fromMap(ncMap);
          await _serviceFactory.dataService.saveNonConformity(nc);
          debugPrint('NonConformity imported: ${nc.id}');
        }
      }

      debugPrint('Import completed. Starting media download from cloud...');

      // IMPORTANTE: As imagens NÃO são importadas do arquivo .tar
      // Em vez disso, são baixadas diretamente da nuvem usando o cloudUrl
      // Isso garante que temos as versões mais recentes das imagens
      if (hiveData['offline_media'] != null) {
        final mediaList = hiveData['offline_media'] as List<dynamic>;
        await _downloadMediaFromCloud(mediaList, targetInspectionId);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspeção importada com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error importing inspection: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar inspeção: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  /// Remove todos os dados da inspeção atual antes de importar novos dados
  Future<void> _clearCurrentInspectionData(String inspectionId) async {
    try {
      // Remover Topics
      final topics = await _serviceFactory.dataService.getTopics(inspectionId);
      for (final topic in topics) {
        // Remover Items deste tópico
        final items = await _serviceFactory.dataService.getItems(topic.id);
        for (final item in items) {
          // Remover Details deste item
          final details = await _serviceFactory.dataService.getDetails(item.id);
          for (final detail in details) {
            await _serviceFactory.dataService.deleteDetail(detail.id);
          }
          await _serviceFactory.dataService.deleteItem(item.id);
        }

        // Remover Details diretos
        final directDetails = await _serviceFactory.dataService.getDirectDetails(topic.id);
        for (final detail in directDetails) {
          await _serviceFactory.dataService.deleteDetail(detail.id);
        }

        await _serviceFactory.dataService.deleteTopic(topic.id);
      }

      // Remover NonConformities
      final ncs = await _serviceFactory.dataService.getNonConformities(inspectionId);
      for (final nc in ncs) {
        await _serviceFactory.dataService.deleteNonConformity(nc.id);
      }

      // Remover OfflineMedia
      final mediaList = await _serviceFactory.mediaService.getMediaByInspection(inspectionId);
      for (final media in mediaList) {
        await _serviceFactory.mediaService.deleteMedia(media.id);
      }

      debugPrint('Cleared all data for inspection: $inspectionId');
    } catch (e) {
      debugPrint('Error clearing inspection data: $e');
      rethrow;
    }
  }

  /// Baixa mídias da nuvem usando cloudUrl
  Future<void> _downloadMediaFromCloud(
    List<dynamic> mediaList,
    String currentInspectionId,
  ) async {
    int successCount = 0;
    int errorCount = 0;

    for (final mediaData in mediaList) {
      try {
        final mediaMap = mediaData as Map<String, dynamic>;

        final String? cloudUrl = mediaMap['cloud_url'];
        if (cloudUrl == null || cloudUrl.isEmpty) {
          debugPrint('No cloud URL for media, skipping');
          errorCount++;
          continue;
        }

        debugPrint('Downloading media from: $cloudUrl');

        // Baixar mídia da nuvem
        final response = await http.get(Uri.parse(cloudUrl));
        if (response.statusCode != 200) {
          debugPrint('Failed to download media: HTTP ${response.statusCode}');
          errorCount++;
          continue;
        }

        // Criar diretório de mídias
        final appDir = await getApplicationDocumentsDirectory();
        final mediaDir = Directory('${appDir.path}/media');
        await mediaDir.create(recursive: true);

        // Usar o filename original
        final String filename = mediaMap['filename'] ?? 'media_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String localPath = '${mediaDir.path}/$filename';

        // Salvar arquivo localmente
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);

        debugPrint('Media downloaded to: $localPath');

        // Atualizar inspection_id para o atual e localPath
        mediaMap['inspection_id'] = currentInspectionId;
        mediaMap['local_path'] = localPath;
        mediaMap['is_uploaded'] = 1; // Marcar como já enviado (veio da nuvem)

        // Criar objeto OfflineMedia
        final media = OfflineMedia.fromMap(mediaMap);

        // Salvar no banco de dados Hive
        await DatabaseHelper.insertOfflineMedia(media);

        debugPrint('Media imported successfully: $filename');
        successCount++;
      } catch (e) {
        debugPrint('Error downloading media: $e');
        errorCount++;
        // Continuar com próximas mídias
      }
    }

    debugPrint('Media download completed: $successCount successful, $errorCount errors');
  }
}
