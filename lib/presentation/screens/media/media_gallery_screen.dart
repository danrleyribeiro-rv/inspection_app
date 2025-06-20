// lib/presentation/screens/media/media_gallery_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/screens/media/media_viewer_screen.dart';
import 'package:inspection_app/presentation/screens/media/components/media_filter_panel.dart';
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
    this.initialItemOnly = false,  // Padrão é false
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  List<Map<String, dynamic>> _allMedia = [];
  List<Map<String, dynamic>> _filteredMedia = [];
  List<Topic> _topics = [];
  bool _isLoading = true;

  // Estado dos filtros
  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;
  bool? _selectedIsNonConformityOnly;
  String? _selectedMediaType;
  bool _topicOnly = false;
  bool _itemOnly = false;
  int _activeFiltersCount = 0;

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
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _serviceFactory.mediaService.getAllMedia(widget.inspectionId),
        _serviceFactory.coordinator.getTopics(widget.inspectionId),
      ]);
      _allMedia = results[0] as List<Map<String, dynamic>>;
      _topics = results[1] as List<Topic>;
      _applyFilters();
    } catch (e) {
      debugPrint("Error loading media data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
  
  void _applyFilters() {
    setState(() {
      _filteredMedia = _serviceFactory.mediaService.filterMedia(
        allMedia: _allMedia,
        topicId: _selectedTopicId,
        itemId: _selectedItemId,
        detailId: _selectedDetailId,
        isNonConformityOnly: _selectedIsNonConformityOnly,
        mediaType: _selectedMediaType,
        topicOnly: _topicOnly,
        itemOnly: _itemOnly,
      );
      _updateActiveFiltersCount();
    });
  }

  void _clearFilters() {
    _onApplyFiltersCallback(
      topicId: null, itemId: null, detailId: null,
      isNonConformityOnly: null, mediaType: null,
      topicOnly: false, itemOnly: false,
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
      builder: (_) => MediaViewerScreen(mediaItems: _filteredMedia, initialIndex: initialIndex),
    ));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Galeria de Mídia")),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          if (_filteredMedia.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Icon(Icons.image_search, size: 60, color: Colors.grey.shade600),
                       const SizedBox(height: 16),
                       const Text("Nenhuma mídia encontrada", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                       const SizedBox(height: 8),
                      Text(
                        _activeFiltersCount > 0 ? "Tente ajustar ou limpar os filtros para ver mais resultados." : "Capture fotos ou vídeos na inspeção para vê-los aqui.",
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
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _filteredMedia.length,
                itemBuilder: (context, index) {
                  final media = _filteredMedia[index];
                  return _MediaGridTile(key: ValueKey(media['id']), media: media, onTap: () => _showMediaViewer(index));
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFilterPanel,
        icon: const Icon(Icons.filter_list),
        label: Text('Filtros ($_activeFiltersCount)'),
        backgroundColor: _activeFiltersCount > 0 ? Colors.blue : null,
      ),
    );
  }
}

class _MediaGridTile extends StatefulWidget {
  final Map<String, dynamic> media;
  final VoidCallback onTap;
  const _MediaGridTile({super.key, required this.media, required this.onTap});
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
      _thumbnailPath = await VideoThumbnail.thumbnailFile(video: videoPath, thumbnailPath: tempDir.path, imageFormat: ImageFormat.JPEG, quality: 50, maxWidth: 200);
    } catch(e) {
      debugPrint("Error generating thumbnail: $e");
    } finally {
      if (mounted) setState(() => _isLoadingThumbnail = false);
    }
  }

  ImageProvider? _getImageProvider() {
    if (widget.media['type'] == 'image') {
      final String? localPath = widget.media['localPath'];
      if (localPath != null && File(localPath).existsSync()) return FileImage(File(localPath));
      final String? url = widget.media['url'];
      if (url != null) return NetworkImage(url);
    }
    if (_thumbnailPath != null) return FileImage(File(_thumbnailPath!));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _getImageProvider();
    return GestureDetector(onTap: widget.onTap, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: GridTile(footer: _buildFooter(), child: Container(color: Colors.grey.shade800, child: Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
      if (imageProvider != null) Image(image: imageProvider, fit: BoxFit.cover) else if (_isLoadingThumbnail) const Center(child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.movie_creation_outlined, color: Colors.grey),
      if (widget.media['type'] == 'video') const Icon(Icons.play_circle_outline, color: Colors.white70, size: 40),
    ])))));
  }

  Widget _buildFooter() {
    final bool isNc = widget.media['is_non_conformity'] ?? false;
    final List<Widget> tags = [];
    if (isNc) tags.add(const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14));
    if (widget.media['detail_name'] != null) {
      tags.add(const Icon(Icons.list_alt, color: Colors.white70, size: 14));
    } else if (widget.media['item_name'] != null) tags.add(const Icon(Icons.category, color: Colors.white70, size: 14));
    else if (widget.media['topic_name'] != null) tags.add(const Icon(Icons.topic, color: Colors.white70, size: 14));
    String name = widget.media['detail_name'] ?? widget.media['item_name'] ?? widget.media['topic_name'] ?? 'Mídia';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black87, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter, stops: [0.0, 0.8])), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      if (tags.isNotEmpty) ...[const SizedBox(height: 2), Row(children: tags.map((t) => Padding(padding: const EdgeInsets.only(right: 4.0), child: t)).toList())]
    ]));
  }
}