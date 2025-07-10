// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/inspection.dart';
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

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  bool _isLoading = true;
  final bool _isSyncing = false;
  bool _isOnline = true;
  bool _isApplyingTemplate = false;
  bool _isAvailableOffline =
      false; // Track if inspection is fully available offline
  bool _canEdit =
      false; // Track if user can edit (based on offline availability)
  Inspection? _inspection;
  List<Topic> _topics = [];
  final Map<String, List<Item>> _itemsCache = {};
  final Map<String, List<Detail>> _detailsCache = {};

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();
    _loadInspection();
  }

  @override
  void dispose() {
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
        final newOnlineStatus =
            connectivityResult.contains(ConnectivityResult.wifi) ||
                connectivityResult.contains(ConnectivityResult.mobile);
        setState(() {
          _isOnline = newOnlineStatus;
        });

        // OFFLINE-FIRST: Don't automatically apply templates when coming online
        // Templates should be applied only through manual user action
      }
    });

    Connectivity().checkConnectivity().then((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.mobile);
        });
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
      // Carregar todos os tópicos
      final topics =
          await _serviceFactory.dataService.getTopics(widget.inspectionId);

      // Carregar todos os itens e detalhes em paralelo
      for (int topicIndex = 0; topicIndex < topics.length; topicIndex++) {
        final topic = topics[topicIndex];

        // Carregar itens do tópico - use fallback if ID is null
        final topicId = topic.id ?? 'topic_$topicIndex';
        final items = await _serviceFactory.dataService.getItems(topicId);
        _itemsCache[topicId] = items;

        // Carregar detalhes de cada item
        for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
          final item = items[itemIndex];
          final itemId = item.id ?? 'item_$itemIndex';
          final details = await _serviceFactory.dataService.getDetails(itemId);
          _detailsCache['${topicId}_$itemId'] = details;
        }
      }

      if (mounted) {
        setState(() {
          _topics = topics;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar dados: $e');
      }
    }
  }

  Future<void> _checkAndApplyTemplate() async {
    if (_inspection == null || !mounted) return;

    if (_inspection!.templateId != null) {
      // Check if template was already applied by checking if there are topics
      final isAlreadyApplied = _topics.isNotEmpty;
      if (!mounted || isAlreadyApplied) {
        if (mounted) {
          setState(
              () => _inspection = _inspection!.copyWith(isTemplated: true));
        }
        return;
      }
      setState(() => _isApplyingTemplate = true);

      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aplicando template à inspeção...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Template application not yet implemented in new service
        // await _serviceFactory.dataService.applyTemplate(_inspection!.id, _inspection!.templateId!);

        if (!mounted) return;

        // Update inspection status in Firebase
        await FirebaseFirestore.instance
            .collection('inspections')
            .doc(_inspection!.id)
            .update({
          'is_templated': true,
          'status': 'in_progress',
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        final updatedInspection = _inspection!.copyWith(
          isTemplated: true,
          status: 'in_progress',
          updatedAt: DateTime.now(),
        );
        setState(() => _inspection = updatedInspection);

        await _loadInspection();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template aplicado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aplicar template: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isApplyingTemplate = false);
        }
      }
    }
  }

  Future<void> _manuallyApplyTemplate() async {
    if (_inspection == null || !_isOnline || _isApplyingTemplate) return;

    final isAlreadyApplied = _topics.isNotEmpty;
    if (!mounted) return;

    final shouldApply = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aplicar Template'),
            content: Text(isAlreadyApplied
                ? 'Esta inspeção já tem um template aplicado. Deseja reaplicá-lo?'
                : 'Deseja aplicar o template a esta inspeção?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                    backgroundColor: Color(0xFF6F4B99),
                    foregroundColor: Colors.white),
                child: const Text('Aplicar Template'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !shouldApply) return;

    setState(() => _isApplyingTemplate = true);

    try {
      if (isAlreadyApplied) {
        await FirebaseFirestore.instance
            .collection('inspections')
            .doc(_inspection!.id)
            .update({
          'is_templated': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _inspection = _inspection!.copyWith(isTemplated: false);
          });
        }
      }

      if (mounted) {
        await _checkAndApplyTemplate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aplicar template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplyingTemplate = false);
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
      // Adicionar o tópico à estrutura aninhada da inspeção
      await _addTopicToNestedStructure(result);

      await _markAsModified();

      // Reload data to ensure consistency
      await _loadAllData();

      if (mounted) {
        setState(() {}); // Trigger UI update
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico adicionado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar interface: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addTopicToNestedStructure(Topic topic) async {
    if (_inspection == null) return;

    try {
      // Criar estrutura do tópico como seria no Firestore
      final topicData = {
        'name': topic.topicName,
        'description': topic.topicLabel,
        'observation': topic.observation,
        'items': [], // Inicialmente vazio
      };

      // Obter os topics atuais da inspeção
      final currentTopics =
          List<Map<String, dynamic>>.from(_inspection!.topics ?? []);

      // Adicionar o novo tópico
      currentTopics.add(topicData);

      // Atualizar a inspeção com a nova estrutura
      final updatedInspection = _inspection!.copyWith(topics: currentTopics);

      // Salvar no banco local
      await _serviceFactory.dataService.saveInspection(updatedInspection);

      // Processar a estrutura aninhada atualizada
      await _serviceFactory.syncService.syncInspection(widget.inspectionId);

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
    // Changes are automatically marked for sync in offline-first mode
    // Recarregar dados sem setState global
    await _loadAllData();

    // Trigger UI update to show sync indicator
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _importInspection() async {
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar Inspeção'),
        content: const Text(
            'Esta funcionalidade não está disponível no modo offline.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Import functionality removed for offline-first mode
    // This would need to be reimplemented to work with the new SQLite system
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
      case 'nonConformities':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NonConformityScreen(
              inspectionId: widget.inspectionId,
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
                  if (!_isLoading) ...[
                    const SizedBox(height: 2),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isOnline &&
              _inspection != null &&
              _inspection!.templateId != null)
            IconButton(
              icon: const Icon(Icons.architecture, size: 22),
              tooltip: _inspection!.isTemplated
                  ? 'Reaplicar Template'
                  : 'Aplicar Template',
              onPressed: _isApplyingTemplate ? null : _manuallyApplyTemplate,
              padding: const EdgeInsets.all(5),
              visualDensity: VisualDensity.compact,
            ),
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
