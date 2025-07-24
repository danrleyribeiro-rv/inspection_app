// lib/presentation/screens/media/media_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';

class MediaPreviewScreen extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final Map<String, dynamic>? mediaMetadata;
  
  const MediaPreviewScreen({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.mediaMetadata,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  
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
        title: widget.mediaMetadata != null && 
               (widget.mediaMetadata!['captured_at'] != null || widget.mediaMetadata!['created_at'] != null)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.mediaType == 'image' ? 'Imagem' : 'Vídeo',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    _formatDateTime(widget.mediaMetadata!['captured_at'] ?? widget.mediaMetadata!['created_at']),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              )
            : Text(
                widget.mediaType == 'image' ? 'Imagem' : 'Vídeo',
                style: const TextStyle(color: Colors.white),
              ),
        actions: [],
      ),
      body: Center(
        child: widget.mediaType == 'video'
            ? _buildVideoPlayer()
            : _buildImageViewer(),
      ),
    );
  }
  
  Widget _buildImageViewer() {
    return PhotoView(
      imageProvider: NetworkImage(widget.mediaUrl),
      minScale: PhotoViewComputedScale.contained * 0.5,
      maxScale: PhotoViewComputedScale.covered * 3.0,
      initialScale: PhotoViewComputedScale.contained,
      basePosition: Alignment.center,
      scaleStateChangedCallback: (PhotoViewScaleState state) {
        debugPrint('PhotoView scale state: $state');
      },
      enableRotation: false,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      heroAttributes: PhotoViewHeroAttributes(tag: widget.mediaUrl),
      loadingBuilder: (context, event) {
        return Center(
          child: CircularProgressIndicator(
            value: event == null ? null : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
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
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
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