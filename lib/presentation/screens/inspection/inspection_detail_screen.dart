// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/hierarchical_inspection_view.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/empty_topic_state.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/loading_state.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/offline_template_topic_selector_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/inspection_info_dialog.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/sync/sync_progress_overlay.dart';
import 'package:lince_inspecoes/services/navigation_state_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> with WidgetsBindingObserver {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  bool _isLoading = true;
  final bool _isSyncing = false;
  final bool _isApplyingTemplate = false;
  bool _isAvailableOffline =
      false; // Track if inspection is fully available offline
  bool _canEdit =
      false; // Track if user can edit (based on offline availability)
  Inspection? _inspection;
  List<Topic> _topics = [];
  final Map<String, List<Item>> _itemsCache = {};
  final Map<String, List<Detail>> _detailsCache = {};
  double? _cachedProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Marca nova sessão apenas no initState (primeira vez que abre)
    NavigationStateService.markNewSession();
    _listenToConnectivity();
    _loadInspection();
    // Limpa estados de navegação antigos em background
    NavigationStateService.cleanupOldStates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('InspectionDetailScreen: App resumed - navigation state restoration controlled by session');
        break;
      case AppLifecycleState.paused:
        debugPrint('InspectionDetailScreen: App paused - navigation state will be preserved');
        break;
      case AppLifecycleState.detached:
        // App está sendo completamente fechado
        debugPrint('InspectionDetailScreen: App detached - preparing for session reset');
        NavigationStateService.markNewSession();
        break;
      case AppLifecycleState.inactive:
        debugPrint('InspectionDetailScreen: App inactive (notification panel, etc.)');
        break;
      case AppLifecycleState.hidden:
        debugPrint('InspectionDetailScreen: App hidden');
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Limpar overlay ao sair da tela
    SyncProgressOverlay.hide();
    // Sincronizar ao sair da tela
    _syncOnExit();
    super.dispose();
  }

  Future<void> _syncOnExit() async {
    // OFFLINE-FIRST: Never auto-sync on exit
    // Users must manually sync when they want to upload changes
    debugPrint(
        'InspectionDetailScreen: Exiting without auto-sync (offline-first mode)');
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (mounted) {
        // Network status updated (removed _isOnline field)

        // OFFLINE-FIRST: Don't automatically apply templates when coming online
        // Templates should be applied only through manual user action
      }
    });

    Connectivity().checkConnectivity().then((connectivityResult) {
      if (mounted) {
        // Initial connectivity check (removed _isOnline field)
      }
    });
  }

  Future<void> _loadInspection() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Check if inspection is fully downloaded
      final inspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      _isAvailableOffline = inspection != null;
      _canEdit = _isAvailableOffline;

      if (_isAvailableOffline) {
        // Load from offline storage (OFFLINE-FIRST)
        final offlineInspection = await _serviceFactory.dataService
            .getInspection(widget.inspectionId);
        if (offlineInspection != null) {
          setState(() {
            _inspection = offlineInspection;
          });

          // Marcar como "em progresso" apenas se estiver pending
          if (offlineInspection.status == 'pending') {
            await _markAsInProgress();
          }

          await _loadAllData();
        } else {
          _showErrorSnackBar('Erro ao carregar inspeção offline.');
        }
      } else {
        // Inspection not downloaded - show download dialog
        _showOfflineRequiredDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAllData() async {
    if (_inspection?.id == null) return;

    try {
      // Always load topics (especially after adding new ones)
      final topics = await _serviceFactory.dataService.getTopics(widget.inspectionId);
      

      // Load items and details for all topics
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = topics[topicIndex];
        final topicId = topic.id ?? 'topic_$topicIndex';
        
        // Always reload to ensure we have the latest data
        if (topic.directDetails == true) {
          final directDetails = await _serviceFactory.dataService.getDirectDetails(topicId);
          _detailsCache['${topicId}_direct'] = directDetails;
          _itemsCache[topicId] = [];
        } else {
          final items = await _serviceFactory.dataService.getItems(topicId);
          _itemsCache[topicId] = items;

          for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
            final item = items[itemIndex];
            final itemId = item.id ?? 'item_$itemIndex';
            final details = await _serviceFactory.dataService.getDetails(itemId);
            _detailsCache['${topicId}_$itemId'] = details;
          }
        }
      }

      if (mounted) {
        setState(() {
          _topics = topics;
        });
      }
    } catch (e) {
      debugPrint('InspectionDetailScreen: Error loading data: $e');
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar dados: $e');
      }
    }
  }



  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showOfflineRequiredDialog() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Necessário'),
            content: const Text(
                'Esta inspeção está apenas parcialmente disponível. Para editar, '
                'você precisa baixar todos os dados e mídias. Deseja baixar agora?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Also close inspection screen
                },
                child: const Text('Voltar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _downloadInspectionForOffline();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F4B99),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Baixar'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _downloadInspectionForOffline() async {
    if (!mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _OfflineDownloadDialog(inspectionId: widget.inspectionId),
    );

    try {
      await _serviceFactory.syncService.syncInspection(widget.inspectionId);

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      setState(() {
        _isAvailableOffline = true;
        _canEdit = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Inspeção baixada com sucesso! Agora você pode editá-la offline.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload inspection from offline storage
      await _loadInspection();
    } catch (e) {
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar inspeção: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Removed _convertDateTimesToTimestamps - handled by cache service now

  Future<void> _addTopic() async {
    // Check if user can edit
    if (!_canEdit) {
      _showOfflineRequiredDialog();
      return;
    }

    // Use offline-capable dialog that works with cached templates
    final result = await showDialog<Topic>(
      context: context,
      builder: (context) => OfflineTemplateTopicSelectorDialog(
        inspectionId: widget.inspectionId,
        templateId: _inspection?.templateId,
      ),
    );

    if (result == null || !mounted) return;

    try {
      // Limpar caches para forçar recarregamento
      _itemsCache.clear();
      _detailsCache.clear();
      _topics.clear();
      _invalidateProgressCache();

      // Adicionar o tópico à estrutura aninhada da inspeção
      await _addTopicToNestedStructure(result);

      await _markAsModified();

      // Reload data to ensure consistency and show new topic immediately
      await _loadAllData();

      if (mounted) {
        setState(() {}); // Trigger UI update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tópico "${result.topicName}" adicionado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar tópico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addTopicToNestedStructure(Topic topic) async {
    if (_inspection == null) return;

    try {
      // Verificar se o tópico tem ID válido, se não tiver, buscar por position
      String? topicId = topic.id;
      if (topicId == null) {
        debugPrint('InspectionDetailScreen: Topic ID is null, searching by position ${topic.position}');
        // Buscar o tópico recém-criado pelo position
        final allTopics = await _serviceFactory.dataService.getTopics(widget.inspectionId);
        final matchingTopic = allTopics.where((t) => t.position == topic.position && t.topicName == topic.topicName).firstOrNull;
        if (matchingTopic?.id != null) {
          topicId = matchingTopic!.id;
          debugPrint('InspectionDetailScreen: Found topic by position with ID: $topicId');
        } else {
          debugPrint('InspectionDetailScreen: Could not find topic by position, cannot add to nested structure');
          return;
        }
      }
      
      // Buscar itens criados para este tópico usando o topicId encontrado
      final items = await _serviceFactory.dataService.getItems(topicId!);
      
      // Verificar se é um tópico com direct_details
      final bool hasDirectDetails = topic.directDetails == true;
      
      // Criar estrutura do tópico baseada no tipo
      Map<String, dynamic> topicData;
      
      if (hasDirectDetails) {
        // Para tópicos com direct_details, buscar detalhes diretos
        final directDetails = await _serviceFactory.dataService.getDirectDetails(topicId);
        
        final List<Map<String, dynamic>> detailsData = [];
        for (final detail in directDetails) {
          try {
            detailsData.add({
              'name': detail.detailName,
              'value': detail.detailValue ?? '',
              'type': detail.type ?? 'text',
              'options': detail.options ?? [],
              'required': detail.isRequired ?? false,
              'observation': detail.observation ?? '',
              'media': [],
              'non_conformities': [],
            });
          } catch (e) {
            debugPrint('InspectionDetailScreen: Error processing direct detail ${detail.id}: $e');
          }
        }
        
        topicData = {
          'name': topic.topicName,
          'description': topic.topicLabel ?? '',
          'observation': topic.observation ?? '',
          'direct_details': true,
          'details': detailsData,
          'media': [],
          'non_conformities': [],
        };
      } else {
        // Para tópicos normais, processar itens
        final List<Map<String, dynamic>> itemsData = [];
        for (final item in items) {
          if (item.id == null) {
            debugPrint('InspectionDetailScreen: Item ID is null, skipping item');
            continue;
          }
          
          final details = await _serviceFactory.dataService.getDetails(item.id!);
          
          final List<Map<String, dynamic>> detailsData = [];
          for (final detail in details) {
            try {
              detailsData.add({
                'name': detail.detailName,
                'value': detail.detailValue ?? '',
                'type': detail.type ?? 'text',
                'options': detail.options ?? [],
                'required': detail.isRequired ?? false,
                'observation': detail.observation ?? '',
                'media': [],
                'non_conformities': [],
              });
            } catch (e) {
              debugPrint('InspectionDetailScreen: Error processing detail ${detail.id}: $e');
            }
          }
          
          itemsData.add({
            'name': item.itemName,
            'description': item.itemLabel ?? '',
            'observation': item.observation ?? '',
            'evaluable': item.evaluable ?? false,
            'evaluation_options': item.evaluationOptions ?? [],
            'evaluation_value': item.evaluationValue,
            'details': detailsData,
            'media': [],
            'non_conformities': [],
          });
        }
        
        topicData = {
          'name': topic.topicName,
          'description': topic.topicLabel ?? '',
          'observation': topic.observation ?? '',
          'direct_details': false,
          'items': itemsData,
          'media': [],
          'non_conformities': [],
        };
      }
      

      // Obter os topics atuais da inspeção
      final currentTopics =
          List<Map<String, dynamic>>.from(_inspection!.topics ?? []);

      // Adicionar o novo tópico
      currentTopics.add(topicData);

      // Atualizar a inspeção com a nova estrutura
      final updatedInspection = _inspection!.copyWith(topics: currentTopics);

      try {
        // Atualizar no banco local (não inserir novamente)
        await _serviceFactory.dataService.updateInspection(updatedInspection);
      } catch (e) {
        debugPrint('InspectionDetailScreen: Error updating inspection: $e');
        rethrow;
      }

      // OFFLINE-FIRST: Don't auto-sync when adding topics
      // User must manually sync when they want to upload changes

      // Atualizar o estado local
      _inspection = updatedInspection;

      debugPrint(
          'InspectionDetailScreen: Added topic to nested structure successfully');
    } catch (e) {
      debugPrint(
          'InspectionDetailScreen: Error adding topic to nested structure: $e');
      rethrow;
    }
  }

  Future<void> _markAsInProgress() async {
    try {
      // Verificar se ainda está pending antes de atualizar
      final currentInspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (currentInspection?.status == 'pending') {
        await _serviceFactory.dataService
            .updateInspectionStatus(widget.inspectionId, 'in_progress');
        debugPrint(
            'InspectionDetailScreen: Marked inspection ${widget.inspectionId} as in progress');
      } else {
        debugPrint(
            'InspectionDetailScreen: Inspection ${widget.inspectionId} is already ${currentInspection?.status}, not changing to in_progress');
      }
    } catch (e) {
      debugPrint(
          'InspectionDetailScreen: Error marking inspection as in progress: $e');
    }
  }

  Future<void> _markAsModified() async {
    try {
      await _serviceFactory.dataService
          .updateInspectionStatus(widget.inspectionId, 'modified');
      debugPrint(
          'InspectionDetailScreen: Marked inspection ${widget.inspectionId} as modified');
    } catch (e) {
      debugPrint(
          'InspectionDetailScreen: Error marking inspection as modified: $e');
    }
  }

  Future<void> _updateCache() async {
    await _markAsModified();
    _invalidateProgressCache();
    
    // Force reload data to show duplicated items/topics/details
    _itemsCache.clear();
    _detailsCache.clear();
    _topics.clear();
    
    await _loadAllData();
    
    if (mounted) {
      setState(() {});
    }
  }

  double _calculateInspectionProgress() {
    if (_cachedProgress != null) return _cachedProgress!;
    
    if (_topics.isEmpty) return 0.0;
    
    int totalUnits = 0;
    int completedUnits = 0;
    
    for (final topic in _topics) {
      final topicId = topic.id ?? 'topic_${_topics.indexOf(topic)}';
      
      if (topic.directDetails == true) {
        final directDetailsKey = '${topicId}_direct';
        final details = _detailsCache[directDetailsKey] ?? [];
        
        for (final detail in details) {
          totalUnits++;
          if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
            completedUnits++;
          }
        }
      } else {
        final items = _itemsCache[topicId] ?? [];
        
        for (final item in items) {
          final itemId = item.id ?? 'item_${items.indexOf(item)}';
          
          if (item.evaluable == true) {
            totalUnits++;
            if (item.evaluationValue != null && item.evaluationValue!.isNotEmpty) {
              completedUnits++;
            }
          }
          
          final details = _detailsCache['${topicId}_$itemId'] ?? [];
          for (final detail in details) {
            totalUnits++;
            if (detail.detailValue != null && detail.detailValue!.isNotEmpty) {
              completedUnits++;
            }
          }
        }
      }
    }
    
    _cachedProgress = totalUnits > 0 ? completedUnits / totalUnits : 0.0;
    return _cachedProgress!;
  }

  void _invalidateProgressCache() {
    _cachedProgress = null;
  }


  Map<String, dynamic> _formatMediaForExport(dynamic media) {
    return {
      'filename': media.filename,
      'url': media.cloudUrl ?? '',
      'type': media.type ?? 'image',
      'created_at': media.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  String _sanitizeFileName(String fileName) {
    // Remove caracteres especiais e substitui por underscore
    return fileName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'[-\s]+'), '_')
        .trim();
  }

  Future<void> _exportInspection() async {
    if (!mounted) return;

    try {
      // Create cloud-sync format inspection data
      final Map<String, dynamic> inspectionData = _inspection?.toMap() ?? {};
      
      // Remove ALL local-only fields to match cloud format exactly
      final fieldsToRemove = [
        'id', 'needs_sync', 'is_deleted', 'has_local_changes', 
        'is_synced', 'last_sync_at', 'sync_history', 'local_id'
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
      final sortedTopics = List<Topic>.from(_topics);
      sortedTopics.sort((a, b) => a.position.compareTo(b.position));
      
      for (final topic in sortedTopics) {
        final topicId = topic.id ?? 'topic_${sortedTopics.indexOf(topic)}';
        
        Map<String, dynamic> topicData;
        if (topic.directDetails == true) {
          // Direct details topic
          final directDetails = _detailsCache['${topicId}_direct'] ?? [];
          final sortedDetails = List.from(directDetails);
          sortedDetails.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
          
          final List<Map<String, dynamic>> detailsData = [];
          
          for (final detail in sortedDetails) {
            final detailMedia = await _serviceFactory.mediaService.getMediaByContext(detailId: detail.id);
            final detailNCs = await _serviceFactory.dataService.getNonConformitiesByDetail(detail.id ?? '');
            
            detailsData.add({
              'name': detail.detailName,
              'type': detail.type ?? 'text',
              'required': detail.isRequired ?? false,
              'options': detail.options ?? [],
              'value': detail.detailValue,
              'observation': detail.observation,
              'is_damaged': false,
              'media': detailMedia.map((media) => _formatMediaForExport(media)).toList(),
              'non_conformities': detailNCs.map((nc) => nc.toMap()).toList(),
            });
          }
          
          final topicMedia = await _serviceFactory.mediaService.getMediaByContext(topicId: topicId);
          final topicNCs = await _serviceFactory.dataService.getNonConformitiesByTopic(topicId);
          
          topicData = {
            'name': topic.topicName,
            'description': topic.topicLabel,
            'observation': topic.observation,
            'direct_details': true,
            'details': detailsData,
            'media': topicMedia.map((media) => _formatMediaForExport(media)).toList(),
            'non_conformities': topicNCs.map((nc) => nc.toMap()).toList(),
          };
        } else {
          // Regular topic with items
          final items = _itemsCache[topicId] ?? [];
          final sortedItems = List.from(items);
          sortedItems.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
          
          final List<Map<String, dynamic>> itemsData = [];
          
          for (final item in sortedItems) {
            final itemId = item.id ?? 'item_${sortedItems.indexOf(item)}';
            final details = _detailsCache['${topicId}_$itemId'] ?? [];
            final sortedDetails = List.from(details);
            sortedDetails.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
            
            final List<Map<String, dynamic>> detailsData = [];
            
            for (final detail in sortedDetails) {
              final detailMedia = await _serviceFactory.mediaService.getMediaByContext(detailId: detail.id);
              final detailNCs = await _serviceFactory.dataService.getNonConformitiesByDetail(detail.id ?? '');
              
              detailsData.add({
                'name': detail.detailName,
                'type': detail.type ?? 'text',
                'required': detail.isRequired ?? false,
                'options': detail.options ?? [],
                'value': detail.detailValue,
                'observation': detail.observation,
                'is_damaged': false,
                'media': detailMedia.map((media) => _formatMediaForExport(media)).toList(),
                'non_conformities': detailNCs.map((nc) => nc.toMap()).toList(),
              });
            }
            
            final itemMedia = await _serviceFactory.mediaService.getMediaByContext(itemId: itemId);
            final itemNCs = await _serviceFactory.dataService.getNonConformitiesByItem(itemId);
            
            itemsData.add({
              'name': item.itemName,
              'description': item.itemLabel,
              'observation': item.observation,
              'evaluable': item.evaluable ?? false,
              'evaluation_options': item.evaluationOptions ?? [],
              'evaluation_value': item.evaluationValue,
              'details': detailsData,
              'media': itemMedia.map((media) => _formatMediaForExport(media)).toList(),
              'non_conformities': itemNCs.map((nc) => nc.toMap()).toList(),
            });
          }
          
          final topicMedia = await _serviceFactory.mediaService.getMediaByContext(topicId: topicId);
          final topicNCs = await _serviceFactory.dataService.getNonConformitiesByTopic(topicId);
          
          topicData = {
            'name': topic.topicName,
            'description': topic.topicLabel,
            'observation': topic.observation,
            'direct_details': false,
            'items': itemsData,
            'media': topicMedia.map((media) => _formatMediaForExport(media)).toList(),
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
      final jsonFile = ArchiveFile('inspection.json', jsonBytes.length, jsonBytes);
      archive.addFile(jsonFile);

      // NOVA FUNCIONALIDADE: Adicionar arquivo .db do SQLite
      try {
        final dbPath = path.join(await getDatabasesPath(), 'inspection_offline.db');
        final dbFile = File(dbPath);

        if (await dbFile.exists()) {
          final dbBytes = await dbFile.readAsBytes();
          final dbArchiveFile = ArchiveFile('database/inspection_offline.db', dbBytes.length, dbBytes);
          archive.addFile(dbArchiveFile);
          debugPrint('Database file added to export: ${dbBytes.length} bytes');
        } else {
          debugPrint('Database file not found at: $dbPath');
          // Forçar criação de backup mesmo sem DB
          final backupInfo = {
            'message': 'Database backup not available - using JSON export only',
            'timestamp': DateTime.now().toIso8601String(),
            'inspection_id': widget.inspectionId,
          };
          final backupBytes = utf8.encode(jsonEncode(backupInfo));
          final backupFile = ArchiveFile('database/backup_info.json', backupBytes.length, backupBytes);
          archive.addFile(backupFile);
        }
      } catch (e) {
        debugPrint('Error adding database to export: $e');
        // Garantir que sempre tenha algo mesmo com erro
        final errorInfo = {
          'error': 'Failed to backup database: $e',
          'timestamp': DateTime.now().toIso8601String(),
          'inspection_id': widget.inspectionId,
          'fallback': 'Using JSON export as primary backup'
        };
        final errorBytes = utf8.encode(jsonEncode(errorInfo));
        final errorFile = ArchiveFile('database/error_log.json', errorBytes.length, errorBytes);
        archive.addFile(errorFile);
      }

      // Collect and organize all media files with proper structure
      final allMedia = await _serviceFactory.mediaService.getMediaByInspection(widget.inspectionId);
      
      // Build organized folder structure for media
      for (final media in allMedia) {
        try {
          if (media.localPath.isNotEmpty) {
            final imageFile = File(media.localPath);
            if (await imageFile.exists()) {
              final imageBytes = await imageFile.readAsBytes();
              
              String folderPath = _buildMediaFolderPath(media);
              
              final fileName = media.filename;
              final archiveImageFile = ArchiveFile('$folderPath/$fileName', imageBytes.length, imageBytes);
              archive.addFile(archiveImageFile);
            }
          }
        } catch (e) {
          debugPrint('Erro ao adicionar imagem ${media.filename}: $e');
        }
      }

      // Gerar o arquivo ZIP
      final zipBytes = ZipEncoder().encode(archive);

      // MODIFICADO: Forçar salvamento na pasta Downloads
      Directory? directory;

      try {
        if (Platform.isAndroid) {
          // FORÇAR Downloads - tentar múltiplos caminhos
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
              debugPrint('Created Downloads in external storage: ${directory.path}');
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
      final fileName = 'inspecao_${_inspection?.cod ?? 'export'}_${DateTime.now().millisecondsSinceEpoch}.zip';
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inspeção exportada como ZIP!'),
                const SizedBox(height: 4),
                Text(
                  'Local: ${zipFile?.path ?? 'Erro ao obter caminho'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'ABRIR',
              textColor: Colors.white,
              onPressed: () => _openExportedFile(zipFile?.path ?? ''),
            ),
          ),
        );
      }

      debugPrint('Inspection exported successfully as ZIP: ${zipFile?.path ?? 'unknown path'}');
      debugPrint('ZIP contains organized JSON data, database backup, and ${allMedia.length} images');

    } catch (e) {
      debugPrint('Error exporting inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar inspeção: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _buildMediaFolderPath(dynamic media) {
    // Handle non-conformity media separately
    if (media.nonConformityId != null) {
      return 'media/nao_conformidades';
    }
    
    // Find topic
    final topic = _topics.firstWhere(
      (t) => t.id == media.topicId, 
      orElse: () => Topic(
        topicName: 'topico_nao_encontrado',
        inspectionId: widget.inspectionId,
        position: 0,
      )
    );
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
        final details = _detailsCache[detailsKey] ?? [];
        final detail = details.where((d) => d.id == media.detailId).firstOrNull;
        final sanitizedDetailName = _sanitizeFileName(detail?.detailName ?? 'detalhe_nao_encontrado');
        return 'media/01_topicos/$sanitizedTopicName/03_detalhes/$sanitizedDetailName';
      } else {
        // Regular details under items
        final items = _itemsCache[media.topicId] ?? [];
        final item = items.where((it) => it.id == media.itemId).firstOrNull;
        final sanitizedItemName = _sanitizeFileName(item?.itemName ?? 'item_nao_encontrado');
        
        final detailsKey = '${media.topicId}_${media.itemId}';
        final details = _detailsCache[detailsKey] ?? [];
        final detail = details.where((d) => d.id == media.detailId).firstOrNull;
        final sanitizedDetailName = _sanitizeFileName(detail?.detailName ?? 'detalhe_nao_encontrado');
        
        return 'media/01_topicos/$sanitizedTopicName/02_itens/$sanitizedItemName/03_detalhes/$sanitizedDetailName';
      }
    }
    
    // Item-level media
    if (media.itemId != null) {
      final items = _itemsCache[media.topicId] ?? [];
      final item = items.where((it) => it.id == media.itemId).firstOrNull;
      final sanitizedItemName = _sanitizeFileName(item?.itemName ?? 'item_nao_encontrado');
      return 'media/01_topicos/$sanitizedTopicName/02_itens/$sanitizedItemName';
    }
    
    // Fallback
    return 'media/01_topicos/$sanitizedTopicName';
  }

  Future<void> _openExportedFile(String filePath) async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivo Exportado com Sucesso!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text('O arquivo ZIP foi salvo em:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Você pode compartilhar o arquivo ou encontrá-lo no gerenciador de arquivos.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              try {
                await Share.shareXFiles(
                  [XFile(filePath)],
                  text: 'Inspeção exportada - ${_inspection?.cod ?? 'Lince Inspeções'}',
                );
              } catch (e) {
                debugPrint('Erro ao compartilhar arquivo: $e');
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Erro ao compartilhar: $e'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartilhar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6F4B99),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importInspection() async {
    if (!mounted) return;

    try {
      // Criar um diálogo de seleção de arquivo
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importar Inspeção'),
          content: const Text(
              'Esta funcionalidade permite importar uma inspeção exportada anteriormente.\n\nDeseja continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Importar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Implementar importação usando createInspectionFromJson
      await _importFromVistoriaFlexivel();

    } catch (e) {
      debugPrint('Error importing inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar inspeção: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importFromVistoriaFlexivel() async {
    if (!mounted) return;

    try {
      // Dados do Vistoria_Flexivel.json
      const vistoriaFlexivelData = {
        "title": "Flexível",
        "observation": null,
        "project_id": "DQOFavelUHcuwdEuPE4I",
        "template_id": "KrzoTXUdv1yRcYDWBND2",
        "inspector_id": "bSTmE0Ix6WbBMueqvZWfpKc3Ngy2",
        "status": "pending",
        "address": {
          "cep": "88062110",
          "street": "Rua Crisógono Vieira da Cruz",
          "number": "233",
          "complement": "",
          "neighborhood": "Lagoa da Conceição",
          "city": "Florianópolis",
          "state": "SC"
        },
        "address_string": "Rua Crisógono Vieira da Cruz, 233, Lagoa da Conceição, Florianópolis - SC",
        "is_templated": true,
        "area": "0",
        "topics": [
          {
            "name": "Novo Tópico 1",
            "description": null,
            "observation": null,
            "direct_details": false,
            "items": [
              {
                "name": "Novo Item 1",
                "description": null,
                "observation": null,
                "evaluable": true,
                "evaluation_options": ["a", "b", "c"],
                "evaluation_value": null,
                "details": [
                  {
                    "name": "Novo Detalhe 1",
                    "type": "text",
                    "required": false,
                    "options": [],
                    "value": null,
                    "observation": null,
                    "is_damaged": false,
                    "media": [],
                    "non_conformities": []
                  }
                ]
              }
            ]
          },
          {
            "name": "Novo Tópico 2",
            "description": null,
            "observation": null,
            "direct_details": true,
            "details": [
              {
                "name": "Novo Detalhe 1",
                "type": "select",
                "required": false,
                "options": ["a", "b", "c"],
                "value": null,
                "observation": null,
                "is_damaged": false,
                "media": [],
                "non_conformities": []
              }
            ]
          },
          {
            "name": "Novo Tópico 3",
            "description": null,
            "observation": null,
            "direct_details": true,
            "details": [
              {
                "name": "Novo Detalhe 1",
                "type": "boolean",
                "required": false,
                "options": [],
                "value": null,
                "observation": null,
                "is_damaged": false,
                "media": [],
                "non_conformities": []
              }
            ]
          }
        ],
        "cod": "INSP250715-001.TP0004",
        "deleted_at": null,
        "updated_at": {
          "_seconds": 1752625367,
          "_nanoseconds": 469000000
        },
        "created_at": {
          "_seconds": 1752625367,
          "_nanoseconds": 469000000
        }
      };

      // Usar o serviço de dados para processar a estrutura aninhada
      await _serviceFactory.dataService.createInspectionFromJson(vistoriaFlexivelData);

      // Recarregar a inspeção após importação
      await _loadInspection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vistoria_Flexivel.json importado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      debugPrint('Error importing Vistoria_Flexivel.json: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
        ),
      ),
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    if (!mounted) return;

    switch (value) {
      case 'import':
        await _importInspection();
        break;
      case 'export':
        await _exportInspection();
        break;
      case 'nonConformities':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NonConformityScreen(
              inspectionId: widget.inspectionId,
              initialTabIndex: 1, // Ir direto para a aba de listagem
            ),
          ),
        );
        break;
      case 'media':
        _navigateToMediaGallery();
        break;
      case 'refresh':
        await _loadInspection();
        break;
      case 'info':
        if (_inspection != null) {
          final inspectionId = _inspection!.id;
          int totalTopics = _topics.length;
          int totalItems = 0;
          int totalDetails = 0;
          int totalMedia = 0;

          for (final topic in _topics) {
            if (!mounted) return;
            final topicId = topic.id ?? 'topic_${_topics.indexOf(topic)}';
            final items = _itemsCache[topicId] ?? [];
            totalItems += items.length;
            for (final item in items) {
              if (!mounted) return;
              final itemId = item.id ?? 'item_${items.indexOf(item)}';
              final details = _detailsCache['${topicId}_$itemId'] ?? [];
              totalDetails += details.length;
            }
          }

          if (!mounted) return;
          final allMedia = await _serviceFactory.mediaService
              .getMediaByInspection(inspectionId);
          totalMedia = allMedia.length;

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => InspectionInfoDialog(
                inspection: _inspection!,
                totalTopics: totalTopics,
                totalItems: totalItems,
                totalDetails: totalDetails,
                totalMedia: totalMedia,
              ),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _inspection?.cod ?? 'Inspeção',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isLoading && _topics.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      child: LinearProgressIndicator(
                        value: _calculateInspectionProgress(),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _calculateInspectionProgress() >= 1.0 
                            ? Colors.green 
                            : Colors.white,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isSyncing || _isApplyingTemplate)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          if (!(_isSyncing || _isApplyingTemplate))
            PopupMenuButton<String>(
              padding: const EdgeInsets.all(5),
              icon: const Icon(Icons.more_vert, size: 22),
              onSelected: _handleMenuSelection,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload),
                      SizedBox(width: 8),
                      Text('Importar Inspeção'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('Exportar Inspeção'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('Informações'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Conteúdo principal
          Expanded(
            child: _isLoading
                ? LoadingState(
                    isDownloading: false,
                    isApplyingTemplate: _isApplyingTemplate)
                : _topics.isEmpty
                    ? EmptyTopicState(onAddTopic: _addTopic)
                    : HierarchicalInspectionView(
                        inspectionId: widget.inspectionId,
                        topics: _topics,
                        itemsCache: _itemsCache,
                        detailsCache: _detailsCache,
                        onUpdateCache: _updateCache,
                      ),
          ),

          // Barra inferior
          if (keyboardHeight == 0 && !_isLoading && _topics.isNotEmpty)
            Container(
              padding: EdgeInsets.only(
                top: 4,
                bottom: bottomPadding + 4,
                left: 8,
                right: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF312456),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShortcutButton(
                    icon: Icons.photo_library,
                    label: 'Galeria',
                    onTap: _navigateToMediaGallery,
                    color: Colors.purple,
                  ),
                  _buildShortcutButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'NCs',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NonConformityScreen(
                            inspectionId: widget.inspectionId,
                            initialTabIndex: 1, // Ir direto para a aba de listagem
                          ),
                        ),
                      );
                    },
                    color: Colors.red,
                  ),
                  _buildShortcutButton(
                    icon: Icons.add_circle_outline,
                    label: '+ Tópico',
                    onTap: _canEdit
                        ? _addTopic
                        : () => _showOfflineRequiredDialog(),
                    color: _canEdit ? Color(0xFF6F4B99) : Colors.grey,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.08).round()),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineDownloadDialog extends StatefulWidget {
  final String inspectionId;

  const _OfflineDownloadDialog({required this.inspectionId});

  @override
  State<_OfflineDownloadDialog> createState() => _OfflineDownloadDialogState();
}

class _OfflineDownloadDialogState extends State<_OfflineDownloadDialog> {
  final double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // No download progress listener needed for offline-first architecture
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Baixando Inspeção'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Baixando todos os dados e mídias...'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toInt()}%'),
          if (_progress > 0.2 && _progress < 1.0) ...[
            const SizedBox(height: 8),
            const Text(
              'Baixando mídias...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
