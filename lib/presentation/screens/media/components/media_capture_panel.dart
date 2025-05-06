// lib/presentation/screens/media/components/media_capture_panel.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/services/firebase_storage_service.dart';
import 'package:inspection_app/services/image_watermark_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MediaCapturePanel extends StatefulWidget {
  final String inspectionId;
  final List<Room> rooms;
  final String? selectedRoomId;
  final String? selectedItemId;
  final String? selectedDetailId;
  final Function(String) onMediaAdded;

  const MediaCapturePanel({
    super.key,
    required this.inspectionId,
    required this.rooms,
    this.selectedRoomId,
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
  String? _roomId;
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
    _roomId = widget.selectedRoomId;
    _itemId = widget.selectedItemId;
    _detailId = widget.selectedDetailId;
    
    // Load items and details if room/item is selected
    if (_roomId != null) {
      _loadItems(_roomId!);
    }
    
    if (_roomId != null && _itemId != null) {
      _loadDetails(_roomId!, _itemId!);
    }
  }
  
  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadItems(String roomId) async {
    setState(() => _isLoadingItems = true);
    
    try {
      final items = await _inspectionService.getItems(
        widget.inspectionId,
        roomId,
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
  
  Future<void> _loadDetails(String roomId, String itemId) async {
    setState(() => _isLoadingDetails = true);
    
    try {
      final details = await _inspectionService.getDetails(
        widget.inspectionId,
        roomId,
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
    if (_roomId == null || _itemId == null || _detailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um tópico, item e detalhe primeiro')),
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
    if (_roomId == null || _itemId == null || _detailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um tópico, item e detalhe primeiro')),
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
    if (_roomId == null || _itemId == null || _detailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um tópico, item e detalhe primeiro')),
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
  
  Future<void> _processMedia(String filePath, String type, bool isFromGallery) async {
    try {
      setState(() => _isLoading = true);
      
      // Create a temporary directory for processing
      final timestamp = DateTime.now();
      final fileExt = path.extension(filePath);
      final mediaDir = await getApplicationDocumentsDirectory();
      final directory = Directory('${mediaDir.path}/media');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // Generate a unique filename
      final filename = '${type}_${timestamp.millisecondsSinceEpoch}_${_uuid.v4()}$fileExt';
      final localPath = '${directory.path}/$filename';
      
      // Get original file
      final file = File(filePath);
      
      // Apply watermark
      late File processedFile;
      if (type == 'image') {
        processedFile = await _watermarkService.addWatermarkToImage(
          file,
          isFromGallery: isFromGallery,
          timestamp: timestamp,
        );
      } else {
        processedFile = await _watermarkService.addWatermarkToVideo(
          file,
          isFromGallery: isFromGallery,
          timestamp: timestamp,
        );
      }
      
      // Copy to local path
      if (processedFile.path != localPath) {
        await processedFile.copy(localPath);
      }
      
      // Prepare media metadata
      Map<String, dynamic> mediaData = {
        'inspection_id': widget.inspectionId,
        'room_id': _roomId,
        'room_item_id': _itemId,
        'detail_id': _detailId,
        'type': type,
        'localPath': localPath,
        'is_non_conformity': _isNonConformity,
        'observation': _observation.isEmpty ? null : _observation,
        'created_at': FieldValue.serverTimestamp(),
      };
      
      // Try to upload to Firebase Storage
      try {
        final storagePath = 'inspections/${widget.inspectionId}/$_roomId/$_itemId/$_detailId/$filename';
        
        String? contentType;
        if (fileExt.toLowerCase().contains(RegExp(r'jpg|jpeg|png|gif|webp'))) {
          contentType = 'image/${fileExt.toLowerCase().replaceAll('.', '')}';
        } else if (fileExt.toLowerCase().contains(RegExp(r'mp4|mov|avi'))) {
          contentType = 'video/${fileExt.toLowerCase().replaceAll('.', '')}';
        }
        
        final ref = _storage.ref().child(storagePath);
        final UploadTask uploadTask = ref.putFile(
          File(localPath),
          SettableMetadata(contentType: contentType),
        );
        
        final snapshot = await uploadTask.whenComplete(() {});
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        mediaData['url'] = downloadUrl;
      } catch (e) {
        print('Error uploading to Firebase Storage: $e');
        // Continue without URL, it will be uploaded when online
      }
      
      // Save to Firestore
      await _firestore.collection('media').add(mediaData);
      
      // Update detail if it's a non-conformity
      if (_isNonConformity && _detailId != null) {
        try {
          final detailRef = _firestore.collection('item_details').doc(_detailId);
          await detailRef.update({
            'is_damaged': true,
            'updated_at': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Error updating detail damage status: $e');
        }
      }
      
      // Call the callback
      widget.onMediaAdded(localPath);
      
      // Close the bottom sheet
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == 'image' ? 'Foto' : 'Vídeo'} salvo com sucesso'),
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
    final bool isFormValid = _roomId != null && _itemId != null && _detailId != null;
    final bool isAnyLoading = _isLoading || _isCameraLoading || _isVideoLoading || 
                             _isGalleryLoading || _isVideoGalleryLoading;
    
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
                    fontSize: 18,
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
            
            // Room selector
            const Text('Tópico', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: DropdownButtonFormField<String>(
                value: _roomId,
                isExpanded: true,
                dropdownColor: Colors.grey[800],
                decoration: const InputDecoration(
                  hintText: 'Selecione um tópico',
                  hintStyle: TextStyle(color: Colors.white70),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                items: widget.rooms.map((room) {
                  return DropdownMenuItem<String>(
                    value: room.id,
                    child: Text(room.roomName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _roomId = value;
                    _itemId = null;
                    _detailId = null;
                    _items = [];
                    _details = [];
                  });
                  
                  if (value != null) {
                    _loadItems(value);
                  }
                },
                validator: (value) => value == null ? 'Selecione um tópico' : null,
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
                      onChanged: _roomId == null
                          ? null
                          : (value) {
                              setState(() {
                                _itemId = value;
                                _detailId = null;
                                _details = [];
                              });
                              
                              if (value != null && _roomId != null) {
                                _loadDetails(_roomId!, value);
                              }
                            },
                      validator: (value) => value == null ? 'Selecione um item' : null,
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
                      validator: (value) => value == null ? 'Selecione um detalhe' : null,
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
                title: const Text('Não Conformidade',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text('Marcar como item com problema',
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
            const Text('Observação (opcional)', style: TextStyle(color: Colors.white70)),
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
                    onPressed: isFormValid && !isAnyLoading
                        ? _captureImage
                        : null,
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
                    onPressed: isFormValid && !isAnyLoading
                        ? _captureVideo
                        : null,
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
                    fontStyle: FontStyle.italic, 
                    color: Colors.white70
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