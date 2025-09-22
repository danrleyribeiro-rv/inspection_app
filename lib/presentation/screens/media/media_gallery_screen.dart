// lib/presentation/screens/media/media_gallery_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_viewer_screen.dart';
import 'package:lince_inspecoes/presentation/screens/media/components/media_filter_panel.dart';
import 'package:lince_inspecoes/presentation/screens/media/components/media_grid.dart';
import 'package:lince_inspecoes/presentation/widgets/camera/inspection_camera_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/move_media_dialog.dart';
import 'package:lince_inspecoes/services/media_counter_notifier.dart';

class MediaGalleryScreen extends StatefulWidget {
  final String inspectionId;
  final String? initialTopicId;
  final String? initialItemId;
  final String? initialDetailId;
  final String? initialNonConformityId; // NEW: Filter by specific NC
  final bool? initialIsNonConformityOnly;
  final String? initialMediaType;
  final String? initialMediaSource; // NEW: Filter by media source
  final bool excludeResolutionMedia; // NEW: Exclude resolution media
  // THE FIX: Novos parâmetros para filtro explícito
  final bool initialTopicOnly;
  final bool initialItemOnly;

  const MediaGalleryScreen({
    super.key,
    required this.inspectionId,
    this.initialTopicId,
    this.initialItemId,
    this.initialDetailId,
    this.initialNonConformityId,
    this.initialIsNonConformityOnly,
    this.initialMediaType,
    this.initialMediaSource,
    this.excludeResolutionMedia = false,
    this.initialTopicOnly = false, // Padrão é false
    this.initialItemOnly = false, // Padrão é false
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  List<Map<String, dynamic>> _allMedia = [];
  List<Map<String, dynamic>> _filteredMedia = [];
  List<Topic> _topics = [];
  bool _isLoading = true;
  bool _isAvailableOffline = false;
  final int _refreshVersion = 0; // Force rebuild counter

  // Para forçar refreshes mais agressivos
  Timer? _refreshTimer;

  // Estado dos filtros
  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;
  String? _selectedNonConformityId; // NEW: Filter by specific NC
  bool? _selectedIsNonConformityOnly;
  String? _selectedMediaType;
  String? _selectedMediaSource; // NEW: Filter by media source
  bool _excludeResolutionMedia = false; // NEW: Exclude resolution media
  bool _topicOnly = false;
  bool _itemOnly = false;
  int _activeFiltersCount = 0;

  // Multi-select state
  bool _isMultiSelectMode = false;
  final Set<String> _selectedMediaIds = {};

  @override
  void initState() {
    super.initState();
    _setInitialFilters();
    _loadData();

    // Escutar mudanças nos contadores para reload automático
    MediaCounterNotifier.instance.addListener(_onMediaCounterChanged);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    MediaCounterNotifier.instance.removeListener(_onMediaCounterChanged);
    super.dispose();
  }

  void _onMediaCounterChanged() {
    debugPrint(
        'MediaGalleryScreen: MediaCounterNotifier triggered - single targeted reload');

    // Cancelar timer anterior se existe
    _refreshTimer?.cancel();

    // Single targeted refresh - apenas recarregar se necessário
    _refreshTimer = Timer(const Duration(milliseconds: 200), () async {
      if (mounted) {
        await _loadData();
      }
    });
  }

  void _setInitialFilters() {
    _selectedTopicId = widget.initialTopicId;
    _selectedItemId = widget.initialItemId;
    _selectedDetailId = widget.initialDetailId;
    _selectedNonConformityId = widget.initialNonConformityId;
    _selectedMediaType = widget.initialMediaType;
    _selectedMediaSource = widget.initialMediaSource;
    _excludeResolutionMedia = widget.excludeResolutionMedia;
    _selectedIsNonConformityOnly = widget.initialIsNonConformityOnly;

    // THE FIX: Usa os parâmetros explícitos
    _topicOnly = widget.initialTopicOnly;
    _itemOnly = widget.initialItemOnly;

    debugPrint('MediaGalleryScreen: Initial filters set');
    debugPrint('  TopicId: $_selectedTopicId');
    debugPrint('  ItemId: $_selectedItemId');
    debugPrint('  DetailId: $_selectedDetailId');
    debugPrint('  TopicOnly: $_topicOnly, ItemOnly: $_itemOnly');
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Force longer delay to ensure database operations and file system operations have completed
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      // Check offline availability first
      _isAvailableOffline = await _serviceFactory.dataService
              .getInspection(widget.inspectionId) !=
          null;

      // Load data based on availability
      List<Map<String, dynamic>> allMedia;
      List<Topic> topics;

      if (_isAvailableOffline) {
        // Load from offline storage
        final results = await Future.wait([
          _loadOfflineMedia(),
          _serviceFactory.dataService.getTopics(widget.inspectionId),
        ]);
        allMedia = results[0] as List<Map<String, dynamic>>;
        topics = results[1] as List<Topic>;
      } else {
        // Load from offline storage (always use offline storage)
        final results = await Future.wait([
          _loadOfflineMedia(),
          _serviceFactory.dataService.getTopics(widget.inspectionId),
        ]);
        allMedia = results[0] as List<Map<String, dynamic>>;
        topics = results[1] as List<Topic>;
      }

      final previousCount = _allMedia.length;
      final previousIds = _allMedia.map((m) => m['id']).toSet();
      _allMedia = allMedia;
      _topics = topics;
      final newIds = _allMedia.map((m) => m['id']).toSet();

      debugPrint(
          'MediaGalleryScreen._loadData: Previous count: $previousCount, New count: ${_allMedia.length}');
      debugPrint('MediaGalleryScreen._loadData: Previous IDs: $previousIds');
      debugPrint('MediaGalleryScreen._loadData: New IDs: $newIds');

      // Check if data actually changed (count or content)
      bool dataChanged = previousCount != _allMedia.length ||
          !previousIds.containsAll(newIds) ||
          !newIds.containsAll(previousIds);

      if (dataChanged) {
        debugPrint('MediaGalleryScreen._loadData: Data changed detected');
      }

      _applyFilters();
    } catch (e) {
      debugPrint("Error loading media data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar mídias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Load media from offline storage with full functionality
  Future<List<Map<String, dynamic>>> _loadOfflineMedia() async {
    try {
      debugPrint(
          'MediaGalleryScreen._loadOfflineMedia: Starting media load (version: $_refreshVersion)');

      // Reinitialize service to ensure fresh connection
      await _serviceFactory.mediaService.initialize();

      // Small delay to ensure any pending DB operations are complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Get all offline media for this inspection (SUPER fresh from DB)
      final offlineMediaList = await _serviceFactory.mediaService
          .getMediaByInspection(widget.inspectionId);

      debugPrint(
          'MediaGalleryScreen._loadOfflineMedia: Found ${offlineMediaList.length} media files (fresh from DB)');

      // Media IDs loaded (debug logging disabled)

      // Convert OfflineMedia objects to Map<String, dynamic> with additional fields
      final List<Map<String, dynamic>> enrichedMedia = [];

      for (final media in offlineMediaList) {
        final mediaData = media.toJson();

        // Debug: Log source values for camera issue debugging
        debugPrint(
            'MediaGalleryScreen: Media ${media.id} - source: ${media.source}');

        // Add missing fields that the gallery expects
        mediaData['url'] = media.cloudUrl; // For backward compatibility
        mediaData['is_non_conformity'] = media.nonConformityId != null;

        // Get names from related entities
        if (media.topicId != null) {
          try {
            final topic =
                await _serviceFactory.dataService.getTopic(media.topicId!);
            mediaData['topic_name'] = topic?.topicName ?? 'Tópico';
          } catch (e) {
            debugPrint(
                'MediaGalleryScreen: Error getting topic ${media.topicId}: $e');
            mediaData['topic_name'] = 'Tópico';
          }
        }

        if (media.itemId != null) {
          try {
            final item =
                await _serviceFactory.dataService.getItem(media.itemId!);
            mediaData['item_name'] = item?.itemName ?? 'Item';
          } catch (e) {
            debugPrint(
                'MediaGalleryScreen: Error getting item ${media.itemId}: $e');
            mediaData['item_name'] = 'Item';
          }
        }

        if (media.detailId != null) {
          try {
            final detail =
                await _serviceFactory.dataService.getDetail(media.detailId!);
            mediaData['detail_name'] = detail?.detailName ?? 'Detalhe';
          } catch (e) {
            debugPrint(
                'MediaGalleryScreen: Error getting detail ${media.detailId}: $e');
            mediaData['detail_name'] = 'Detalhe';
          }
        }

        enrichedMedia.add(mediaData);
      }

      debugPrint(
          'MediaGalleryScreen._loadOfflineMedia: Enriched ${enrichedMedia.length} media files with names');
      return enrichedMedia;
    } catch (e) {
      debugPrint(
          'MediaGalleryScreen._loadOfflineMedia: Error loading offline media: $e');
      return [];
    }
  }

  void _onApplyFiltersCallback({
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
    required bool topicOnly,
    required bool itemOnly,
  }) {
    setState(() {
      _selectedTopicId = topicId;
      _selectedItemId = itemId;
      _selectedDetailId = detailId;
      _selectedIsNonConformityOnly = isNonConformityOnly;
      _selectedMediaType = mediaType;
      _topicOnly = topicOnly;
      _itemOnly = itemOnly;
    });
    _applyFilters();
  }

  void _applyFilters() async {
    debugPrint(
        'MediaGalleryScreen: Applying filters on ${_allMedia.length} media items');
    debugPrint(
        'MediaGalleryScreen: Current filters - Topic: $_selectedTopicId, Item: $_selectedItemId, Detail: $_selectedDetailId');
    debugPrint(
        'MediaGalleryScreen: Filter options - TopicOnly: $_topicOnly, ItemOnly: $_itemOnly');

    // Sample media data logging removed for performance

    List<Map<String, dynamic>> filteredMedia = _allMedia;

    // Apply hierarchical filters with level-specific logic
    if (_selectedTopicId != null) {
      // Filter by topic ID - supports both key formats
      filteredMedia = filteredMedia.where((media) {
        final topicId = media['topicId'] ?? media['topic_id'];
        return topicId == _selectedTopicId;
      }).toList();
      // Debug: After topic filter

      // If topicOnly is true, show only media at topic level (no item or detail)
      if (_topicOnly) {
        filteredMedia = filteredMedia.where((media) {
          final itemId = media['itemId'] ?? media['item_id'];
          final detailId = media['detailId'] ?? media['detail_id'];
          return itemId == null && detailId == null;
        }).toList();
        debugPrint(
            'MediaGalleryScreen: After topic-only filter: ${filteredMedia.length} items');
      }
    }

    if (_selectedItemId != null) {
      // Filter by item ID - supports both key formats
      filteredMedia = filteredMedia.where((media) {
        final itemId = media['itemId'] ?? media['item_id'];
        return itemId == _selectedItemId;
      }).toList();
      // Debug: After item filter

      // If itemOnly is true, show only media at item level (no detail)
      if (_itemOnly) {
        filteredMedia = filteredMedia.where((media) {
          final detailId = media['detailId'] ?? media['detail_id'];
          return detailId == null;
        }).toList();
        // Debug: After item-only filter
      }
    }

    if (_selectedDetailId != null) {
      // Filter by detail ID - supports both key formats
      filteredMedia = filteredMedia.where((media) {
        final detailId = media['detailId'] ?? media['detail_id'];
        return detailId == _selectedDetailId;
      }).toList();
      debugPrint(
          'MediaGalleryScreen: After detail filter: ${filteredMedia.length} items');
    }

    if (_selectedMediaType != null) {
      filteredMedia = filteredMedia
          .where((media) => media['type'] == _selectedMediaType)
          .toList();
      debugPrint(
          'MediaGalleryScreen: After type filter: ${filteredMedia.length} items');
    }

    if (_selectedIsNonConformityOnly == true) {
      filteredMedia = filteredMedia.where((media) {
        final ncId = media['nonConformityId'] ?? media['non_conformity_id'];
        return ncId != null;
      }).toList();
      debugPrint(
          'MediaGalleryScreen: After NC filter: ${filteredMedia.length} items');
    }

    if (_selectedNonConformityId != null) {
      filteredMedia = filteredMedia.where((media) {
        final ncId = media['nonConformityId'] ?? media['non_conformity_id'];
        return ncId == _selectedNonConformityId;
      }).toList();
      debugPrint(
          'MediaGalleryScreen: After specific NC filter: ${filteredMedia.length} items');
    }

    if (_selectedMediaSource != null) {
      filteredMedia = filteredMedia.where((media) {
        final source = media['source'];
        return source == _selectedMediaSource;
      }).toList();
      debugPrint(
          'MediaGalleryScreen: After source filter: ${filteredMedia.length} items');
    }

    if (_excludeResolutionMedia) {
      filteredMedia = filteredMedia.where((media) {
        final source = media['source'];
        return source != 'resolution_camera' && source != 'resolution_gallery';
      }).toList();
      // Debug: After excluding resolution media
    }

    // Removed excessive debug logs for filtering

    // Data change tracking removed after optimization

    setState(() {
      _filteredMedia = filteredMedia;
      _updateActiveFiltersCount();
    });
    // State updated (debug logging disabled)
  }

  void _clearFilters() {
    _onApplyFiltersCallback(
      topicId: null,
      itemId: null,
      detailId: null,
      isNonConformityOnly: null,
      mediaType: null,
      topicOnly: false,
      itemOnly: false,
    );
  }

  void _updateActiveFiltersCount() {
    int count = 0;
    if (_selectedTopicId != null) count++;
    if (_topicOnly) count++;
    if (_selectedItemId != null) count++;
    if (_itemOnly) count++;
    if (_selectedDetailId != null) count++;
    if (_selectedIsNonConformityOnly == true) count++;
    if (_selectedMediaType != null) count++;
    _activeFiltersCount = count;
  }

  String _getActiveFilterDescription() {
    List<String> descriptions = [];

    if (_selectedDetailId != null) {
      descriptions.add('Detalhe');
    } else if (_selectedItemId != null) {
      if (_itemOnly) {
        descriptions.add('Item específico');
      } else {
        descriptions.add('Item');
      }
    } else if (_selectedTopicId != null) {
      if (_topicOnly) {
        descriptions.add('Tópico específico');
      } else {
        descriptions.add('Tópico');
      }
    }

    if (_selectedIsNonConformityOnly == true) {
      descriptions.add('Não Conformidade');
    }

    if (_selectedMediaType != null) {
      descriptions.add(_selectedMediaType == 'image' ? 'Imagens' : 'Vídeos');
    }

    return descriptions.isNotEmpty ? descriptions.join(', ') : 'Geral';
  }

  void _openFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 10,
      useSafeArea: false,
      builder: (context) => MediaFilterPanel(
        inspectionId: widget.inspectionId,
        topics: _topics,
        selectedTopicId: _selectedTopicId,
        selectedItemId: _selectedItemId,
        selectedDetailId: _selectedDetailId,
        isNonConformityOnly: _selectedIsNonConformityOnly,
        mediaType: _selectedMediaType,
        onApplyFilters: _onApplyFiltersCallback,
        onClearFilters: _clearFilters,
      ),
    );
  }

  void _showMediaViewer(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaViewerScreen(
          mediaItems: _filteredMedia, initialIndex: initialIndex),
    ));
  }

  Future<void> _showCaptureDialog() async {
    try {
      // Determine correct source for resolution media
      String effectiveSource = 'camera';
      if (_selectedNonConformityId != null ||
          widget.initialNonConformityId != null) {
        // If we're in a non-conformity context and the current filter is for resolution media
        if (_selectedMediaSource == 'resolution_camera' ||
            widget.initialMediaSource == 'resolution_camera') {
          effectiveSource = 'resolution_camera';
          debugPrint('MediaGalleryScreen: Adjusted source to resolution: $effectiveSource');
        }
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => InspectionCameraScreen(
            inspectionId: widget.inspectionId,
            topicId: _selectedTopicId ?? widget.initialTopicId,
            itemId: _selectedItemId ?? widget.initialItemId,
            detailId: _selectedDetailId ?? widget.initialDetailId,
            nonConformityId: _selectedNonConformityId ?? widget.initialNonConformityId,
            source: effectiveSource,
            onMediaCaptured: (capturedFiles) async {
              try {
                // Media files captured (debug logging disabled)

                // Reload controlled after media capture
                await Future.delayed(const Duration(milliseconds: 300));
                await _loadData();

                if (mounted && context.mounted) {
                  final message = capturedFiles.length == 1
                      ? 'Mídia salva!'
                      : '${capturedFiles.length} mídias salvas!';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }

                // Final gallery state (debug logging disabled)
              } catch (e) {
                debugPrint('Error processing media in gallery: $e');
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao processar mídia: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing camera screen in gallery: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMultiSelectMode
            ? '${_selectedMediaIds.length} selecionado(s)'
            : "Galeria de Mídia"),
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: 'Selecionar Todos',
            ),
            IconButton(
              icon: const Icon(Icons.deselect),
              onPressed: _clearSelection,
              tooltip: 'Limpar Seleção',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitMultiSelectMode,
              tooltip: 'Sair do Modo Seleção',
            ),
          ] else ...[
            // Show camera button ONLY when there are active filters (to avoid orphaned media)
            if (_activeFiltersCount > 0)
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: _showCaptureDialog,
                tooltip: 'Capturar Mídia (${_getActiveFilterDescription()})',
              ),
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _enterMultiSelectMode,
              tooltip: 'Modo de Seleção',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_filteredMedia.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_search,
                                size: 60, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            const Text("Nenhuma mídia encontrada",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text(
                              _activeFiltersCount > 0
                                  ? "Tente ajustar ou limpar os filtros para ver mais resultados."
                                  : "Capture fotos ou vídeos na inspeção para vê-los aqui.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: MediaGrid(
                      key: ValueKey(
                          'media_grid_$_refreshVersion'), // Force rebuild with version
                      media: _filteredMedia,
                      onTap: (mediaItem) {
                        if (_isMultiSelectMode) {
                          _toggleSelection(mediaItem['id']);
                        } else {
                          final index = _filteredMedia.indexOf(mediaItem);
                          _showMediaViewer(index);
                        }
                      },
                      onLongPress: (mediaItem) {
                        if (!_isMultiSelectMode) {
                          _enterMultiSelectMode();
                        }
                        _toggleSelection(mediaItem['id']);
                      },
                      isMultiSelectMode: _isMultiSelectMode,
                      selectedMediaIds: _selectedMediaIds,
                      onRefresh: _loadData,
                    ),
                  ),
              ],
            ),
      floatingActionButton: _isMultiSelectMode && _selectedMediaIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showMultiSelectActions,
              icon: const Icon(Icons.more_horiz),
              label: const Text('Ações'),
              backgroundColor: Colors.orange,
            )
          : FloatingActionButton.extended(
              onPressed: _openFilterPanel,
              icon: const Icon(Icons.filter_list),
              label: Text('Filtros ($_activeFiltersCount)'),
              backgroundColor:
                  _activeFiltersCount > 0 ? const Color(0xFF6F4B99) : null,
            ),
    );
  }

  void _enterMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = true;
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedMediaIds.clear();
    });
  }


  void _toggleSelection(String mediaId) {
    setState(() {
      if (_selectedMediaIds.contains(mediaId)) {
        _selectedMediaIds.remove(mediaId);
      } else {
        _selectedMediaIds.add(mediaId);
      }

      // Exit multi-select mode if no items are selected
      if (_selectedMediaIds.isEmpty) {
        _isMultiSelectMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedMediaIds.clear();
      _selectedMediaIds
          .addAll(_filteredMedia.map((media) => media['id'].toString()));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMediaIds.clear();
    });
  }

  void _showMultiSelectActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '${_selectedMediaIds.length} item(ns) selecionado(s)',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    const Icon(Icons.folder_open, color: Color(0xFF6F4B99)),
                title: const Text('Mover Imagem(s)',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showBulkMoveDialog('topic');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Excluir Imagem(s)',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Remover permanentemente',
                    style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showBulkMoveDialog(String destinationType) {
    if (_selectedMediaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma mídia selecionada')),
      );
      return;
    }

    // Create a special dialog for bulk operations
    showDialog(
      context: context,
      builder: (context) => MoveMediaDialog(
        inspectionId: widget.inspectionId,
        selectedMediaIds: _selectedMediaIds.toList(),
        currentLocation: _selectedMediaIds.length == 1
            ? _buildLocationDescription(_filteredMedia.firstWhere(
                (media) => media['id'] == _selectedMediaIds.first,
                orElse: () => {},
              ))
            : 'Múltiplas localizações',
        isOfflineMode: !_isAvailableOffline,
      ),
    ).then((result) {
      if (result == true && mounted) {
        // Reload data and exit multi-select mode
        final selectedCount = _selectedMediaIds.length;
        _exitMultiSelectMode();
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$selectedCount mídia(s) movida(s) com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  String _buildLocationDescription(Map<String, dynamic> media) {
    List<String> parts = [];
    if (media['topic_name'] != null) {
      parts.add('Tópico: ${media['topic_name']}');
    }
    if (media['item_name'] != null) {
      parts.add('Item: ${media['item_name']}');
    }
    if (media['detail_name'] != null) {
      parts.add('Detalhe: ${media['detail_name']}');
    }
    if (media['is_non_conformity'] == true) {
      parts.add('(NC)');
    }
    return parts.isEmpty ? 'Localização não especificada' : parts.join(' → ');
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Mídias'),
        content: Text(
            'Tem certeza que deseja excluir ${_selectedMediaIds.length} mídia(s) selecionada(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedMedia();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedMedia() async {
    try {
      final deletedCount = _selectedMediaIds.length;
      debugPrint(
          'MediaGalleryScreen: Starting deletion of $deletedCount media items');

      for (final mediaId in _selectedMediaIds) {
        await _serviceFactory.mediaService.deleteMedia(mediaId);
      }

      debugPrint('MediaGalleryScreen: All media deleted, refreshing data');
      _exitMultiSelectMode();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount mídia(s) excluída(s) com sucesso'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint('MediaGalleryScreen: Error during bulk deletion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir mídias: $e')),
        );
      }
    }
  }
}

class _MediaGridTile extends StatefulWidget {
  final Map<String, dynamic> media;
  final VoidCallback onTap;
  const _MediaGridTile({required this.media, required this.onTap});
  @override
  State<_MediaGridTile> createState() => _MediaGridTileState();
}

class _MediaGridTileState extends State<_MediaGridTile> {
  ImageProvider? _getImageProvider() {
    if (widget.media['type'] == 'image') {
      final String? localPath = widget.media['localPath'];
      if (localPath != null && File(localPath).existsSync()) {
        return FileImage(File(localPath));
      }
      final String? url = widget.media['url'];
      if (url != null) return NetworkImage(url);
    }
    // Para vídeos, não retorna provider - usaremos ícone
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _getImageProvider();
    return GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GridTile(
                footer: _buildFooter(),
                child: Container(
                    color: Colors.grey.shade800,
                    child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          if (imageProvider != null)
                            Image(image: imageProvider, fit: BoxFit.cover)
                          else
                            const Icon(Icons.movie_creation_outlined,
                                color: Colors.grey, size: 48),
                          if (widget.media['type'] == 'video')
                            const Icon(Icons.play_circle_outline,
                                color: Colors.white70, size: 40),
                        ])))));
  }

  Widget _buildFooter() {
    final bool isNc = widget.media['is_non_conformity'] ?? false;
    final List<Widget> tags = [];
    if (isNc) {
      tags.add(const Icon(Icons.warning_amber_rounded,
          color: Colors.orange, size: 14));
    }
    if (widget.media['detail_name'] != null) {
      tags.add(const Icon(Icons.list_alt, color: Colors.white70, size: 14));
    } else if (widget.media['item_name'] != null) {
      tags.add(const Icon(Icons.category, color: Colors.white70, size: 14));
    } else if (widget.media['topic_name'] != null) {
      tags.add(const Icon(Icons.topic, color: Colors.white70, size: 14));
    }
    String name = widget.media['detail_name'] ??
        widget.media['item_name'] ??
        widget.media['topic_name'] ??
        'Mídia';
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.black87, Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0.0, 0.8])),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                    children: tags
                        .map((t) => Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: t))
                        .toList())
              ]
            ]));
  }
}
