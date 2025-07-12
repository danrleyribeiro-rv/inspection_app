// lib/presentation/screens/inspection/components/non_conformity_list.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lince_inspecoes/presentation/widgets/media/non_conformity_media_widget.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/non_conformity_edit_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/media_capture_dialog.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class NonConformityList extends StatefulWidget {
  final List<Map<String, dynamic>> nonConformities;
  final String inspectionId;
  final Function(String, String) onStatusUpdate;
  final Function(String) onDeleteNonConformity;
  final Function(Map<String, dynamic>) onEditNonConformity;
  final String? filterByDetailId;
  final Function()? onNonConformityUpdated;
  final String searchQuery;
  final String? levelFilter;

  const NonConformityList({
    super.key,
    required this.nonConformities,
    required this.inspectionId,
    required this.onStatusUpdate,
    required this.onDeleteNonConformity,
    required this.onEditNonConformity,
    this.filterByDetailId,
    this.onNonConformityUpdated,
    this.searchQuery = '',
    this.levelFilter,
  });

  @override
  State<NonConformityList> createState() => _NonConformityListState();
}

class _NonConformityListState extends State<NonConformityList> {
  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;
  final Map<String, int> _mediaCountCache = {};
  int _mediaCountVersion = 0; // Força rebuild do FutureBuilder

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'alta':
        return Colors.red;
      case 'média':
      case 'media':
        return Colors.orange;
      case 'baixa':
        return Colors.yellow; // Changed from green to yellow
      case 'crítica':
      case 'critica':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<int> _getMediaCount(String nonConformityId) async {
    if (_mediaCountCache.containsKey(nonConformityId)) {
      return _mediaCountCache[nonConformityId]!;
    }

    try {
      final medias = await _serviceFactory.mediaService.getMediaByContext(
        nonConformityId: nonConformityId,
      );
      
      // Filter out resolution medias to show only regular NC medias
      final regularMedias = medias.where((media) {
        final source = media.source ?? '';
        return source != 'resolution_camera' && source != 'resolution_gallery';
      }).toList();
      
      final count = regularMedias.length;
      _mediaCountCache[nonConformityId] = count;
      return count;
    } catch (e) {
      debugPrint('Error getting media count for NC $nonConformityId: $e');
      return 0;
    }
  }

  Future<int> _getResolutionMediaCount(String nonConformityId) async {
    final cacheKey = 'resolution_$nonConformityId';
    if (_mediaCountCache.containsKey(cacheKey)) {
      return _mediaCountCache[cacheKey]!;
    }

    try {
      // Get all medias for this non-conformity and filter for resolution images
      final medias = await _serviceFactory.mediaService.getMediaByContext(
        nonConformityId: nonConformityId,
      );
      
      // Filter medias that are resolution images based on source
      final resolutionMedias = medias.where((media) {
        final source = media.source ?? '';
        return source == 'resolution_camera' || source == 'resolution_gallery';
      }).toList();
      
      final count = resolutionMedias.length;
      _mediaCountCache[cacheKey] = count;
      return count;
    } catch (e) {
      debugPrint('Error getting resolution media count for NC $nonConformityId: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nonConformities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text('Nenhuma não conformidade registrada',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Cadastre uma nova não conformidade na outra aba'),
          ],
        ),
      );
    }

    List<Map<String, dynamic>> filteredNCs = widget.nonConformities;
    
    // Apply detail filter if provided
    if (widget.filterByDetailId != null) {
      filteredNCs = filteredNCs
          .where((nc) => nc['detail_id'] == widget.filterByDetailId)
          .toList();
    }
    
    // Apply search filter
    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filteredNCs = filteredNCs.where((nc) {
        final description = (nc['description'] ?? '').toString().toLowerCase();
        final topicName = (nc['topic_name'] ?? '').toString().toLowerCase();
        final itemName = (nc['item_name'] ?? '').toString().toLowerCase();
        final detailName = (nc['detail_name'] ?? '').toString().toLowerCase();
        final severity = (nc['severity'] ?? '').toString().toLowerCase();
        
        return description.contains(query) ||
               topicName.contains(query) ||
               itemName.contains(query) ||
               detailName.contains(query) ||
               severity.contains(query);
      }).toList();
    }
    
    // Apply level filter
    if (widget.levelFilter != null) {
      filteredNCs = filteredNCs.where((nc) {
        switch (widget.levelFilter) {
          case 'topic':
            return nc['item_id'] == null && nc['detail_id'] == null;
          case 'item':
            return nc['item_id'] != null && nc['detail_id'] == null;
          case 'detail':
            return nc['detail_id'] != null;
          default:
            return true;
        }
      }).toList();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredNCs.length,
      itemBuilder: (context, index) =>
          _buildCompactCard(context, filteredNCs[index]),
    );
  }

  Widget _buildCompactCard(BuildContext context, Map<String, dynamic> item) {
    // Extract names directly from the item data structure
    final topicName = item['topic_name'] ?? 'Tópico não especificado';
    final itemName = item['item_name'] ?? 'Item não especificado';
    final detailName = item['detail_name'] ?? 'Detalhe não especificado';

    final severity = item['severity'] ?? 'Média';
    final status = item['status'] ?? 'pendente';

    final isResolved = item['is_resolved'] == true;

    // Se resolvido, usar cor verde escura. Senão, usar cor baseada na severidade
    Color cardColor = isResolved
        ? const Color(0xFF1B5E20) // Verde escuro para resolvidos
        : switch (severity?.toLowerCase()) {
            'alta' => const Color(0xFF4A1E1E), // Vermelho escuro
            'média' || 'media' => const Color(0xFF4A3B1E), // Laranja escuro
            'baixa' => const Color(0xFF4A3B1E), // Amarelo escuro (changed from green)
            'crítica' || 'critica' => const Color(0xFF3A1E4A), // Roxo escuro
            _ => const Color(0xFF3A3A3A), // Cinza escuro
          };

    final (statusColor, statusText) =
        isResolved ? (Colors.green, 'RESOLVIDO') : (Colors.orange, 'PENDENTE');

    DateTime? createdAt;
    try {
      if (item['created_at'] != null) {
        createdAt = item['created_at'] is String
            ? DateTime.parse(item['created_at'])
            : item['created_at']?.toDate?.call();
      }
    } catch (e) {
      debugPrint('Error parsing date: ${item['created_at']}');
    }

    String nonConformityId = item['id'] ?? '';
    if (!nonConformityId.contains('-')) {
      nonConformityId =
          '$widget.inspectionId-${item['topic_id']}-${item['item_id']}-${item['detail_id']}-$nonConformityId';
    }

    final parts = nonConformityId.split('-');
    final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
    final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
    final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
    final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: cardColor,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header compacto
            Row(
              children: [
                _buildStatusChip(statusText, statusColor),
                const SizedBox(width: 4),
                _buildSeverityChip(severity),
                const Spacer(),
                if (!isResolved)
                  _buildActionButton(Icons.check_circle, Colors.green,
                      () => _resolveNonConformity(context, item)),
                _buildActionButton(Icons.delete, Colors.red,
                    () => _confirmDelete(context, item)),
              ],
            ),
            const SizedBox(height: 6),

            // Localização compacta - mais visível
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Text(
                '$topicName > $itemName > $detailName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),

            // Descrição
            Text(item['description'] ?? "Sem descrição",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

            // Ação corretiva se houver
            if (item['corrective_action'] != null) ...[
              const SizedBox(height: 4),
              Text('Ação: ${item['corrective_action']}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 6),

            // Botões de ação: Câmera, Galeria, Editar + Botões de Resolução
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botões regulares (sempre visíveis)
                _buildActionButtonV2(
                  icon: Icons.camera_alt,
                  label: 'Câmera',
                  color: Colors.purple,
                  onPressed: () => _showCaptureDialog(context, item),
                ),
                FutureBuilder<int>(
                  key: ValueKey('nc_media_${item['id']}_$_mediaCountVersion'),
                  future: _getMediaCount(item['id'] ?? ''),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _buildActionButtonV2(
                      icon: Icons.photo_library,
                      label: 'Galeria',
                      color: Colors.purple,
                      onPressed: () => _showMediaGallery(context, item),
                      count: count,
                    );
                  },
                ),
                _buildActionButtonV2(
                  icon: Icons.edit,
                  label: 'Editar',
                  color: Colors.blue,
                  onPressed: () => _showEditDialog(context, item),
                ),
                
                // Botões de resolução (só para NCs resolvidas)
                if (isResolved) ...[
                  FutureBuilder<int>(
                    key: ValueKey('nc_resolution_${item['id']}_$_mediaCountVersion'),
                    future: _getResolutionMediaCount(item['id'] ?? ''),
                    builder: (context, snapshot) {
                      final resolutionCount = snapshot.data ?? 0;
                      
                      if (resolutionCount > 0) {
                        // Se tem mídias de resolução, mostrar botão de galeria
                        return _buildActionButtonV2(
                          icon: Icons.photo_library,
                          label: 'Resolvido',
                          color: Colors.green,
                          onPressed: () => _showResolutionGallery(context, item),
                          count: resolutionCount,
                        );
                      } else {
                        // Se não tem mídias de resolução, mostrar botão de adicionar
                        return _buildActionButtonV2(
                          icon: Icons.camera_alt,
                          label: 'Adicionar',
                          color: Colors.green,
                          onPressed: () => _addResolutionMedia(context, item),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),

            // Imagens de resolução se houver
            if (isResolved &&
                item['resolution_images'] != null &&
                (item['resolution_images'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Imagens de Resolução:',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (item['resolution_images'] as List).length,
                  itemBuilder: (context, index) {
                    final imagePath =
                        (item['resolution_images'] as List)[index] as String;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: imagePath.startsWith('http')
                            ? Image.network(
                                imagePath,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey[600],
                                    child: const Icon(Icons.image,
                                        color: Colors.white54, size: 20),
                                  );
                                },
                              )
                            : Image.file(
                                File(imagePath),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey[600],
                                    child: const Icon(Icons.image,
                                        color: Colors.white54, size: 20),
                                  );
                                },
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 6),

            // Widget de mídia
            if (topicIndex != null &&
                itemIndex != null &&
                detailIndex != null &&
                ncIndex != null)
              NonConformityMediaWidget(
                inspectionId: widget.inspectionId,
                topicIndex: topicIndex,
                itemIndex: itemIndex,
                detailIndex: detailIndex,
                ncIndex: ncIndex,
                isReadOnly: status == 'resolvido',
                onMediaAdded: (_) {},
                onNonConformityUpdated: widget.onNonConformityUpdated,
              ),

            // Data de criação e botões de ação
            Row(
              children: [
                if (createdAt != null)
                  Text(DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 9)),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSeverityChip(String severity) {
    final color = _getSeverityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(severity,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton(
      IconData icon, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 14, color: color),
      onPressed: onPressed,
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildActionButtonV2({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    int? count,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Icon(icon, size: 20),
              ),
              if (count != null && count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6F4B99),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => NonConformityEditDialog(
        nonConformity: item,
        onSave: (updatedData) {
          widget.onEditNonConformity(updatedData);
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> item) {
    String nonConformityId = item['id'] ?? '';
    if (!nonConformityId.contains('-')) {
      nonConformityId =
          '$widget.inspectionId-${item['topic_id']}-${item['item_id']}-${item['detail_id']}-$nonConformityId';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Não Conformidade'),
        content:
            const Text('Tem certeza que deseja excluir esta não conformidade?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              widget.onDeleteNonConformity(nonConformityId);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _resolveNonConformity(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolver Não Conformidade'),
        content: const Text('Deseja adicionar imagens de resolução antes de marcar como resolvida?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _markAsResolved(context, item, []);
            },
            child: const Text('Resolver Sem Fotos'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showResolutionCaptureDialog(context, item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Adicionar Fotos'),
          ),
        ],
      ),
    );
  }

  void _showResolutionCaptureDialog(
      BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => MediaCaptureDialog(
        onMediaCaptured: (filePath, type, source) async {
          try {
            await _handleResolutionMediaCapture(context, item, [filePath]);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao capturar mídia: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleResolutionMediaCapture(
      BuildContext context, 
      Map<String, dynamic> item, 
      List<String> imagePaths) async {
    try {
      final serviceFactory = EnhancedOfflineServiceFactory.instance;
      final nonConformityId = item['id'] ?? '';
      
      // Process and save each resolution image
      for (final imagePath in imagePaths) {
        await serviceFactory.mediaService.captureAndProcessMediaSimple(
          inputPath: imagePath,
          inspectionId: widget.inspectionId,
          type: 'image',
          topicId: item['topic_id'],
          itemId: item['item_id'],
          detailId: item['detail_id'],
          nonConformityId: nonConformityId,
          source: 'resolution_camera', // Mark as resolution media
        );
      }
      
      // Mark as resolved with resolution images
      if (context.mounted) {
        _markAsResolved(context, item, imagePaths);
        
        // Refresh the non-conformity list to update button state
        if (widget.onNonConformityUpdated != null) {
          widget.onNonConformityUpdated!();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar mídia de resolução: $e')),
        );
      }
    }
  }

  void _markAsResolved(BuildContext context, Map<String, dynamic> item,
      List<String> resolutionImages) {
    final updatedItem = Map<String, dynamic>.from(item);
    updatedItem['status'] = 'resolvido';
    updatedItem['is_resolved'] = true;
    updatedItem['resolved_at'] = DateTime.now().toIso8601String();
    updatedItem['resolution_images'] = resolutionImages;

    widget.onEditNonConformity(updatedItem);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resolutionImages.isNotEmpty
              ? 'Não conformidade resolvida com ${resolutionImages.length} imagem(ns)!'
              : 'Não conformidade resolvida!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCaptureDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => MediaCaptureDialog(
        onMediaCaptured: (filePath, type, source) async {
          try {
            await _handleMediaCapture(context, item, [filePath]);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao capturar mídia: $e')),
              );
            }
          }
        },
      ),
    );
  }


  Future<void> _handleMediaCapture(BuildContext context,
      Map<String, dynamic> item, List<String> imagePaths) async {
    try {
      final serviceFactory = EnhancedOfflineServiceFactory.instance;

      // Get the non-conformity ID for media association
      String nonConformityId = item['id'] ?? '';
      if (!nonConformityId.contains('-')) {
        nonConformityId =
            '$widget.inspectionId-${item['topic_id']}-${item['item_id']}-${item['detail_id']}-$nonConformityId';
      }

      // Process and save each image
      for (final imagePath in imagePaths) {
        await serviceFactory.mediaService.captureAndProcessMediaSimple(
          inputPath: imagePath,
          inspectionId: widget.inspectionId,
          type: 'image',
          topicId: item['topic_id'],
          itemId: item['item_id'],
          detailId: item['detail_id'],
          nonConformityId: nonConformityId,
          source: 'camera',
        );
      }

      // Limpar cache para atualizar contador imediatamente
      final nonConformityIdForCache = item['id'] ?? '';
      _mediaCountCache.remove(nonConformityIdForCache);
      
      // Forçar rebuild do widget para mostrar nova contagem
      if (mounted) {
        setState(() {
          _mediaCountVersion++; // Força rebuild do FutureBuilder
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${imagePaths.length} imagem(ns) capturada(s) e associada(s) à não conformidade!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the non-conformity list
        if (widget.onNonConformityUpdated != null) {
          widget.onNonConformityUpdated!();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar mídia: $e')),
        );
      }
    }
  }

  void _showMediaGallery(BuildContext context, Map<String, dynamic> item) {
    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaGalleryScreen(
            inspectionId: widget.inspectionId,
            initialTopicId: item['topic_id'],
            initialItemId: item['item_id'],
            initialDetailId: item['detail_id'],
            initialIsNonConformityOnly: true,
            excludeResolutionMedia: true, // Exclude resolution medias from regular gallery
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir galeria: $e')),
      );
    }
  }

  void _showResolutionGallery(BuildContext context, Map<String, dynamic> item) {
    try {
      // Show only resolution images for this resolved non-conformity
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaGalleryScreen(
            inspectionId: widget.inspectionId,
            initialTopicId: item['topic_id'],
            initialItemId: item['item_id'],
            initialDetailId: item['detail_id'],
            initialIsNonConformityOnly: true,
            initialMediaSource: 'resolution_camera', // Filter by resolution media only
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir galeria de resolução: $e')),
      );
    }
  }

  void _addResolutionMedia(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => MediaCaptureDialog(
        onMediaCaptured: (filePath, type, source) async {
          try {
            // Process resolution media with correct type and source
            final serviceFactory = EnhancedOfflineServiceFactory.instance;
            final nonConformityId = item['id'] ?? '';
            
            await serviceFactory.mediaService.captureAndProcessMediaSimple(
              inputPath: filePath,
              inspectionId: widget.inspectionId,
              type: type, // 'image' or 'video' from MediaCaptureDialog
              topicId: item['topic_id'],
              itemId: item['item_id'],
              detailId: item['detail_id'],
              nonConformityId: nonConformityId,
              source: 'resolution_camera', // Mark as resolution media
            );
            
            // Limpar cache para atualizar contadores
            _mediaCountCache.remove('resolution_$nonConformityId');
            
            // Forçar rebuild do widget para mostrar nova contagem
            if (mounted) {
              setState(() {
                _mediaCountVersion++; // Força rebuild do FutureBuilder
              });
            }
            
            // Refresh the non-conformity list to update button state
            if (widget.onNonConformityUpdated != null) {
              widget.onNonConformityUpdated!();
            }
            
            if (context.mounted) {
              final mediaType = type == 'image' ? 'Foto' : 'Vídeo';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$mediaType de resolução adicionada com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao capturar mídia: $e')),
              );
            }
          }
        },
      ),
    );
  }

}
