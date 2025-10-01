// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/hierarchical_inspection_view.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/empty_topic_state.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/loading_state.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/template_selector_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/inspection_info_dialog.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/sync/sync_progress_overlay.dart';
import 'package:lince_inspecoes/services/utils/inspection_export_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen>
    with WidgetsBindingObserver {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  final InspectionExportService _exportService = InspectionExportService();

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
    _listenToConnectivity();
    _loadInspection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('InspectionDetailScreen: App resumed');
        break;
      case AppLifecycleState.paused:
        debugPrint('InspectionDetailScreen: App paused');
        break;
      case AppLifecycleState.detached:
        debugPrint('InspectionDetailScreen: App detached');
        break;
      case AppLifecycleState.inactive:
        debugPrint(
            'InspectionDetailScreen: App inactive (notification panel, etc.)');
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
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);

      // Load items and details for all topics
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = topics[topicIndex];
        final topicId = topic.id ?? 'topic_$topicIndex';

        // Always reload to ensure we have the latest data
        if (topic.directDetails == true) {
          final directDetails =
              await _serviceFactory.dataService.getDirectDetails(topicId);
          _detailsCache['${topicId}_direct'] = directDetails;
          _itemsCache[topicId] = [];
        } else {
          final items = await _serviceFactory.dataService.getItems(topicId);
          _itemsCache[topicId] = items;

          for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
            final item = items[itemIndex];
            final itemId = item.id ?? 'item_$itemIndex';
            final details =
                await _serviceFactory.dataService.getDetails(itemId);
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

    // Use unified template dialog for topics
    final result = await showDialog<Topic>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Adicionar Tópico',
        type: 'topic',
        parentName: '',
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

      // Topic already saved to Hive by TopicService - no need for nested JSON structure

      // Reload data to ensure consistency and show new topic immediately
      await _loadAllData();

      if (mounted) {
        setState(() {}); // Trigger UI update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Tópico "${result.topicName}" adicionado com sucesso'),
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

  // Method removed - topics are now stored directly in Hive boxes by TopicService

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

  Future<void> _updateCache() async {
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
            if (item.evaluationValue != null &&
                item.evaluationValue!.isNotEmpty) {
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

  Future<void> _exportInspection() async {
    if (!mounted) return;

    await _exportService.exportInspection(
      context: context,
      inspectionId: widget.inspectionId,
      inspection: _inspection,
      topics: _topics,
      itemsCache: _itemsCache,
      detailsCache: _detailsCache,
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
        "address_string":
            "Rua Crisógono Vieira da Cruz, 233, Lagoa da Conceição, Florianópolis - SC",
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
        "updated_at": {"_seconds": 1752625367, "_nanoseconds": 469000000},
        "created_at": {"_seconds": 1752625367, "_nanoseconds": 469000000}
      };

      // Usar o serviço de dados para processar a estrutura aninhada
      await _serviceFactory.dataService
          .createInspectionFromJson(vistoriaFlexivelData);

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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

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
                        color: theme.colorScheme.onSurface
                            .withAlpha((0.3 * 255).round()),
                      ),
                      child: LinearProgressIndicator(
                        value: _calculateInspectionProgress(),
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _calculateInspectionProgress() >= 1.0
                              ? Colors.green
                              : theme.colorScheme.onSurface,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
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

        ],
      ),
      bottomNavigationBar: keyboardHeight == 0 && !_isLoading && _topics.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: BottomNavigationBar(
                  currentIndex: 0, // Usar um item válido sem destaque visual especial
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: theme.unselectedWidgetColor, // Mesma cor para todos
                  unselectedItemColor: theme.unselectedWidgetColor,
                  selectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                  showUnselectedLabels: true,
                  onTap: (index) {
                    switch (index) {
                      case 0:
                        _navigateToMediaGallery();
                        break;
                      case 1:
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NonConformityScreen(
                              inspectionId: widget.inspectionId,
                              initialTabIndex: 1,
                            ),
                          ),
                        );
                        break;
                      case 2:
                        if (_canEdit) {
                          _addTopic();
                        } else {
                          _showOfflineRequiredDialog();
                        }
                        break;
                    }
                  },
                  items: [
                    BottomNavigationBarItem(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.photo_library),
                      ),
                      label: 'Galeria',
                    ),
                    BottomNavigationBarItem(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.warning_amber_rounded),
                      ),
                      label: 'NCs',
                    ),
                    BottomNavigationBarItem(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.add_circle_outline),
                      ),
                      label: '+ Tópico',
                    ),
                  ],
                ),
              ),
            )
          : null,
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
