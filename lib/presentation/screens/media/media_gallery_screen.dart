// lib/presentation/screens/media/media_gallery_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inspection_app/models/room.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/detail.dart';
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
  List<Room> _rooms = [];
  
  // Filter states
  String? _selectedRoomId;
  String? _selectedItemId;
  String? _selectedDetailId;
  bool? _isNonConformityOnly;
  String? _mediaType;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load rooms, which will be needed for filtering
      final rooms = await _inspectionService.getRooms(widget.inspectionId);
      
      // Load all media for this inspection
      final mediaSnapshot = await _firestore
          .collection('media')
          .where('inspection_id', isEqualTo: widget.inspectionId)
          .orderBy('created_at', descending: true)
          .get();
          
      // Convert to list of maps
      final media = await Future.wait(mediaSnapshot.docs.map((doc) async {
        final data = doc.data();
        
        // Load additional metadata
        String? roomName;
        String? itemName;
        String? detailName;
        
        // Check if it's part of a non-conformity
        bool isNonConformity = false;
        
        if (data['room_id'] != null) {
          try {
            final roomDoc = await _firestore.collection('rooms').doc(data['room_id']).get();
            if (roomDoc.exists) {
              roomName = roomDoc.data()?['room_name'];
            }
          } catch (e) {
            print('Error loading room name: $e');
          }
        }
        
        if (data['room_item_id'] != null) {
          try {
            final itemDoc = await _firestore.collection('room_items').doc(data['room_item_id']).get();
            if (itemDoc.exists) {
              itemName = itemDoc.data()?['item_name'];
            }
          } catch (e) {
            print('Error loading item name: $e');
          }
        }
        
        if (data['detail_id'] != null) {
          try {
            final detailDoc = await _firestore.collection('item_details').doc(data['detail_id']).get();
            if (detailDoc.exists) {
              detailName = detailDoc.data()?['detail_name'];
              // Check if detail is marked as damaged
              isNonConformity = detailDoc.data()?['is_damaged'] == true;
            }
            
            // Also check non_conformities collection
            final nonConformityQuery = await _firestore
                .collection('non_conformities')
                .where('inspection_id', isEqualTo: widget.inspectionId)
                .where('detail_id', isEqualTo: data['detail_id'])
                .limit(1)
                .get();
                
            if (nonConformityQuery.docs.isNotEmpty) {
              isNonConformity = true;
            }
          } catch (e) {
            print('Error loading detail name: $e');
          }
        }
        
        return {
          'id': doc.id,
          ...data,
          'room_name': roomName,
          'item_name': itemName,
          'detail_name': detailName,
          'is_non_conformity': isNonConformity,
        };
      }));
      
      if (mounted) {
        setState(() {
          _rooms = rooms;
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
    String? roomId,
    String? itemId,
    String? detailId,
    bool? isNonConformityOnly,
    String? mediaType,
  }) {
    setState(() {
      _selectedRoomId = roomId;
      _selectedItemId = itemId;
      _selectedDetailId = detailId;
      _isNonConformityOnly = isNonConformityOnly;
      _mediaType = mediaType;
      
      // Apply filters
      _filteredMedia = _allMedia.where((media) {
        // Filter by room if selected
        if (roomId != null && media['room_id'] != roomId) {
          return false;
        }
        
        // Filter by item if selected
        if (itemId != null && media['room_item_id'] != itemId) {
          return false;
        }
        
        // Filter by detail if selected
        if (detailId != null && media['detail_id'] != detailId) {
          return false;
        }
        
        // Filter by non-conformity status if selected
        if (isNonConformityOnly == true && !(media['is_non_conformity'] == true)) {
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
      _selectedRoomId = null;
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
      appBar: AppBar(
        title: const Text('Galeria de Mídia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => MediaFilterPanel(
                  inspectionId: widget.inspectionId,
                  rooms: _rooms,
                  selectedRoomId: _selectedRoomId,
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter summary
                if (_selectedRoomId != null || _selectedItemId != null || _selectedDetailId != null || 
                    _isNonConformityOnly != null || _mediaType != null)
                  _buildFilterSummary(),
                
                // Media grid
                Expanded(
                  child: _filteredMedia.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.photo_library, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('Nenhuma mídia encontrada'),
                              if (_selectedRoomId != null || _selectedItemId != null || _selectedDetailId != null || 
                                  _isNonConformityOnly != null || _mediaType != null)
                                ElevatedButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Limpar filtros'),
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
              rooms: _rooms,
              selectedRoomId: _selectedRoomId,
              selectedItemId: _selectedItemId,
              selectedDetailId: _selectedDetailId,
              onMediaAdded: _handleMediaAdded,
            ),
          );
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
  
  Widget _buildFilterSummary() {
    // Build summary of active filters
    List<Widget> filterChips = [];
    
    // Add room filter chip
    if (_selectedRoomId != null) {
      final roomName = _rooms.firstWhere(
        (room) => room.id == _selectedRoomId,
        orElse: () => Room(id: '', inspectionId: '', roomName: 'Desconhecido', position: 0),
      ).roomName;
      
      filterChips.add(
        Chip(
          label: Text('Tópico: $roomName'),
          onDeleted: () {
            _applyFilters(
              roomId: null,
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
        if (media['room_item_id'] == _selectedItemId) {
          itemName = media['item_name'] ?? 'Item';
          break;
        }
      }
      
      filterChips.add(
        Chip(
          label: Text('Item: $itemName'),
          onDeleted: () {
            _applyFilters(
              roomId: _selectedRoomId,
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
          label: Text('Detalhe: $detailName'),
          onDeleted: () {
            _applyFilters(
              roomId: _selectedRoomId,
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
          label: const Text('Apenas Não Conformidades'),
          backgroundColor: Colors.orange.shade100,
          onDeleted: () {
            _applyFilters(
              roomId: _selectedRoomId,
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
      filterChips.add(
        Chip(
          label: Text(_mediaType == 'image' ? 'Apenas Fotos' : 'Apenas Vídeos'),
          backgroundColor: _mediaType == 'image' ? Colors.blue.shade100 : Colors.purple.shade100,
          onDeleted: () {
            _applyFilters(
              roomId: _selectedRoomId,
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
            label: const Text('Limpar Filtros'),
            onPressed: _clearFilters,
            backgroundColor: Colors.grey.shade200,
            avatar: const Icon(Icons.clear, size: 16),
          ),
        ],
      ),
    );
  }
}