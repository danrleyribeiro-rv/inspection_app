// lib/presentation/screens/media/media_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class MediaPreviewScreen extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  
  const MediaPreviewScreen({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    
    // Configurar orientação preferida para visualização em tela cheia
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Inicializar player de vídeo se necessário
    if (widget.mediaType == 'video') {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }
  
  @override
  void dispose() {
    // Restaurar orientação padrão
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Liberar recursos do player de vídeo
    _videoController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Implementar download da mídia
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Implementar compartilhamento da mídia
            },
          ),
        ],
      ),
      body: Center(
        child: widget.mediaType == 'video'
            ? _buildVideoPlayer()
            : _buildImageViewer(),
      ),
    );
  }
  
  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        widget.mediaUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Erro ao carregar imagem',
                style: TextStyle(color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        
        // Controles de vídeo
        if (!_isPlaying || !_videoController!.value.isPlaying)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((255 * 0.5).round()),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                    _isPlaying = false;
                  } else {
                    _videoController!.play();
                    _isPlaying = true;
                  }
                });
              },
            ),
          ),
      ],
    );
  }
}