// lib/presentation/widgets/media/native_camera_widget.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class NativeCameraWidget extends StatefulWidget {
  final Function(List<String>) onImagesSelected;
  final bool allowMultiple;
  final String? inspectionId;
  final String? topicId;
  final String? itemId;
  final String? detailId;

  const NativeCameraWidget({
    super.key,
    required this.onImagesSelected,
    this.allowMultiple = true,
    this.inspectionId,
    this.topicId,
    this.itemId,
    this.detailId,
  });

  @override
  State<NativeCameraWidget> createState() => _NativeCameraWidgetState();
}

class _NativeCameraWidgetState extends State<NativeCameraWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capturar Imagens'),
        backgroundColor: const Color(0xFF312456),
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 80,
              color: Color(0xFF312456),
            ),
            const SizedBox(height: 24),
            const Text(
              'Capturar Imagens',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF312456),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.allowMultiple 
                  ? 'Tire várias fotos para documentar a inspeção.\nTodas as imagens serão convertidas para formato 4:3 paisagem.'
                  : 'Tire uma foto para documentar a inspeção.\nA imagem será convertida para formato 4:3 paisagem.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            
            if (_isProcessing) ...[
              const CircularProgressIndicator(
                color: Color(0xFF312456),
              ),
              const SizedBox(height: 16),
              const Text('Processando imagens...'),
            ] else ...[
              // Camera Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _captureFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Usar Câmera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF312456),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Gallery Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _selectFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: Text(widget.allowMultiple ? 'Escolher da Galeria' : 'Escolher Foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF312456),
                    side: const BorderSide(color: Color(0xFF312456)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Formato Automático',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Todas as imagens são automaticamente convertidas para formato 4:3 em modo paisagem para garantir consistência.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    try {
      setState(() => _isProcessing = true);

      if (widget.allowMultiple) {
        // Para múltiplas imagens, capture uma por vez em um loop
        final images = <String>[];
        bool continueTaking = true;

        while (continueTaking && images.length < 10) { // Limite de 10 imagens
          final XFile? image = await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 90,
          );

          if (image != null) {
            final processedImagePath = await _processImageTo4x3Landscape(image.path);
            if (processedImagePath != null) {
              images.add(processedImagePath);
            }

            if (mounted) {
              // Perguntar se quer tirar mais fotos
              continueTaking = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('${images.length} foto(s) capturada(s)'),
                  content: const Text('Deseja tirar mais fotos?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Concluir'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Mais Fotos'),
                    ),
                  ],
                ),
              ) ?? false;
            }
          } else {
            continueTaking = false;
          }
        }

        if (images.isNotEmpty) {
          widget.onImagesSelected(images);
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        // Captura única
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );

        if (image != null) {
          final processedImagePath = await _processImageTo4x3Landscape(image.path);
          if (processedImagePath != null) {
            widget.onImagesSelected([processedImagePath]);
            if (mounted) Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Error capturing from camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao capturar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      setState(() => _isProcessing = true);

      if (widget.allowMultiple) {
        final List<XFile> images = await _picker.pickMultiImage(
          imageQuality: 90,
        );

        if (images.isNotEmpty) {
          final processedImages = <String>[];
          
          for (final image in images) {
            final processedImagePath = await _processImageTo4x3Landscape(image.path);
            if (processedImagePath != null) {
              processedImages.add(processedImagePath);
            }
          }

          if (processedImages.isNotEmpty) {
            widget.onImagesSelected(processedImages);
            if (mounted) Navigator.of(context).pop();
          }
        }
      } else {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );

        if (image != null) {
          final processedImagePath = await _processImageTo4x3Landscape(image.path);
          if (processedImagePath != null) {
            widget.onImagesSelected([processedImagePath]);
            if (mounted) Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Error selecting from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Converte qualquer imagem para formato 4:3 em modo paisagem
  Future<String?> _processImageTo4x3Landscape(String imagePath) async {
    try {
      // Ler a imagem original
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        debugPrint('Failed to decode image: $imagePath');
        return null;
      }

      // Garantir que a imagem está em modo paisagem
      img.Image landscapeImage = originalImage;
      if (originalImage.width < originalImage.height) {
        // Rotacionar 90 graus para modo paisagem
        landscapeImage = img.copyRotate(originalImage, angle: 90);
      }

      // Calcular dimensões para aspecto 4:3 em modo paisagem
      const double targetAspectRatio = 4.0 / 3.0;
      
      int targetWidth, targetHeight;
      int cropX = 0, cropY = 0;

      final double currentAspectRatio = landscapeImage.width / landscapeImage.height;

      if (currentAspectRatio > targetAspectRatio) {
        // Imagem muito larga - cortar nas laterais
        targetHeight = landscapeImage.height;
        targetWidth = (targetHeight * targetAspectRatio).round();
        cropX = (landscapeImage.width - targetWidth) ~/ 2;
      } else {
        // Imagem muito alta - cortar em cima e embaixo
        targetWidth = landscapeImage.width;
        targetHeight = (targetWidth / targetAspectRatio).round();
        cropY = (landscapeImage.height - targetHeight) ~/ 2;
      }

      // Cortar a imagem para 4:3
      final img.Image croppedImage = img.copyCrop(
        landscapeImage,
        x: cropX,
        y: cropY,
        width: targetWidth,
        height: targetHeight,
      );

      // Redimensionar para um tamanho padrão se necessário (opcional)
      const int maxWidth = 1200;
      img.Image finalImage = croppedImage;
      if (croppedImage.width > maxWidth) {
        final int newHeight = (maxWidth / targetAspectRatio).round();
        finalImage = img.copyResize(
          croppedImage,
          width: maxWidth,
          height: newHeight,
        );
      }

      // Salvar a imagem processada
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String processedPath = path.join(tempDir.path, fileName);
      
      final File processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(finalImage, quality: 90));

      debugPrint('Image processed successfully: $processedPath (${finalImage.width}x${finalImage.height})');
      return processedPath;

    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }
}