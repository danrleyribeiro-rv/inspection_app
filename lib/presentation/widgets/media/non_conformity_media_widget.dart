// lib/presentation/widgets/media/non_conformity_media_widget.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/models/non_conformity.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/non_conformity_edit_dialog.dart';

class NonConformityMediaWidget extends StatefulWidget {
  final String inspectionId;
  final int topicIndex;
  final int itemIndex;
  final int detailIndex;
  final int ncIndex;
  final bool isReadOnly;
  final Function(String) onMediaAdded;
  final Function()? onNonConformityUpdated;

  const NonConformityMediaWidget({
    super.key,
    required this.inspectionId,
    required this.topicIndex,
    required this.itemIndex,
    required this.detailIndex,
    required this.ncIndex,
    this.isReadOnly = false,
    required this.onMediaAdded,
    this.onNonConformityUpdated,
  });

  @override
  State<NonConformityMediaWidget> createState() =>
      _NonConformityMediaWidgetState();
}

class _NonConformityMediaWidgetState extends State<NonConformityMediaWidget> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  int _processingCount = 0;

  void _showCameraCapture() {
    _showMediaSourceDialog();
  }

  void _showMediaSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
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
            const Text(
              'Adicionar Mídia NC',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title:
                  const Text('Câmera', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Tirar foto com a câmera',
                  style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.of(context).pop();
                _captureFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title:
                  const Text('Galeria', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Escolher foto da galeria',
                  style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.of(context).pop();
                _selectFromGallery();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image != null) {
        await _handleCameraCapture(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar imagem: $e')),
        );
      }
    }
  }

  Future<void> _selectFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 90,
      );

      if (images.isNotEmpty) {
        for (final image in images) {
          await _handleGallerySelection(image);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagens: $e')),
        );
      }
    }
  }

  Future<void> _editNonConformity() async {
    try {
      // Buscar a não conformidade específica
      final hierarchyIds = await _getHierarchyIds();
      final nonConformityId =
          '${widget.inspectionId}-${hierarchyIds['topicId']}-${hierarchyIds['itemId']}-${hierarchyIds['detailId']}-nc_${widget.ncIndex}';

      // Buscar todas as não conformidades para encontrar a específica
      final allNonConformitiesObjects = await _serviceFactory.dataService
          .getNonConformities(widget.inspectionId);
      final allNonConformities =
          allNonConformitiesObjects.map((nc) => nc.toJson()).toList();

      Map<String, dynamic>? targetNC;
      for (final nc in allNonConformities) {
        String currentNcId = nc['id'] ?? '';
        if (!currentNcId.contains('-')) {
          currentNcId =
              '${widget.inspectionId}-${nc['topic_id']}-${nc['item_id']}-${nc['detail_id']}-$currentNcId';
        }
        if (currentNcId == nonConformityId) {
          targetNC = nc;
          break;
        }
      }

      if (targetNC != null && mounted) {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => NonConformityEditDialog(
            nonConformity: targetNC!,
            onSave: (updatedData) {
              Navigator.of(context).pop(updatedData);
            },
          ),
        );

        if (result != null) {
          // Atualizar a não conformidade
          final nonConformity = NonConformity(
            id: nonConformityId,
            inspectionId: result['inspection_id'] ?? widget.inspectionId,
            topicId: result['topic_id'],
            itemId: result['item_id'],
            detailId: result['detail_id'],
            title: result['title'] ?? '',
            description: result['description'] ?? '',
            severity: result['severity'] ?? 'medium',
            status: result['status'] ?? 'open',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            needsSync: true,
            isDeleted: false,
          );
          await _serviceFactory.dataService.updateNonConformity(nonConformity);

          // Notificar o parent para atualizar a UI
          widget.onNonConformityUpdated?.call();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não conformidade atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade não encontrada'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error editing non-conformity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao editar não conformidade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openNonConformityMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
          initialTopicId: 'topic_${widget.topicIndex}',
          initialItemId: 'item_${widget.itemIndex}',
          initialDetailId: 'detail_${widget.detailIndex}',
          initialIsNonConformityOnly: true, // Filtro explícito para NC
          initialMediaType: null,
        ),
      ),
    );
  }

  Future<void> _handleCameraCapture(XFile imageFile) async {
    if (mounted) {
      setState(() {
        _processingCount++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processando imagem da câmera para NC...'),
          backgroundColor: Colors.blue,
        ),
      );
    }

    try {
      final hierarchyIds = await _getHierarchyIds();
      
      // Gerar ID específico para a não conformidade
      final nonConformityId = 'nc_${DateTime.now().millisecondsSinceEpoch}';
      
      final media = await _serviceFactory.mediaService.capturePhoto(
        inspectionId: widget.inspectionId,
        topicId: hierarchyIds['topicId'],
        itemId: hierarchyIds['itemId'],
        detailId: hierarchyIds['detailId'],
        nonConformityId: nonConformityId,
        imageFile: imageFile,
        metadata: {
          'source': 'camera',
          'is_non_conformity': true,
          'nc_index': widget.ncIndex,
        },
      );
      
      widget.onMediaAdded(media.id);
      
      if (mounted) {
        // NOVA REGRA: Ir direto para galeria IMEDIATAMENTE após capturar mídia em NC
        debugPrint('NonConformityMediaWidget: IMMEDIATELY navigating to gallery for NC');
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaGalleryScreen(
              inspectionId: widget.inspectionId,
              initialTopicId: hierarchyIds['topicId'],
              initialItemId: hierarchyIds['itemId'],
              initialDetailId: hierarchyIds['detailId'],
              initialIsNonConformityOnly: true, // Filtro explícito para NC
            ),
          ),
        );

        // Mostrar mensagem após um pequeno delay para não interferir na navegação
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Imagem de NC capturada com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error capturing NC photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao capturar imagem de NC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingCount--;
        });
      }
    }
  }

  Future<void> _handleGallerySelection(XFile imageFile) async {
    if (mounted) {
      setState(() {
        _processingCount++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processando imagem da galeria para NC...'),
          backgroundColor: Colors.blue,
        ),
      );
    }

    try {
      final hierarchyIds = await _getHierarchyIds();
      
      // Gerar ID específico para a não conformidade
      final nonConformityId = 'nc_${DateTime.now().millisecondsSinceEpoch}';
      
      final media = await _serviceFactory.mediaService.importMedia(
        inspectionId: widget.inspectionId,
        topicId: hierarchyIds['topicId'],
        itemId: hierarchyIds['itemId'],
        detailId: hierarchyIds['detailId'],
        nonConformityId: nonConformityId,
        filePath: imageFile.path,
        type: 'image',
        source: 'gallery',
        metadata: {
          'source': 'gallery',
          'is_non_conformity': true,
          'nc_index': widget.ncIndex,
        },
      );
      
      widget.onMediaAdded(media.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem de NC importada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error importing NC image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar imagem de NC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingCount--;
        });
      }
    }
  }

  Future<Map<String, String?>> _getHierarchyIds() async {
    try {
      final inspection =
          await _serviceFactory.dataService.getInspection(widget.inspectionId);
      if (inspection?.topics == null) {
        return {
          'topicId': 'topic_${widget.topicIndex}',
          'itemId': 'item_${widget.itemIndex}',
          'detailId': 'detail_${widget.detailIndex}'
        };
      }

      String? topicId;
      String? itemId;
      String? detailId;

      if (widget.topicIndex < inspection!.topics!.length) {
        final topic = inspection.topics![widget.topicIndex];
        topicId = topic['id'] ?? 'topic_${widget.topicIndex}';

        final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
        if (widget.itemIndex < items.length) {
          final item = items[widget.itemIndex];
          itemId = item['id'] ?? 'item_${widget.itemIndex}';

          final details =
              List<Map<String, dynamic>>.from(item['details'] ?? []);
          if (widget.detailIndex < details.length) {
            final detail = details[widget.detailIndex];
            detailId = detail['id'] ?? 'detail_${widget.detailIndex}';
          }
        }
      }

      return {
        'topicId': topicId ?? 'topic_${widget.topicIndex}',
        'itemId': itemId ?? 'item_${widget.itemIndex}',
        'detailId': detailId ?? 'detail_${widget.detailIndex}',
      };
    } catch (e) {
      debugPrint('Error getting hierarchy IDs: $e');
      return {
        'topicId': 'topic_${widget.topicIndex}',
        'itemId': 'item_${widget.itemIndex}',
        'detailId': 'detail_${widget.detailIndex}'
      };
    }
  }

  // Method removed - media is now handled directly by the service

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isReadOnly)
          const SizedBox.shrink()
        else
          Column(
            children: [
              if (_processingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text("Processando $_processingCount NC(s)...",
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label:
                          const Text('Capturar', style: TextStyle(fontSize: 8)),
                      onPressed: _showCameraCapture,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Ver Galeria',
                          style: TextStyle(fontSize: 8)),
                      onPressed: _openNonConformityMediaGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar NC',
                          style: TextStyle(fontSize: 8)),
                      onPressed: _editNonConformity,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
