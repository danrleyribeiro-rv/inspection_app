// lib/services/utils/inspection_export_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class InspectionExportService {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  /// Exporta uma inspeção completa como arquivo ZIP
  Future<void> exportInspection({
    required BuildContext context,
    required String inspectionId,
    required Inspection? inspection,
    required List<Topic> topics,
    required Map<String, List<Item>> itemsCache,
    required Map<String, List<Detail>> detailsCache,
  }) async {
    try {
      // Create cloud-sync format inspection data
      final Map<String, dynamic> inspectionData = inspection?.toMap() ?? {};

      // Remove ALL local-only fields to match cloud format exactly
      final fieldsToRemove = [
        'id',
        'is_deleted',
        'has_local_changes',
        'is_synced',
        'last_sync_at',
        'sync_history',
        'local_id'
      ];
      for (final field in fieldsToRemove) {
        inspectionData.remove(field);
      }

      // Ensure timestamps are properly formatted for cloud sync
      if (inspectionData['created_at'] != null) {
        final createdAt = inspectionData['created_at'];
        if (createdAt is DateTime) {
          inspectionData['created_at'] = {
            '_seconds': (createdAt.millisecondsSinceEpoch / 1000).floor(),
            '_nanoseconds': (createdAt.millisecondsSinceEpoch % 1000) * 1000000,
          };
        }
      }

      if (inspectionData['updated_at'] != null) {
        final updatedAt = inspectionData['updated_at'];
        if (updatedAt is DateTime) {
          inspectionData['updated_at'] = {
            '_seconds': (updatedAt.millisecondsSinceEpoch / 1000).floor(),
            '_nanoseconds': (updatedAt.millisecondsSinceEpoch % 1000) * 1000000,
          };
        }
      }

      // Build ordered and organized topics structure
      final List<Map<String, dynamic>> orderedTopicsData = [];

      // Sort topics by position for proper ordering
      final sortedTopics = List<Topic>.from(topics);
      sortedTopics.sort((a, b) => a.position.compareTo(b.position));

      for (final topic in sortedTopics) {
        final topicId = topic.id;

        Map<String, dynamic> topicData;
        if (topic.directDetails == true) {
          // Direct details topic
          final directDetails = detailsCache['${topicId}_direct'] ?? [];
          final sortedDetails = List.from(directDetails);
          sortedDetails
              .sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

          final List<Map<String, dynamic>> detailsData = [];

          for (final detail in sortedDetails) {
            final detailMedia = await _serviceFactory.mediaService
                .getMediaByContext(detailId: detail.id);
            final detailNCs = await _serviceFactory.dataService
                .getNonConformitiesByDetail(detail.id ?? '');

            detailsData.add({
              'name': detail.detailName,
              'type': detail.type ?? 'text',
              'options': detail.options ?? [],
              'value': detail.detailValue,
              'observation': detail.observation,
              'is_damaged': false,
              'media': detailMedia
                  .map((media) => _formatMediaForExport(media))
                  .toList(),
              'non_conformities': detailNCs.map((nc) => nc.toMap()).toList(),
            });
          }

          final topicMedia = await _serviceFactory.mediaService
              .getMediaByContext(topicId: topicId);
          final topicNCs = await _serviceFactory.dataService
              .getNonConformitiesByTopic(topicId);

          topicData = {
            'name': topic.topicName,
            'description': topic.topicLabel,
            'observation': topic.observation,
            'direct_details': true,
            'details': detailsData,
            'media': topicMedia
                .map((media) => _formatMediaForExport(media))
                .toList(),
            'non_conformities': topicNCs.map((nc) => nc.toMap()).toList(),
          };
        } else {
          // Regular topic with items
          final items = itemsCache[topicId] ?? [];
          final sortedItems = List.from(items);
          sortedItems
              .sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

          final List<Map<String, dynamic>> itemsData = [];

          for (final item in sortedItems) {
            final itemId = item.id ?? 'item_${sortedItems.indexOf(item)}';
            final details = detailsCache['${topicId}_$itemId'] ?? [];
            final sortedDetails = List.from(details);
            sortedDetails
                .sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

            final List<Map<String, dynamic>> detailsData = [];

            for (final detail in sortedDetails) {
              final detailMedia = await _serviceFactory.mediaService
                  .getMediaByContext(detailId: detail.id);
              final detailNCs = await _serviceFactory.dataService
                  .getNonConformitiesByDetail(detail.id ?? '');

              detailsData.add({
                'name': detail.detailName,
                'type': detail.type ?? 'text',
                'options': detail.options ?? [],
                'value': detail.detailValue,
                'observation': detail.observation,
                'is_damaged': false,
                'media': detailMedia
                    .map((media) => _formatMediaForExport(media))
                    .toList(),
                'non_conformities': detailNCs.map((nc) => nc.toMap()).toList(),
              });
            }

            final itemMedia = await _serviceFactory.mediaService
                .getMediaByContext(itemId: itemId);
            final itemNCs = await _serviceFactory.dataService
                .getNonConformitiesByItem(itemId);

            itemsData.add({
              'name': item.itemName,
              'description': item.itemLabel,
              'observation': item.observation,
              'evaluable': item.evaluable ?? false,
              'evaluation_options': item.evaluationOptions ?? [],
              'evaluation_value': item.evaluationValue,
              'details': detailsData,
              'media': itemMedia
                  .map((media) => _formatMediaForExport(media))
                  .toList(),
              'non_conformities': itemNCs.map((nc) => nc.toMap()).toList(),
            });
          }

          final topicMedia = await _serviceFactory.mediaService
              .getMediaByContext(topicId: topicId);
          final topicNCs = await _serviceFactory.dataService
              .getNonConformitiesByTopic(topicId);

          topicData = {
            'name': topic.topicName,
            'description': topic.topicLabel,
            'observation': topic.observation,
            'direct_details': false,
            'items': itemsData,
            'media': topicMedia
                .map((media) => _formatMediaForExport(media))
                .toList(),
            'non_conformities': topicNCs.map((nc) => nc.toMap()).toList(),
          };
        }

        orderedTopicsData.add(topicData);
      }

      inspectionData['topics'] = orderedTopicsData;

      // Create ZIP archive
      final archive = Archive();

      // Add inspection JSON file
      final jsonString = jsonEncode(inspectionData);
      final jsonBytes = utf8.encode(jsonString);
      final jsonFile =
          ArchiveFile('inspection.json', jsonBytes.length, jsonBytes);
      archive.addFile(jsonFile);

      // Criar arquivo .tar com dados do Hive apenas desta inspeção
      try {
        final tarArchive = Archive();

        // Exportar dados do Hive apenas desta inspeção
        final Map<String, dynamic> hiveData = {
          'inspection_id': inspectionId,
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0',
        };

        // Exportar Inspeção
        final inspectionBox = await _serviceFactory.dataService.getInspection(inspectionId);
        if (inspectionBox != null) {
          hiveData['inspection'] = inspectionBox.toMap();
        }

        // Exportar Topics
        final topicsBox = await _serviceFactory.dataService.getTopics(inspectionId);
        final topicsList = <Map<String, dynamic>>[];
        for (final t in topicsBox) {
          topicsList.add(t.toMap());
        }
        hiveData['topics'] = topicsList;

        // Exportar Items
        final allItems = <Map<String, dynamic>>[];
        for (final topic in topicsBox) {
          final items = await _serviceFactory.dataService.getItems(topic.id);
          for (final i in items) {
            allItems.add(i.toMap());
          }
        }
        hiveData['items'] = allItems;

        // Exportar Details
        final allDetails = <Map<String, dynamic>>[];
        for (final topic in topicsBox) {
          if (topic.directDetails == true) {
            final details = await _serviceFactory.dataService.getDirectDetails(topic.id);
            for (final d in details) {
              allDetails.add(d.toMap());
            }
          } else {
            final items = await _serviceFactory.dataService.getItems(topic.id);
            for (final item in items) {
              final details = await _serviceFactory.dataService.getDetails(item.id);
              for (final d in details) {
                allDetails.add(d.toMap());
              }
            }
          }
        }
        hiveData['details'] = allDetails;

        // Exportar NonConformities
        final allNcs = <Map<String, dynamic>>[];
        for (final topic in topicsBox) {
          final topicNcs = await _serviceFactory.dataService.getNonConformitiesByTopic(topic.id);
          for (final nc in topicNcs) {
            allNcs.add(nc.toMap());
          }
        }
        hiveData['non_conformities'] = allNcs;

        // Exportar OfflineMedia
        final mediaList = await _serviceFactory.mediaService.getMediaByInspection(inspectionId);
        final mediaListData = <Map<String, dynamic>>[];
        for (final m in mediaList) {
          mediaListData.add(m.toMap());
        }
        hiveData['offline_media'] = mediaListData;

        // Criar arquivo hive_data.json
        final hiveJsonString = jsonEncode(hiveData);
        final hiveJsonBytes = utf8.encode(hiveJsonString);
        final hiveJsonFile = ArchiveFile('hive_data.json', hiveJsonBytes.length, hiveJsonBytes);
        tarArchive.addFile(hiveJsonFile);

        // Codificar como .tar com nome baseado no código da inspeção
        final tarBytes = TarEncoder().encode(tarArchive);
        final tarFileName = '${inspection?.cod ?? 'inspection'}.tar';
        final tarFile = ArchiveFile(tarFileName, tarBytes.length, tarBytes);
        archive.addFile(tarFile);

        debugPrint('Hive database backup created successfully');
      } catch (e) {
        debugPrint('Error creating Hive backup: $e');
        // Criar arquivo de erro
        final errorInfo = {
          'error': 'Failed to backup Hive database: $e',
          'timestamp': DateTime.now().toIso8601String(),
          'inspection_id': inspectionId,
        };
        final errorBytes = utf8.encode(jsonEncode(errorInfo));
        final errorFile = ArchiveFile(
            'database/error_log.json', errorBytes.length, errorBytes);
        archive.addFile(errorFile);
      }

      // Collect and organize all media files with proper structure
      final allMedia = await _serviceFactory.mediaService
          .getMediaByInspection(inspectionId);

      // Build organized folder structure for media
      for (final media in allMedia) {
        try {
          if (media.localPath.isNotEmpty) {
            final imageFile = File(media.localPath);
            if (await imageFile.exists()) {
              final imageBytes = await imageFile.readAsBytes();

              String folderPath =
                  _buildMediaFolderPath(media, topics, itemsCache, detailsCache);

              final fileName = media.filename;
              final archiveImageFile = ArchiveFile(
                  '$folderPath/$fileName', imageBytes.length, imageBytes);
              archive.addFile(archiveImageFile);
            }
          }
        } catch (e) {
          debugPrint('Erro ao adicionar imagem ${media.filename}: $e');
        }
      }

      // Gerar o arquivo ZIP
      final zipBytes = ZipEncoder().encode(archive);

      // SALVAMENTO EM DOWNLOADS
      // Estratégia: Tentar múltiplos caminhos para garantir salvamento em Downloads
      // Requer permissão MANAGE_EXTERNAL_STORAGE no AndroidManifest.xml
      Directory? directory;

      try {
        if (Platform.isAndroid) {
          // Tentar múltiplos caminhos possíveis da pasta Downloads no Android
          final downloadPaths = [
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Downloads',
            '/sdcard/Download',
            '/sdcard/Downloads',
          ];

          for (final path in downloadPaths) {
            final testDir = Directory(path);
            if (await testDir.exists()) {
              directory = testDir;
              debugPrint('Using Downloads directory: $path');
              break;
            }
          }

          // Se não conseguir Downloads, tentar criar na pasta externa
          if (directory == null) {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              // Criar pasta Downloads na pasta da aplicação
              directory = Directory('${externalDir.path}/Downloads');
              await directory.create(recursive: true);
              debugPrint(
                  'Created Downloads in external storage: ${directory.path}');
            }
          }

          // Fallback final para diretório interno
          if (directory == null || !await directory.exists()) {
            directory = await getApplicationDocumentsDirectory();
            debugPrint('Fallback to documents directory: ${directory.path}');
          }
        } else {
          // Para iOS - usar diretório de documentos
          directory = await getApplicationDocumentsDirectory();
          debugPrint('iOS documents directory: ${directory.path}');
        }
      } catch (e) {
        debugPrint('Erro ao acessar diretório Downloads: $e');
        // GARANTIR que sempre funcione - usar diretório interno
        directory = await getApplicationDocumentsDirectory();
        debugPrint('Emergency fallback directory: ${directory.path}');
      }

      // Criar pasta "Lince Inspeções" se não existir
      final linceDirectory = Directory('${directory.path}/Lince Inspeções');
      if (!await linceDirectory.exists()) {
        await linceDirectory.create(recursive: true);
      }

      // GARANTIR salvamento do arquivo ZIP
      final fileName =
          'inspecao_${inspection?.cod ?? 'export'}_${DateTime.now().millisecondsSinceEpoch}.zip';
      File? zipFile;

      try {
        zipFile = File('${linceDirectory.path}/$fileName');
        await zipFile.writeAsBytes(zipBytes);
        debugPrint('ZIP saved successfully at: ${zipFile.path}');
      } catch (e) {
        debugPrint('Error saving to primary location: $e');
        // FORÇAR salvamento em qualquer lugar possível
        final fallbackPaths = [
          '${directory.path}/$fileName',
          '${(await getApplicationDocumentsDirectory()).path}/$fileName',
          '${(await getTemporaryDirectory()).path}/$fileName',
        ];

        bool saved = false;
        for (final fallbackPath in fallbackPaths) {
          try {
            zipFile = File(fallbackPath);
            await zipFile.writeAsBytes(zipBytes);
            debugPrint('ZIP saved to fallback location: $fallbackPath');
            saved = true;
            break;
          } catch (fallbackError) {
            debugPrint('Fallback path failed: $fallbackPath - $fallbackError');
          }
        }

        if (!saved || zipFile == null) {
          throw Exception('Failed to save ZIP to any location');
        }
      }

      if (!(await zipFile.exists())) {
        throw Exception('Falha ao salvar o arquivo ZIP em um local válido.');
      }

      // Notificar o MediaScanner do Android para indexar o arquivo
      if (Platform.isAndroid) {
        try {
          // Usar o canal de método para notificar o MediaScanner
          // Isso tornará o arquivo visível imediatamente no gerenciador de arquivos
          final process = await Process.run('am', [
            'broadcast',
            '-a',
            'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
            '-d',
            'file://${zipFile.path}',
          ]);

          if (process.exitCode == 0) {
            debugPrint('MediaScanner notified successfully');
          } else {
            debugPrint('Failed to notify MediaScanner: ${process.stderr}');
          }
        } catch (e) {
          debugPrint('Error notifying MediaScanner: $e');
          // Não é crítico, continuar mesmo se falhar
        }
      }

      if (context.mounted) {
        // Extrair caminho simplificado para mostrar ao usuário
        final simplePath = zipFile.path.replaceAll('/storage/emulated/0/', '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exportação concluída com sucesso!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Local: $simplePath'),
                const SizedBox(height: 4),
                const Text(
                  'Use o compartilhamento abaixo ou acesse o Gerenciador de Arquivos',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Abre a bandeja de compartilhamento nativa com o arquivo.
        await Share.shareXFiles(
          [XFile(zipFile.path)],
          text: 'Inspeção exportada: ${inspection?.cod ?? 'Lince Inspeções'}',
        );
      }

      debugPrint(
          'Inspection exported successfully as ZIP: ${zipFile.path}');
      debugPrint(
          'ZIP contains organized JSON data, database backup, and ${allMedia.length} images');
    } catch (e) {
      debugPrint('Error exporting inspection: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar inspeção: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> _formatMediaForExport(dynamic media) {
    return {
      'filename': media.filename,
      'url': media.cloudUrl ?? '',
      'type': media.type ?? 'image',
      'created_at': media.createdAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
    };
  }

  String _sanitizeFileName(String fileName) {
    // Remove caracteres especiais e substitui por underscore
    return fileName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'[-\s]+'), '_')
        .trim();
  }

  String _buildMediaFolderPath(
    dynamic media,
    List<Topic> topics,
    Map<String, List<Item>> itemsCache,
    Map<String, List<Detail>> detailsCache,
  ) {
    // Handle non-conformity media separately
    if (media.nonConformityId != null) {
      return 'media/nao_conformidades';
    }

    // Find topic
    final topic = topics.firstWhere((t) => t.id == media.topicId,
        orElse: () => Topic(
              topicName: 'topico_nao_encontrado',
              inspectionId: media.inspectionId ?? '',
              position: 0,
            ));
    final sanitizedTopicName = _sanitizeFileName(topic.topicName);

    // Topic-level media
    if (media.itemId == null && media.detailId == null) {
      return 'media/01_topicos/$sanitizedTopicName';
    }

    // Detail-level media
    if (media.detailId != null) {
      if (topic.directDetails == true) {
        // Direct details - no item folder
        final detailsKey = '${media.topicId}_direct';
        final details = detailsCache[detailsKey] ?? [];
        final detail = details.where((d) => d.id == media.detailId).firstOrNull;
        final sanitizedDetailName =
            _sanitizeFileName(detail?.detailName ?? 'detalhe_nao_encontrado');
        return 'media/01_topicos/$sanitizedTopicName/03_detalhes/$sanitizedDetailName';
      } else {
        // Regular details under items
        final items = itemsCache[media.topicId] ?? [];
        final item = items.where((it) => it.id == media.itemId).firstOrNull;
        final sanitizedItemName =
            _sanitizeFileName(item?.itemName ?? 'item_nao_encontrado');

        final detailsKey = '${media.topicId}_${media.itemId}';
        final details = detailsCache[detailsKey] ?? [];
        final detail = details.where((d) => d.id == media.detailId).firstOrNull;
        final sanitizedDetailName =
            _sanitizeFileName(detail?.detailName ?? 'detalhe_nao_encontrado');

        return 'media/01_topicos/$sanitizedTopicName/02_itens/$sanitizedItemName/03_detalhes/$sanitizedDetailName';
      }
    }

    // Item-level media
    if (media.itemId != null) {
      final items = itemsCache[media.topicId] ?? [];
      final item = items.where((it) => it.id == media.itemId).firstOrNull;
      final sanitizedItemName =
          _sanitizeFileName(item?.itemName ?? 'item_nao_encontrado');
      return 'media/01_topicos/$sanitizedTopicName/02_itens/$sanitizedItemName';
    }

    // Fallback
    return 'media/01_topicos/$sanitizedTopicName';
  }
}
