// lib/presentation/screens/media/media_gallery_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/services/firebase_service.dart';
import 'package:inspection_app/presentation/screens/media/components/media_filter_panel.dart';
import 'package:inspection_app/presentation/screens/media/components/media_grid.dart';
import 'package:inspection_app/presentation/screens/media/components/media_capture_panel.dart';
import 'package:inspection_app/presentation/screens/media/components/media_details_bottom_sheet.dart';

class MediaGalleryScreen extends StatefulWidget {
  final String inspectionId;

  const MediaGalleryScreen({
    super.key,
    required this.inspectionId,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  final _firestore = FirebaseService().firestore;
  final _inspectionService = FirebaseInspectionService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allMedia = [];
  List<Map<String, dynamic>> _filteredMedia = [];
  List<Topic> _topics = [];

  // Filter states
  String? _selectedTopicId;
  String? _selectedItemId;
  String? _selectedDetailId;
  bool? _isNonConformityOnly;
  String? _mediaType;

  // Helper to convert various date formats to DateTime
  DateTime? _getDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load topics, which will be needed for filtering
      final topics = await _inspectionService.getTopics(widget.inspectionId);

      // Get the inspection document
      final inspectionDoc = await _firestore
          .collection('inspections')
          .doc(widget.inspectionId)
          .get();

      if (!inspectionDoc.exists) {
        throw Exception('Inspection not found');
      }

      final data = inspectionDoc.data() ?? {};
      final mediaArray = data['media'] as List<dynamic>? ?? [];

      // Convert to list of maps
      final media = await Future.wait(mediaArray.map((mediaData) async {
        String? topicName;
        String? itemName;
        String? detailName;
        bool isNonConformity = false;

        final topicId = mediaData['topic_id'];
        final itemId = mediaData['topic_item_id'];
        final detailId = mediaData['detail_id'];

        // Get topic name
        if (topicId != null) {
          final topicsArray = data['topics'] as List<dynamic>? ?? [];
          final topic = topicsArray.firstWhere(
            (topic) => topic['id'] == topicId,
            orElse: () => null,
          );

          if (topic != null) {
            topicName = topic['topic_name'];
          }
        }

// Get item name
        if (topicId != null && itemId != null) {
          final itemsArray = data['items'] as List<dynamic>? ?? [];
          final item = itemsArray.firstWhere(
            (item) => item['topic_id'] == topicId && item['id'] == itemId,
            orElse: () => null,
          );

          if (item != null) {
            itemName = item['item_name'];
          }
        }

        // Get detail name and check non-conformity status
        if (topicId != null && itemId != null && detailId != null) {
          final detailsArray = data['details'] as List<dynamic>? ?? [];
          final detail = detailsArray.firstWhere(
            (detail) =>
                detail['topic_id'] == topicId &&
                detail['item_id'] == itemId &&
                detail['id'] == detailId,
            orElse: () => null,
          );

          if (detail != null) {
            detailName = detail['detail_name'];
            // Check if detail is marked as damaged
            isNonConformity = detail['is_damaged'] == true;
          }

          // Also check non_conformities collection
          final nonConformitiesArray =
              data['non_conformities'] as List<dynamic>? ?? [];
          final hasNonConformity = nonConformitiesArray.any((nc) =>
              nc['topic_id'] == topicId &&
              nc['item_id'] == itemId &&
              nc['detail_id'] == detailId);

          if (hasNonConformity) {
            isNonConformity = true;
          }
        }

        // Check if this media is specifically marked as non-conformity
        if (mediaData['is_non_conformity'] == true) {
          isNonConformity = true;
        }

        return {
          ...Map<String, dynamic>.from(mediaData),
          'topic_name': topicName,
          'item_name': itemName,
          'detail_name': detailName,
          'is_non_conformity': isNonConformity,
        };
      }));

      // Sort by created_at descending
      media.sort((a, b) {
        final aDate = _getDateTime(a['created_at']) ?? DateTime.now();
        final bDate = _getDateTime(b['created_at']) ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _topics = topics;
          _allMedia = media;
          _filteredMedia = List.from(media);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading media data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar mídia: $e')),
        );
      }
    }
  }

  void _applyFilters({
    String? topicId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) {
    setState(() {
      _selectedTopicId = topicId;
      _selectedItemId = itemId;
      _selectedDetailId = detailId;
      _isNonConformityOnly = isNonConformityOnly;
      _mediaType = mediaType;

      // Apply filters
      _filteredMedia = _allMedia.where((media) {
        // Filter by topic if selected
        if (topicId != null && media['topic_id'] != topicId) {
          return false;
        }

        // Filter by item if selected
        if (itemId != null && media['topic_item_id'] != itemId) {
          return false;
        }

        // Filter by detail if selected
        if (detailId != null && media['detail_id'] != detailId) {
          return false;
        }

        // Filter by non-conformity status if selected
        if (isNonConformityOnly == true &&
            !(media['is_non_conformity'] == true)) {
          return false;
        }

        // Filter by media type if selected
        if (mediaType != null && media['type'] != mediaType) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedTopicId = null;
      _selectedItemId = null;
      _selectedDetailId = null;
      _isNonConformityOnly = null;
      _mediaType = null;
      _filteredMedia = List.from(_allMedia);
    });
  }

  Future<void> _handleMediaAdded(String localPath) async {
    await _loadData(); // Reload all data
  }

  void _showMediaDetails(Map<String, dynamic> media) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaDetailsBottomSheet(
        media: media,
        inspectionId: widget.inspectionId,
        onMediaDeleted: (_) => _loadData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Text('Galeria de Mídia'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => MediaFilterPanel(
                  inspectionId: widget.inspectionId,
                  topics: _topics,
                  selectedTopicId: _selectedTopicId,
                  selectedItemId: _selectedItemId,
                  selectedDetailId: _selectedDetailId,
                  isNonConformityOnly: _isNonConformityOnly,
                  mediaType: _mediaType,
                  onApplyFilters: _applyFilters,
                  onClearFilters: _clearFilters,
                ),
              );
            },
            tooltip: 'Filtrar mídia',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // Filter summary
                if (_selectedTopicId != null ||
                    _selectedItemId != null ||
                    _selectedDetailId != null ||
                    _isNonConformityOnly != null ||
                    _mediaType != null)
                  _buildFilterSummary(),

                // Media grid
                Expanded(
                  child: _filteredMedia.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.photo_library,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhuma mídia encontrada',
                                style: TextStyle(color: Colors.white),
                              ),
                              if (_selectedTopicId != null ||
                                  _selectedItemId != null ||
                                  _selectedDetailId != null ||
                                  _isNonConformityOnly != null ||
                                  _mediaType != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.filter_alt_off),
                                  onPressed: _clearFilters,
                                  label: const Text('Limpar filtros'),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.white),
                                ),
                            ],
                          ),
                        )
                      : MediaGrid(
                          media: _filteredMedia,
                          onTap: _showMediaDetails,
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => MediaCapturePanel(
              inspectionId: widget.inspectionId,
              topics: _topics,
              selectedTopicId: _selectedTopicId,
              selectedItemId: _selectedItemId,
              selectedDetailId: _selectedDetailId,
              onMediaAdded: _handleMediaAdded,
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterSummary() {
    // Build summary of active filters
    List<Widget> filterChips = [];

    // Add topic filter chip
    if (_selectedTopicId != null) {
      final topicName = _topics
          .firstWhere(
            (topic) => topic.id == _selectedTopicId,
            orElse: () => Topic(
                id: '',
                inspectionId: '',
                topicName: 'Desconhecido',
                position: 0),
          )
          .topicName;

      filterChips.add(
        Chip(
          label: Text('Tópico: $topicName',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue.shade900,
          deleteIconColor: Colors.white,
          onDeleted: () {
            _applyFilters(
              topicId: null,
              itemId: _selectedItemId,
              detailId: _selectedDetailId,
              isNonConformityOnly: _isNonConformityOnly,
              mediaType: _mediaType,
            );
          },
        ),
      );
    }

    // Add item filter chip
    if (_selectedItemId != null) {
      // Find the item name
      String itemName = 'Item';
      for (var media in _allMedia) {
        if (media['topic_item_id'] == _selectedItemId) {
          itemName = media['item_name'] ?? 'Item';
          break;
        }
      }

      filterChips.add(
        Chip(
          label: Text('Item: $itemName',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.indigo.shade900,
          deleteIconColor: Colors.white,
          onDeleted: () {
            _applyFilters(
              topicId: _selectedTopicId,
              itemId: null,
              detailId: _selectedDetailId,
              isNonConformityOnly: _isNonConformityOnly,
              mediaType: _mediaType,
            );
          },
        ),
      );
    }

    // Add detail filter chip
    if (_selectedDetailId != null) {
      // Find the detail name
      String detailName = 'Detalhe';
      for (var media in _allMedia) {
        if (media['detail_id'] == _selectedDetailId) {
          detailName = media['detail_name'] ?? 'Detalhe';
          break;
        }
      }

      filterChips.add(
        Chip(
          label: Text('Detalhe: $detailName',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.teal.shade900,
          deleteIconColor: Colors.white,
          onDeleted: () {
            _applyFilters(
              topicId: _selectedTopicId,
              itemId: _selectedItemId,
              detailId: null,
              isNonConformityOnly: _isNonConformityOnly,
              mediaType: _mediaType,
            );
          },
        ),
      );
    }

    // Add non-conformity filter chip
    if (_isNonConformityOnly == true) {
      filterChips.add(
        Chip(
          label: const Text('Apenas Não Conformidades',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange.shade900,
          deleteIconColor: Colors.white,
          onDeleted: () {
            _applyFilters(
              topicId: _selectedTopicId,
              itemId: _selectedItemId,
              detailId: _selectedDetailId,
              isNonConformityOnly: null,
              mediaType: _mediaType,
            );
          },
        ),
      );
    }

    // Add media type filter chip
    if (_mediaType != null) {
      final chipColor =
          _mediaType == 'image' ? Colors.purple.shade900 : Colors.pink.shade900;

      filterChips.add(
        Chip(
          label: Text(
            _mediaType == 'image' ? 'Apenas Fotos' : 'Apenas Vídeos',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: chipColor,
          deleteIconColor: Colors.white,
          onDeleted: () {
            _applyFilters(
              topicId: _selectedTopicId,
              itemId: _selectedItemId,
              detailId: _selectedDetailId,
              isNonConformityOnly: _isNonConformityOnly,
              mediaType: null,
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...filterChips,
          ActionChip(
            label: const Text('Limpar Filtros',
                style: TextStyle(color: Colors.white)),
            onPressed: _clearFilters,
            backgroundColor: Colors.grey.shade800,
            avatar: const Icon(Icons.clear, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
