// lib/presentation/screens/media/media_gallery_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_viewer_screen.dart';
import 'package:lince_inspecoes/presentation/screens/media/components/media_filter_panel.dart';
import 'package:lince_inspecoes/presentation/screens/media/components/media_grid.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/media_capture_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MediaGalleryScreen extends StatefulWidget {
  final String inspectionId;
  final String? initialTopicId;
  final String? initialItemId;
  final String? initialDetailId;
  final bool? initialIsNonConformityOnly;
  final String? initialMediaType;
  // THE FIX: Novos parâmetros para filtro explícito
  final bool initialTopicOnly;
  final bool initialItemOnly;

  const MediaGalleryScreen({
    super.key,
    required this.inspectionId,
    this.initialTopicId,
    this.initialItemId,
    this.initialDetailId,
    this.initialIsNonConformityOnly,
    this.initialMediaType,
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

  // Estado dos filtros
  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;
  bool? _selectedIsNonConformityOnly;
  String? _selectedMediaType;
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
  }

  void _setInitialFilters() {
    _selectedTopicId = widget.initialTopicId;
    _selectedItemId = widget.initialItemId;
    _selectedDetailId = widget.initialDetailId;
    _selectedMediaType = widget.initialMediaType;
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
        // Load from regular cache/cloud
        final results = await Future.wait([
          _serviceFactory.mediaService
              .getMediaByInspection(widget.inspectionId),
          _serviceFactory.dataService.getTopics(widget.inspectionId),
        ]);
        allMedia = results[0] as List<Map<String, dynamic>>;
        topics = results[1] as List<Topic>;
      }

      _allMedia = allMedia;
      _topics = topics;
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
      // Get all offline media for this inspection
      final offlineMediaList = await _serviceFactory.mediaService
          .getMediaByInspection(widget.inspectionId);

      // Convert OfflineMedia objects to Map<String, dynamic>
      return offlineMediaList.map((media) => media.toJson()).toList();
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
    debugPrint('MediaGalleryScreen: Applying filters on ${_allMedia.length} media items');
    List<Map<String, dynamic>> filteredMedia = _allMedia;

    // Apply filters directly
    if (_selectedTopicId != null) {
      filteredMedia = filteredMedia
          .where((media) => media['topic_id'] == _selectedTopicId)
          .toList();
      debugPrint('MediaGalleryScreen: After topic filter: ${filteredMedia.length} items');
    }
    if (_selectedItemId != null) {
      filteredMedia = filteredMedia
          .where((media) => media['item_id'] == _selectedItemId)
          .toList();
      debugPrint('MediaGalleryScreen: After item filter: ${filteredMedia.length} items');
    }
    if (_selectedDetailId != null) {
      filteredMedia = filteredMedia
          .where((media) => media['detail_id'] == _selectedDetailId)
          .toList();
      debugPrint('MediaGalleryScreen: After detail filter: ${filteredMedia.length} items');
    }
    if (_selectedMediaType != null) {
      filteredMedia = filteredMedia
          .where((media) => media['type'] == _selectedMediaType)
          .toList();
      debugPrint('MediaGalleryScreen: After type filter: ${filteredMedia.length} items');
    }
    if (_selectedIsNonConformityOnly == true) {
      filteredMedia = filteredMedia
          .where((media) => media['non_conformity_id'] != null)
          .toList();
      debugPrint('MediaGalleryScreen: After NC filter: ${filteredMedia.length} items');
    }

    debugPrint('MediaGalleryScreen: Final filtered media count: ${filteredMedia.length}');
    setState(() {
      _filteredMedia = filteredMedia;
      _updateActiveFiltersCount();
    });
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
      await showDialog(
        context: context,
        builder: (context) => MediaCaptureDialog(
          onMediaCaptured: (filePath, type) async {
            try {
              // Processar e salvar mídia usando o contexto atual da galeria
              // Se não há filtros, salva no contexto geral da inspeção
              await _serviceFactory.mediaService.captureAndProcessMediaSimple(
                inputPath: filePath,
                inspectionId: widget.inspectionId,
                type: type,
                topicId: _selectedTopicId ?? widget.initialTopicId,
                itemId: _selectedItemId ?? widget.initialItemId,
                detailId: _selectedDetailId ?? widget.initialDetailId,
              );

              if (mounted && context.mounted) {
                final message = type == 'image' ? 'Foto salva!' : 'Vídeo salvo!';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                  ),
                );

                // Recarregar a galeria para mostrar a nova mídia
                _loadData();
              }
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
      );
    } catch (e) {
      debugPrint('Error showing capture dialog in gallery: $e');
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
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Limpar Seleção',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitMultiSelectMode,
              tooltip: 'Sair da Seleção',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: _showCaptureDialog,
              tooltip: 'Capturar Mídia',
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
                      media: _filteredMedia,
                      onTap: (mediaItem) {
                        if (_isMultiSelectMode) {
                          _toggleSelection(mediaItem['id']);
                        } else {
                          final index = _filteredMedia.indexOf(mediaItem);
                          _showMediaViewer(index);
                        }
                      },
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

  void _createNonConformityWithSelectedMedia() {
    if (_selectedMediaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma mídia selecionada')),
      );
      return;
    }

    _exitMultiSelectMode();

    // Navigate to NonConformityScreen with preselected values
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NonConformityScreen(
          inspectionId: widget.inspectionId,
          preSelectedTopic: widget.initialTopicId,
          preSelectedItem: widget.initialItemId,
          preSelectedDetail: widget.initialDetailId,
          selectedMediaIds: _selectedMediaIds.toList(),
        ),
      ),
    ).then((_) {
      // Refresh the media gallery when returning from NC screen
      _loadData();
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_selectedMediaIds.length} item(ns) selecionado(s)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.drive_file_move, color: Colors.blue),
              title: const Text('Mover para Não Conformidade'),
              onTap: () {
                Navigator.pop(context);
                _showMoveToNCDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToNCDialog() {
    // This will be implemented to create new non-conformities with selected media
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mover para Não Conformidade'),
        content: const Text(
            'Esta funcionalidade permitirá criar uma nova não conformidade com as mídias selecionadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createNonConformityWithSelectedMedia();
            },
            child: const Text('Criar NC'),
          ),
        ],
      ),
    );
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
      for (final mediaId in _selectedMediaIds) {
        await _serviceFactory.mediaService.deleteMedia(mediaId);
      }

      _exitMultiSelectMode();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedMediaIds.length} mídia(s) excluída(s) com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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
  String? _thumbnailPath;
  bool _isLoadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    if (widget.media['type'] == 'video') {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    final String? videoPath = widget.media['localPath'];
    if (videoPath == null || !File(videoPath).existsSync()) return;
    if (mounted) setState(() => _isLoadingThumbnail = true);
    try {
      final tempDir = await getTemporaryDirectory();
      _thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          quality: 50,
          maxWidth: 200);
    } catch (e) {
      debugPrint("Error generating thumbnail: $e");
    } finally {
      if (mounted) setState(() => _isLoadingThumbnail = false);
    }
  }

  ImageProvider? _getImageProvider() {
    if (widget.media['type'] == 'image') {
      final String? localPath = widget.media['localPath'];
      if (localPath != null && File(localPath).existsSync()) {
        return FileImage(File(localPath));
      }
      final String? url = widget.media['url'];
      if (url != null) return NetworkImage(url);
    }
    if (_thumbnailPath != null) return FileImage(File(_thumbnailPath!));
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
                          else if (_isLoadingThumbnail)
                            const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                          else
                            const Icon(Icons.movie_creation_outlined,
                                color: Colors.grey),
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
                  maxLines: 1,
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
