import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

class MediaViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> mediaItems;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController?> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose video controllers
    for (var controller in _videoControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  String _formatDateTime(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Data desconhecida';
      }
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Data inválida';
    }
  }

  Widget _buildMediaWidget(Map<String, dynamic> media, int index) {
    final bool isImage = media['type'] == 'image';
    
    // Try multiple path formats for compatibility
    String displayPath = '';
    if (media['localPath'] != null && media['localPath'].toString().isNotEmpty) {
      displayPath = media['localPath'].toString();
    } else if (media['local_path'] != null && media['local_path'].toString().isNotEmpty) {
      displayPath = media['local_path'].toString();
    } else if (media['cloudUrl'] != null && media['cloudUrl'].toString().isNotEmpty) {
      displayPath = media['cloudUrl'].toString();
    } else if (media['url'] != null && media['url'].toString().isNotEmpty) {
      displayPath = media['url'].toString();
    }

    // Check if media is available
    if (displayPath.isEmpty) {
      return _buildUnavailableWidget();
    }

    // Verify local file exists
    if (!displayPath.startsWith('http')) {
      final file = File(displayPath);
      if (!file.existsSync()) {
        return _buildUnavailableWidget();
      }
    }

    if (isImage) {
      return _buildImageWidget(displayPath);
    } else {
      return _buildVideoWidget(displayPath, index);
    }
  }

  Widget _buildVideoWidget(String path, int index) {
    // Simplified video widget - you can enhance this later
    return const Center(
      child: Text(
        'Vídeo Player\n(Em desenvolvimento)',
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildErrorWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.white, size: 64),
          SizedBox(height: 16),
          Text(
            'Erro ao carregar mídia',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String displayPath) {
    return PhotoView(
      imageProvider: displayPath.startsWith('http')
          ? NetworkImage(displayPath)
          : FileImage(File(displayPath)) as ImageProvider,
      minScale: PhotoViewComputedScale.contained * 0.5,
      maxScale: PhotoViewComputedScale.covered * 3.0,
      initialScale: PhotoViewComputedScale.contained,
      basePosition: Alignment.center,
      scaleStateChangedCallback: (PhotoViewScaleState state) {
        debugPrint('PhotoView scale state: $state');
      },
      onTapUp: (context, details, controllerValue) {
        if (controllerValue.scale! <= PhotoViewComputedScale.contained.multiplier) {
          // Only toggle UI when not zoomed
        }
      },
      enableRotation: false,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      heroAttributes: PhotoViewHeroAttributes(tag: displayPath),
      loadingBuilder: (context, event) => _buildLoadingWidget(),
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
    );
  }

  Widget _buildUnavailableWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, color: Colors.white, size: 64),
          SizedBox(height: 16),
          Text('Mídia não disponível', style: TextStyle(color: Colors.white)),
          SizedBox(height: 8),
          Text(
              'A mídia pode estar sendo processada ou não foi sincronizada ainda',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} de ${widget.mediaItems.length}',
          style: const TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: _buildMediaWidget(widget.mediaItems[index], index),
          );
        },
      ),
    );
  }
}