// lib/presentation/screens/media/components/media_capture_panel.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lince_inspecoes/models/topic.dart';
import 'package:lince_inspecoes/models/item.dart';
import 'package:lince_inspecoes/models/detail.dart';
import 'package:lince_inspecoes/models/offline_media.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class MediaCapturePanel extends StatefulWidget {
  final String inspectionId;
  final List<Topic> topics;
  final String? selectedTopicId;
  final String? selectedItemId;
  final String? selectedDetailId;
  final Function(String) onMediaAdded;

  const MediaCapturePanel({
    super.key,
    required this.inspectionId,
    required this.topics,
    this.selectedTopicId,
    this.selectedItemId,
    this.selectedDetailId,
    required this.onMediaAdded,
  });

  @override
  State<MediaCapturePanel> createState() => _MediaCapturePanelState();
}

class _MediaCapturePanelState extends State<MediaCapturePanel> {
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;

  String? _topicId;
  String? _itemId;
  String? _detailId;
  bool _isNonConformity = false;
  // String _observation = ''; // Removed - not used
  bool _topicOnly = false;

  List<Item> _items = [];
  List<Detail> _details = [];

  bool _isLoading = false;
  bool _isLoadingItems = false;
  bool _isLoadingDetails = false;
  bool _isCameraLoading = false;
  bool _isVideoLoading = false;
  bool _isGalleryLoading = false;
  bool _isVideoGalleryLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _observationController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _topicId = widget.selectedTopicId;
    _itemId = widget.selectedItemId;
    _detailId = widget.selectedDetailId;

    if (_topicId != null) {
      _loadItems(_topicId!);
    }

    if (_topicId != null && _itemId != null) {
      _loadDetails(_topicId!, _itemId!);
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadItems(String topicId) async {
    setState(() => _isLoadingItems = true);

    try {
      final items = await _serviceFactory.dataService.getItems(topicId);

      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    } catch (e) {
      debugPrint('Error loading items: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadDetails(String topicId, String itemId) async {
    setState(() => _isLoadingDetails = true);

    try {
      final details = await _serviceFactory.dataService.getDetails(itemId);

      setState(() {
        _details = details;
        _isLoadingDetails = false;
      });
    } catch (e) {
      debugPrint('Error loading details: $e');
      setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _captureImage() async {
    if (!_validateSelection()) return;

    setState(() => _isCameraLoading = true);

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        setState(() => _isCameraLoading = false);
        return;
      }

      await _processMedia(pickedFile.path, 'image', false);
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar imagem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCameraLoading = false);
      }
    }
  }

  Future<void> _captureVideo() async {
    if (!_validateSelection()) return;

    setState(() => _isVideoLoading = true);

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 1),
      );

      if (pickedFile == null) {
        setState(() => _isVideoLoading = false);
        return;
      }

      await _processMedia(pickedFile.path, 'video', false);
    } catch (e) {
      debugPrint('Error capturing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar vídeo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVideoLoading = false);
      }
    }
  }

  Future<void> _pickFromGallery(bool isVideo) async {
    if (!_validateSelection()) return;

    setState(() {
      if (isVideo) {
        _isVideoGalleryLoading = true;
      } else {
        _isGalleryLoading = true;
      }
    });

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = isVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1200,
              maxHeight: 800,
              imageQuality: 80,
            );

      if (pickedFile == null) {
        setState(() {
          if (isVideo) {
            _isVideoGalleryLoading = false;
          } else {
            _isGalleryLoading = false;
          }
        });
        return;
      }

      await _processMedia(
        pickedFile.path,
        isVideo ? 'video' : 'image',
        true,
      );
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar da galeria: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isVideo) {
            _isVideoGalleryLoading = false;
          } else {
            _isGalleryLoading = false;
          }
        });
      }
    }
  }

  bool _validateSelection() {
    if (_topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um tópico primeiro')),
      );
      return false;
    }

    if (!_topicOnly && _itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um item primeiro')),
      );
      return false;
    }

    if (!_topicOnly && _detailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um detalhe primeiro')),
      );
      return false;
    }

    return true;
  }

  Future<void> _processMedia(
      String filePath, String type, bool isFromGallery) async {
    try {
      setState(() => _isLoading = true);

      // Usar o novo sistema OfflineMedia
      final OfflineMedia offlineMedia;
      if (type == 'image') {
        offlineMedia = await _serviceFactory.mediaService.capturePhoto(
          imageFile: XFile(filePath),
          inspectionId: widget.inspectionId,
          topicId:
              _topicOnly ? _topicId : (_detailId != null ? _topicId : null),
          itemId: _detailId != null ? _itemId : null,
          detailId: _detailId,
          nonConformityId: _isNonConformity ? 'temp_nc_id' : null,
        );
      } else {
        offlineMedia = await _serviceFactory.mediaService.captureVideo(
          videoFile: XFile(filePath),
          inspectionId: widget.inspectionId,
          topicId:
              _topicOnly ? _topicId : (_detailId != null ? _topicId : null),
          itemId: _detailId != null ? _itemId : null,
          detailId: _detailId,
          nonConformityId: _isNonConformity ? 'temp_nc_id' : null,
        );
      }

      // Notificar o componente pai sobre a nova mídia
      widget.onMediaAdded(offlineMedia.localPath);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${type == 'image' ? 'Foto' : 'Vídeo'} salvo com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error processing media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar mídia: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (código existente sem alterações)
    final bool isFormValid = _topicId != null &&
        (_topicOnly || (_itemId != null && _detailId != null));
    final bool isAnyLoading = _isLoading ||
        _isCameraLoading ||
        _isVideoLoading ||
        _isGalleryLoading ||
        _isVideoGalleryLoading;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF312456),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Capturar Nova Mídia',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Topic selector
            const Text('Tópico', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: DropdownButtonFormField<String>(
                value: _topicId,
                isExpanded: true,
                dropdownColor: Colors.grey[800],
                decoration: const InputDecoration(
                  hintText: 'Selecione um tópico',
                  hintStyle: TextStyle(color: Colors.white70),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                items: widget.topics.map((topic) {
                  return DropdownMenuItem<String>(
                    value: topic.id,
                    child: Text(topic.topicName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _topicId = value;
                    _itemId = null;
                    _detailId = null;
                    _items = [];
                    _details = [];
                    _topicOnly = false;
                  });

                  if (value != null) {
                    _loadItems(value);
                  }
                },
                validator: (value) =>
                    value == null ? 'Selecione um tópico' : null,
              ),
            ),
            const SizedBox(height: 16),

            // Checkbox para "Apenas Tópico"
            if (_topicId != null)
              CheckboxListTile(
                title: const Text(
                  'Registrar apenas no Tópico',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Mídia será associada apenas ao tópico selecionado',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                value: _topicOnly,
                onChanged: (value) {
                  setState(() {
                    _topicOnly = value ?? false;
                    if (_topicOnly) {
                      _itemId = null;
                      _detailId = null;
                    }
                  });
                },
                activeColor: const Color(0xFF6F4B99),
              ),

            // Item selector
            if (!_topicOnly) ...[
              const Text('Item', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              _isLoadingItems
                  ? const LinearProgressIndicator(color: Color(0xFF6F4B99))
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _itemId,
                        isExpanded: true,
                        dropdownColor: Colors.grey[800],
                        decoration: const InputDecoration(
                          hintText: 'Selecione um item',
                          hintStyle: TextStyle(color: Colors.white70),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(color: Colors.white),
                        items: _items.map((item) {
                          return DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.itemName),
                          );
                        }).toList(),
                        onChanged: _topicId == null
                            ? null
                            : (value) {
                                setState(() {
                                  _itemId = value;
                                  _detailId = null;
                                  _details = [];
                                });

                                if (value != null && _topicId != null) {
                                  _loadDetails(_topicId!, value);
                                }
                              },
                        validator: (value) =>
                            value == null ? 'Selecione um item' : null,
                      ),
                    ),
              const SizedBox(height: 16),

              // Detail selector
              const Text('Detalhe', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              _isLoadingDetails
                  ? const LinearProgressIndicator(color: Color(0xFF6F4B99))
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _detailId,
                        isExpanded: true,
                        dropdownColor: Colors.grey[800],
                        decoration: const InputDecoration(
                          hintText: 'Selecione um detalhe',
                          hintStyle: TextStyle(color: Colors.white70),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(color: Colors.white),
                        items: _details.map((detail) {
                          return DropdownMenuItem<String>(
                            value: detail.id,
                            child: Text(detail.detailName),
                          );
                        }).toList(),
                        onChanged: _itemId == null
                            ? null
                            : (value) {
                                setState(() {
                                  _detailId = value;
                                });
                              },
                        validator: (value) =>
                            value == null ? 'Selecione um detalhe' : null,
                      ),
                    ),
              const SizedBox(height: 16),
            ],

            // Non-conformity flag
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Não Conformidade',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Marcar como item com problema',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                value: _isNonConformity,
                onChanged: (value) {
                  setState(() {
                    _isNonConformity = value;
                  });
                },
                activeColor: Colors.orange,
              ),
            ),

            // Observation field
            const SizedBox(height: 16),
            const Text('Observação (opcional)',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _observationController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Digite uma observação...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
              ),
              maxLines: 2,
              onChanged: (value) {
                // _observation = value; // Removed - not used
              },
            ),
            const SizedBox(height: 24),

            // Camera and gallery buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isFormValid && !isAnyLoading ? _captureImage : null,
                    icon: _isCameraLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.camera_alt),
                    label: const Text('Tirar Foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F4B99),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isFormValid && !isAnyLoading ? _captureVideo : null,
                    icon: _isVideoLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.videocam),
                    label: const Text('Gravar Vídeo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isFormValid && !isAnyLoading
                        ? () => _pickFromGallery(false)
                        : null,
                    icon: _isGalleryLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.photo_library),
                    label: const Text('Galeria Fotos'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF6F4B99)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isFormValid && !isAnyLoading
                        ? () => _pickFromGallery(true)
                        : null,
                    icon: _isVideoGalleryLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.video_library),
                    label: const Text('Galeria Vídeos'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.purple),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(color: Color(0xFF6F4B99)),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Processando mídia...',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
