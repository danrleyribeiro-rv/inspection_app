import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaCaptureDialog extends StatelessWidget {
  final Function(String filePath, String type) onMediaCaptured;

  const MediaCaptureDialog({
    super.key,
    required this.onMediaCaptured,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Capturar Mídia',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Opção Foto
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text(
                'Foto',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Capturar uma foto',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => _capturePhoto(context),
            ),
            
            const SizedBox(height: 8),
            
            // Opção Vídeo
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam, color: Colors.red),
              ),
              title: const Text(
                'Vídeo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Gravar um vídeo',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () => _captureVideo(context),
            ),
            
            const SizedBox(height: 16),
            
            // Botão Cancelar
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(BuildContext context) async {
    Navigator.of(context).pop(); // Fechar o diálogo
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        onMediaCaptured(photo.path, 'image');
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    }
  }

  Future<void> _captureVideo(BuildContext context) async {
    Navigator.of(context).pop(); // Fechar o diálogo
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        onMediaCaptured(video.path, 'video');
      }
    } catch (e) {
      debugPrint('Error capturing video: $e');
    }
  }
}