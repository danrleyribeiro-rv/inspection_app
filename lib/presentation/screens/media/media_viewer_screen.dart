import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  bool _showUI = true;
  final Map<int, VideoPlayerController?> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose video controllers
    for (var controller in _videoControllers.values) {
      controller?.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
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
    final bool hasLocalPath =
        media['localPath'] != null && File(media['localPath']).existsSync();
    final bool hasUrl = media['url'] != null;

    if (isImage) {
      if (hasLocalPath) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(media['localPath']),
            fit: BoxFit.contain,
            errorBuilder: (ctx, error, _) => _buildErrorWidget(),
          ),
        );
      } else if (hasUrl) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            media['url'],
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildLoadingWidget();
            },
            errorBuilder: (ctx, error, _) => _buildErrorWidget(),
          ),
        );
      }
    } else {
      // Video
      return _buildVideoPlayer(media, index);
    }
    return _buildUnsupportedWidget();
  }

  Widget _buildVideoPlayer(Map<String, dynamic> media, int index) {
    VideoPlayerController? controller = _videoControllers[index];
    if (controller == null) {
      // Initialize controller
      if (media['localPath'] != null && File(media['localPath']).existsSync()) {
        controller = VideoPlayerController.file(File(media['localPath']));
      } else if (media['url'] != null) {
        controller = VideoPlayerController.networkUrl(Uri.parse(media['url']));
      }
      if (controller != null) {
        _videoControllers[index] = controller;
        controller.initialize().then((_) {
          if (mounted) setState(() {});
        });
      }
    }
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingWidget();
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        if (!controller.value.isPlaying)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((255 * 0.5).round()),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
              onPressed: () {
                controller!.play();
                setState(() {});
              },
            ),
          ),
        if (controller.value.isPlaying)
          GestureDetector(
            onTap: () {
              controller!.pause();
              setState(() {});
            },
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
      ],
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
          Text('Erro ao carregar mídia', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildUnsupportedWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, color: Colors.white, size: 64),
          SizedBox(height: 16),
          Text('Tipo de mídia não suportado',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMedia = widget.mediaItems[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          children: [
            // PageView para swipe entre imagens
            PageView.builder(
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

            // AppBar superior
            if (_showUI)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha((255 * 0.7).round()),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      title: Text(
                        '${_currentIndex + 1} de ${widget.mediaItems.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      iconTheme: const IconThemeData(color: Colors.white),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () {
                            // Implementar compartilhamento
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () {
                            // Implementar download
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Informações na parte inferior
            if (_showUI)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha((255 * 0.8).round()),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Localização
                          if (currentMedia['topic_name'] != null)
                            Text(
                              'Tópico: ${currentMedia['topic_name']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (currentMedia['item_name'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Item: ${currentMedia['item_name']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                          if (currentMedia['detail_name'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Detalhe: ${currentMedia['detail_name']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Data e tipo
                          Row(
                            children: [
                              Icon(
                                currentMedia['type'] == 'image'
                                    ? Icons.photo
                                    : Icons.videocam,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateTime(currentMedia['created_at']),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const Spacer(),
                              if (currentMedia['is_non_conformity'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withAlpha((255 * 0.8).round()),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'NC',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          // Observação se existir
                          if (currentMedia['observation'] != null &&
                              (currentMedia['observation'] as String)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha((255 * 0.3).round()),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentMedia['observation'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Indicadores de navegação lateral
            if (_showUI && widget.mediaItems.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((255 * 0.5).round()),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon:
                            const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (_currentIndex < widget.mediaItems.length - 1)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((255 * 0.5).round()),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
