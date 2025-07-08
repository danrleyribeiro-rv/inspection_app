// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:inspection_app/models/cached_inspection.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/presentation/screens/inspection/components/hierarchical_inspection_view.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/components/empty_topic_state.dart';
import 'package:inspection_app/presentation/screens/inspection/components/loading_state.dart';
import 'package:inspection_app/presentation/widgets/dialogs/offline_template_topic_selector_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/inspection_info_dialog.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/sync/sync_progress_overlay.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final ServiceFactory _serviceFactory = ServiceFactory();

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _isApplyingTemplate = false;
  // Removed _hasUnsavedChanges - not needed in offline-first mode
  bool _isAvailableOffline = false; // Track if inspection is fully available offline
  bool _canEdit = false; // Track if user can edit (based on offline availability)
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
    debugPrint('InspectionDetailScreen: Exiting without auto-sync (offline-first mode)');
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
      final cached = _serviceFactory.cacheService.getCachedInspection(widget.inspectionId);
      _isAvailableOffline = cached != null && cached.localStatus == 'downloaded';
      _canEdit = _isAvailableOffline;

      if (_isAvailableOffline) {
        // Load from offline storage (OFFLINE-FIRST)
        final offlineInspection = await _serviceFactory.cacheService.getInspection(widget.inspectionId);
        if (offlineInspection != null) {
          setState(() {
            _inspection = offlineInspection;
          });
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
          await _serviceFactory.cacheService.getTopics(widget.inspectionId);

      // Carregar todos os itens e detalhes em paralelo
      for (final topic in topics) {
        if (topic.id != null) {
          // Carregar itens do tópico
          final items = await _serviceFactory.coordinator.getItems(
            widget.inspectionId,
            topic.id!,
          );
          _itemsCache[topic.id!] = items;

          // Carregar detalhes de cada item
          for (final item in items) {
            if (item.id != null) {
              final details = await _serviceFactory.coordinator.getDetails(
                widget.inspectionId,
                topic.id!,
                item.id!,
              );
              _detailsCache['${topic.id!}_${item.id!}'] = details;
            }
          }
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
      final isAlreadyApplied = await _serviceFactory.coordinator
          .isTemplateAlreadyApplied(_inspection!.id);
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

        final success = await _serviceFactory.coordinator
            .applyTemplateToInspectionSafe(
                _inspection!.id, _inspection!.templateId!);

        if (!mounted) return;

        if (success) {
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

          // Changes are automatically tracked in cache service

          await _loadInspection();
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template aplicado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
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

    final isAlreadyApplied = await _serviceFactory.coordinator
        .isTemplateAlreadyApplied(_inspection!.id);
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
              'Esta inspeção está apenas parcialmente disponível. Para editar offline, '
              'você precisa baixar todos os dados e mídias. Deseja baixar agora?'
            ),
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
      builder: (context) => _OfflineDownloadDialog(inspectionId: widget.inspectionId),
    );

    try {
      final success = await _serviceFactory.coordinator.downloadInspectionForOfflineEditing(
        widget.inspectionId,
        onProgress: (progress) {
          // Progress is handled by the dialog
        },
      );

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        setState(() {
          _isAvailableOffline = true;
          _canEdit = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inspeção baixada com sucesso! Agora você pode editá-la offline.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Reload inspection from offline storage
        await _loadInspection();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao baixar inspeção. Verifique sua conexão.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
    await _markAsModified();
    
    // Changes are automatically tracked in cache service
    
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

  Future<void> _markAsModified() async {
    final inspectionsBox = Hive.box<CachedInspection>('inspections');
    final cachedInspection = inspectionsBox.get(widget.inspectionId);
    if (cachedInspection != null && cachedInspection.localStatus != 'modified') {
      cachedInspection.localStatus = 'modified';
      await cachedInspection.save();
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
    final confirmed = await _serviceFactory.importExportService
        .showImportConfirmationDialog(context);
    if (!mounted || !confirmed) return;
    setState(() => _isSyncing = true);

    try {
      final jsonData = await _serviceFactory.importExportService.pickJsonFile();
      if (!mounted || jsonData == null) {
        if (mounted) setState(() => _isSyncing = false);
        return;
      }

      final success = await _serviceFactory.importExportService
          .importInspection(widget.inspectionId, jsonData);
      if (!mounted) return;

      if (success) {
        await _loadInspection();
        if (mounted) {
          _serviceFactory.importExportService.showSuccessMessage(
              context, 'Dados da inspeção importados com sucesso');
        }
      } else {
        if (mounted) {
          _serviceFactory.importExportService
              .showErrorMessage(context, 'Falha ao importar dados da inspeção');
        }
      }
    } catch (e) {
      if (mounted) {
        _serviceFactory.importExportService
            .showErrorMessage(context, 'Erro ao importar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
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
            final items = _itemsCache[topic.id!] ?? [];
            totalItems += items.length;
            for (final item in items) {
              if (!mounted) return;
              final details = _detailsCache['${topic.id!}_${item.id!}'] ?? [];
              totalDetails += details.length;
            }
          }

          if (!mounted) return;
          final allMedia =
              await _serviceFactory.coordinator.getAllMedia(inspectionId);
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
      backgroundColor: const Color(0xFF312456),
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isLoading) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isAvailableOffline ? Icons.offline_pin : Icons.cloud_download,
                          size: 12,
                          color: _isAvailableOffline ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isAvailableOffline ? 'Offline' : 'Somente Leitura',
                          style: TextStyle(
                            fontSize: 10,
                            color: _isAvailableOffline ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
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
                    isDownloading: false, isApplyingTemplate: _isApplyingTemplate)
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
                    onTap: _canEdit ? _addTopic : () => _showOfflineRequiredDialog(),
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
          const Text('Baixando todos os dados e mídias para uso offline...'),
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