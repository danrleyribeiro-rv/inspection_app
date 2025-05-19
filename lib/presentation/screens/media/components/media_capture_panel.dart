// lib/presentation/screens/media/components/media_capture_panel.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/image_watermark_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final _firestore = FirebaseService().firestore;
  final _inspectionService = FirebaseInspectionService();
  final _watermarkService = ImageWatermarkService();
  final _storage = FirebaseStorage.instance;
  final _uuid = Uuid();

  // Local state
  String? _topicId;
  String? _itemId;
  String? _detailId;
  bool _isNonConformity = false;
  String _observation = '';

  // Data lists
  List<Item> _items = [];
  List<Detail> _details = [];

  // Loading flags
  bool _isLoading = false;
  bool _isLoadingItems = false;
  bool _isLoadingDetails = false;
  bool _isCameraLoading = false;
  bool _isVideoLoading = false;
  bool _isGalleryLoading = false;
  bool _isVideoGalleryLoading = false;

  // Form key
  final _formKey = GlobalKey<FormState>();
  final _observationController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize with provided values
    _topicId = widget.selectedTopicId;
    _itemId = widget.selectedItemId;
    _detailId = widget.selectedDetailId;

    // Load items and details if topic/item is selected
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
      final items = await _inspectionService.getItems(
        widget.inspectionId,
        topicId,
      );

      setState(() {
        _items = items;
        _isLoadingItems = false;
      });
    } catch (e) {
      print('Error loading items: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _loadDetails(String topicId, String itemId) async {
    setState(() => _isLoadingDetails = true);

    try {
      final details = await _inspectionService.getDetails(
        widget.inspectionId,
        topicId,
        itemId,
      );

      setState(() {
        _details = details;
        _isLoadingDetails = false;
      });
    } catch (e) {
      print('Error loading details: $e');
      setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _captureImage() async {
    if (_topicId == null || _itemId == null || _detailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione um tópico, item e detalhe primeiro')),
      );
      return;
    }

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
      print('Error capturing image: $e');
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
    if (_topicId == null || _itemId == null || _detailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione um tópico, item e detalhe primeiro')),
      );
      return;
    }

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
      print('Error capturing video: $e');
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
    if (_topicId == null || _itemId == null || _detailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione um tópico, item e detalhe primeiro')),
      );
      return;
    }

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
      print('Error picking from gallery: $e');
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

  Future<void> _processMedia(
      String filePath, String type, bool isFromGallery) async {
    try {
      setState(() => _isLoading = true);

      // Create a unique filename and path
      final ext = path.extension(filePath);
      final fileName =
          '${widget.inspectionId}_${_topicId}_${_itemId}_${_detailId}_${_uuid.v4().substring(0, 8)}$ext';
      final appDir = await getApplicationDocumentsDirectory();
      final localPath = path.join(appDir.path, fileName);

      // Apply watermarks and process the file
      if (type == 'image') {
        // Optionally apply watermark
        final watermarkedFile =
            await _watermarkService.applyWatermark(filePath, localPath);
        // If watermarking failed, fallback to copy
        if (watermarkedFile == null) {
          await File(filePath).copy(localPath);
        }
      } else {
        // For video, just copy
        await File(filePath).copy(localPath);
      }

      // Prepare media data
      final mediaId = _uuid.v4();

      Map<String, dynamic> mediaData = {
        'type': type,
        'localPath': localPath,
        'is_non_conformity': _isNonConformity,
        'observation': _observation.isEmpty ? null : _observation,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Try to upload to Firebase Storage
      try {
        // Upload to Firebase Storage
        final storageRef =
            _storage.ref().child('inspection_media').child(fileName);
        await storageRef.putFile(File(localPath));
        final downloadUrl = await storageRef.getDownloadURL();

        mediaData['url'] = downloadUrl;
      } catch (e) {
        print('Error uploading to Firebase Storage: $e');
        // Continue without URL, it will be uploaded when online
      }

      // Salvar na subcoleção 'media' do detalhe
      await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .collection('topics')
          .doc(_topicId)
          .collection('topic_items')
          .doc(_itemId)
          .collection('item_details')
          .doc(_detailId)
          .collection('media')
          .doc(mediaId)
          .set(mediaData);

      // Update detail if it's a non-conformity
      if (_isNonConformity) {
        await _firestore
            .collection('inspections')
            .doc(widget.inspectionId)
            .collection('topics')
            .doc(_topicId)
            .collection('topic_items')
            .doc(_itemId)
            .collection('item_details')
            .doc(_detailId)
            .update({'is_damaged': true});
      }

      // Call the callback
      widget.onMediaAdded(localPath);

      // Close the bottom sheet
      if (mounted) {
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${type == 'image' ? 'Foto' : 'Vídeo'} salvo com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error processing media: $e');
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
    final bool isFormValid =
        _topicId != null && _itemId != null && _detailId != null;
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
        color: Color(0xFF1E293B), // Slate background to match theme
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
                    fontSize: 16,
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

            // Item selector
            const Text('Item', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            _isLoadingItems
                ? const LinearProgressIndicator(color: Colors.blue)
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
                ? const LinearProgressIndicator(color: Colors.blue)
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
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
                _observation = value;
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
                      backgroundColor: Colors.blue,
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
                      side: const BorderSide(color: Colors.blue),
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
              const LinearProgressIndicator(color: Colors.blue),
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
