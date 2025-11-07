// lib/presentation/screens/media/components/media_details_bottom_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';
import 'package:intl/intl.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_viewer_screen.dart';

class MediaDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> media;
  final String inspectionId;
  final Function(String) onMediaDeleted;

  const MediaDetailsBottomSheet({
    super.key,
    required this.media,
    required this.inspectionId,
    required this.onMediaDeleted,
  });

  @override
  State<MediaDetailsBottomSheet> createState() =>
      _MediaDetailsBottomSheetState();
}

class _MediaDetailsBottomSheetState extends State<MediaDetailsBottomSheet> {
  final _firestore = FirebaseService().firestore;
  final _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isNonConformity = false;
  String _observation = '';
  final _observationController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize with media data
    _isNonConformity = widget.media['is_non_conformity'] == true;
    _observation = widget.media['observation'] ?? '';
    _observationController.text = _observation;
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _deleteMedia() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Mídia'),
        content: const Text(
            'Tem certeza que deseja excluir esta mídia? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final mediaId = widget.media['id'];

      // Parse the composite ID to get the inspection ID
      final parts = mediaId.split('-');
      if (parts.length < 4) {
        throw Exception('Invalid media ID format');
      }

      final inspectionId = parts[0];

      // Get the inspection document
      final inspectionDoc =
          await _firestore.collection('inspections').doc(inspectionId).get();

      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found');
      }

      final data = inspectionDoc.data() ?? {};
      final mediaArray = List<Map<String, dynamic>>.from(data['media'] ?? []);

      // Find the media to delete
      final mediaIndex =
          mediaArray.indexWhere((media) => media['id'] == mediaId);

      if (mediaIndex < 0) {
        throw Exception('Media not found');
      }

      // Delete from storage if URL exists
      if (widget.media['url'] != null) {
        try {
          final storageRef = _storage.refFromURL(widget.media['url']);
          await storageRef.delete();
        } catch (e) {
          debugPrint('Error deleting from storage: $e');
        }
      }

      // Delete local file
      if (widget.media['localPath'] != null) {
        try {
          final file = File(widget.media['localPath']);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting local file: $e');
        }
      }

      // Remove from array
      mediaArray.removeAt(mediaIndex);

      // Update the inspection document
      await _firestore.collection('inspections').doc(inspectionId).update({
        'media': mediaArray,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Notify parent
      widget.onMediaDeleted(mediaId);

      // Close bottom sheet
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mídia excluída com sucesso'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting media: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir mídia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateMedia() async {
    setState(() => _isLoading = true);

    try {
      final mediaId = widget.media['id'];

      // Parse the composite ID to get the inspection ID
      final parts = mediaId.split('-');
      if (parts.length < 4) {
        throw Exception('Invalid media ID format');
      }

      final inspectionId = parts[0];

      // Get the inspection document
      final inspectionDoc =
          await _firestore.collection('inspections').doc(inspectionId).get();

      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found');
      }

      final data = inspectionDoc.data() ?? {};
      final mediaArray = List<Map<String, dynamic>>.from(data['media'] ?? []);

      // Find the media to update
      final mediaIndex =
          mediaArray.indexWhere((media) => media['id'] == mediaId);

      if (mediaIndex < 0) {
        throw Exception('Media not found');
      }

      // Update media data
      mediaArray[mediaIndex]['is_non_conformity'] = _isNonConformity;
      mediaArray[mediaIndex]['observation'] =
          _observation.isEmpty ? null : _observation;
      mediaArray[mediaIndex]['updated_at'] = FieldValue.serverTimestamp();

      // Update the inspection document
      await _firestore.collection('inspections').doc(inspectionId).update({
        'media': mediaArray,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update detail non-conformity status if needed
      if (widget.media['detail_id'] != null) {
        final topicId = widget.media['topic_id'];
        final itemId = widget.media['topic_item_id'];
        final detailId = widget.media['detail_id'];

        final detailsArray =
            List<Map<String, dynamic>>.from(data['details'] ?? []);

        // Find the detail
        final detailIndex = detailsArray.indexWhere((detail) =>
            detail['topic_id'] == topicId &&
            detail['item_id'] == itemId &&
            detail['id'] == detailId);

        if (detailIndex >= 0) {
          detailsArray[detailIndex]['is_damaged'] = _isNonConformity;
          detailsArray[detailIndex]['updated_at'] =
              FieldValue.serverTimestamp();

          await _firestore.collection('inspections').doc(inspectionId).update({
            'details': detailsArray,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mídia atualizada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating media: $e');
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar mídia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Format timestamp
  String _formatDateTime(dynamic timestamp) {
    try {
      DateTime date;

      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Data desconhecida';
      }

      return DateFormat('dd/MM/yyyy HH:mm:ss').format(date);
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return 'Data inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isImage = widget.media['type'] == 'image';
    final bool hasLocalPath = widget.media['localPath'] != null &&
        File(widget.media['localPath']).existsSync();
    final bool hasUrl = widget.media['url'] != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Media display
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media content
                  if (isImage)
                    _buildImageDisplay(hasLocalPath, hasUrl)
                  else
                    _buildVideoDisplay(hasLocalPath, hasUrl),

                  // Media info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location
                        const Text(
                          'Localização:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                  Icons.home_work_outlined,
                                  'Tópico',
                                  widget.media['topic_name'] ??
                                      'Não especificado',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.list_alt,
                                  'Item',
                                  widget.media['item_name'] ??
                                      'Não especificado',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.details,
                                  'Detalhe',
                                  widget.media['detail_name'] ??
                                      'Não especificado',
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Date and non-conformity status
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                Icons.calendar_today,
                                'Data de Captura',
                                _formatDateTime(widget.media['created_at']),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (_isEditing) ...[
                          // Non-conformity switch
                          SwitchListTile(
                            title: const Text('Não Conformidade'),
                            subtitle:
                                const Text('Marcar como item com problema'),
                            value: _isNonConformity,
                            onChanged: (value) {
                              setState(() {
                                _isNonConformity = value;
                              });
                            },
                            activeThumbColor: Colors.red,
                          ),

                          // Observation field
                          const Text(
                            'Observação (opcional):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _observationController,
                            decoration: const InputDecoration(
                              hintText: 'Digite uma observação...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            onChanged: (value) {
                              _observation = value;
                            },
                          ),

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                    _isNonConformity =
                                        widget.media['is_non_conformity'] ==
                                            true;
                                    _observation =
                                        widget.media['observation'] ?? '';
                                    _observationController.text = _observation;
                                  });
                                },
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _updateMedia,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: AdaptiveProgressIndicator(
                                          radius: 8.0,
                                        ),
                                      )
                                    : const Text('Salvar'),
                              ),
                            ],
                          ),
                        ] else ...[
                          Card(
                            elevation: 2,
                            margin: EdgeInsets.zero,
                            color: _isNonConformity ? Colors.red.shade50 : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: _isNonConformity
                                  ? BorderSide(color: Colors.red.shade300)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(
                                    _isNonConformity
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    color: _isNonConformity
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isNonConformity
                                              ? 'Não Conformidade'
                                              : 'Conformidade',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _isNonConformity
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                        ),
                                        if (_observation.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(_observation),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isEditing = !_isEditing;
                          });
                        },
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _isLoading ? null : _deleteMedia,
                  tooltip: 'Excluir',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageDisplay(bool hasLocalPath, bool hasUrl) {
    Widget imageWidget;

    if (hasLocalPath) {
      imageWidget = Image.file(
        File(widget.media['localPath']),
        fit: BoxFit.contain,
        errorBuilder: (ctx, error, _) => _buildErrorContainer(),
      );
    } else if (hasUrl) {
      imageWidget = Image.network(
        widget.media['url'],
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingContainer();
        },
        errorBuilder: (ctx, error, _) => _buildErrorContainer(),
      );
    } else {
      imageWidget = _buildNoSourceContainer('image');
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaViewerScreen(
              mediaItems: [widget.media],
              initialIndex: 0,
            ),
          ),
        );
      },
      child: imageWidget,
    );
  }

  Widget _buildVideoDisplay(bool hasLocalPath, bool hasUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaViewerScreen(
              mediaItems: [widget.media],
              initialIndex: 0,
            ),
          ),
        );
      },
      child: Container(
        height: 300,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Toque para reproduzir vídeo',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContainer() {
    return Container(
      height: 300,
      color: Colors.grey.shade200,
      child: const Center(
        child: AdaptiveProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      height: 300,
      color: Colors.grey.shade200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Erro ao carregar imagem'),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSourceContainer(String type) {
    return Container(
      height: 300,
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'image' ? Icons.image_not_supported : Icons.videocam_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text('Mídia não disponível'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}
