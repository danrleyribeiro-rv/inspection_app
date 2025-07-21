// lib/presentation/screens/inspection/components/non_conformity_list.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lince_inspecoes/presentation/widgets/media/non_conformity_media_widget.dart';
import 'package:lince_inspecoes/presentation/screens/inspection/components/non_conformity_edit_dialog.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_gallery_screen.dart';
import 'package:lince_inspecoes/presentation/widgets/camera/inspection_camera_screen.dart';
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
  final EnhancedOfflineServiceFactory _serviceFactory =
      EnhancedOfflineServiceFactory.instance;
  final Map<String, int> _mediaCountCache = {};
  final Map<String, ValueNotifier<int>> _mediaCountNotifiers = {};

  @override
  void initState() {
    super.initState();
    // Listen for media changes to invalidate cache
    _setupMediaChangeListener();
  }

  @override
  void dispose() {
    // Dispose all notifiers
    for (final notifier in _mediaCountNotifiers.values) {
      notifier.dispose();
    }
    _mediaCountNotifiers.clear();
    super.dispose();
  }

  void _setupMediaChangeListener() {
    // Clear cache and force rebuild when media changes
    // This ensures counters update immediately when media is deleted
    _clearMediaCache();
  }

  void _clearMediaCache() {
    debugPrint('NonConformityList: Clearing media cache');
    _mediaCountCache.clear();

    // Refresh all notifiers
    for (final notifier in _mediaCountNotifiers.values) {
      notifier.value = 0;
    }

    // Refresh all counts asynchronously
    for (final entry in _mediaCountNotifiers.entries) {
      final key = entry.key;
      if (key.startsWith('resolution_')) {
        final ncId = key.substring('resolution_'.length);
        _refreshResolutionMediaCount(ncId);
      } else {
        _refreshMediaCount(key);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(NonConformityList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the non-conformities list changed, clear cache to ensure fresh counts
    if (oldWidget.nonConformities != widget.nonConformities) {
      debugPrint(
          'NonConformityList: Non-conformities list updated, clearing cache');
      _clearMediaCache();
    }
  }

  // Public method to be called when media changes externally
  void refreshMediaCounts() {
    debugPrint('NonConformityList: External refresh requested');
    _clearMediaCache();
  }

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

  ValueNotifier<int> _getMediaCountNotifier(String nonConformityId) {
    if (!_mediaCountNotifiers.containsKey(nonConformityId)) {
      _mediaCountNotifiers[nonConformityId] = ValueNotifier<int>(0);
      _refreshMediaCount(nonConformityId);
    }
    return _mediaCountNotifiers[nonConformityId]!;
  }

  Future<void> _refreshMediaCount(String nonConformityId) async {
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

      if (_mediaCountNotifiers.containsKey(nonConformityId)) {
        _mediaCountNotifiers[nonConformityId]!.value = count;
      }
    } catch (e) {
      debugPrint('Error getting media count for NC $nonConformityId: $e');
      if (_mediaCountNotifiers.containsKey(nonConformityId)) {
        _mediaCountNotifiers[nonConformityId]!.value = 0;
      }
    }
  }

  ValueNotifier<int> _getResolutionMediaCountNotifier(String nonConformityId) {
    final cacheKey = 'resolution_$nonConformityId';
    if (!_mediaCountNotifiers.containsKey(cacheKey)) {
      _mediaCountNotifiers[cacheKey] = ValueNotifier<int>(0);
      _refreshResolutionMediaCount(nonConformityId);
    }
    return _mediaCountNotifiers[cacheKey]!;
  }

  Future<void> _refreshResolutionMediaCount(String nonConformityId) async {
    final cacheKey = 'resolution_$nonConformityId';
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

      if (_mediaCountNotifiers.containsKey(cacheKey)) {
        _mediaCountNotifiers[cacheKey]!.value = count;
      }
    } catch (e) {
      debugPrint(
          'Error getting resolution media count for NC $nonConformityId: $e');
      if (_mediaCountNotifiers.containsKey(cacheKey)) {
        _mediaCountNotifiers[cacheKey]!.value = 0;
      }
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

    final severity = item['severity'];
    final status = item['status'] ?? 'pendente';

    // More robust resolution check
    final isResolvedField = item['is_resolved'];
    final isResolved = (isResolvedField == true ||
            isResolvedField == 1 ||
            isResolvedField == '1') ||
        (item['status'] == 'closed');

    // Debug para verificar status
    if (item['id'] != null) {
      debugPrint(
          'NonConformityList: NC ${item['id']} - status: $status, is_resolved: ${item['is_resolved']} (type: ${item['is_resolved'].runtimeType}), resolved: $isResolved');
    }

    // Se resolvido, usar cor verde escura. Senão, usar cor baseada na severidade
    Color cardColor = isResolved
        ? const Color(0xFF1B5E20) // Verde escuro para resolvidos
        : (severity == null || severity.isEmpty)
            ? const Color(0xFF3A3A3A) // Cinza escuro para sem severidade
            : switch (severity.toLowerCase()) {
                'alta' => const Color(0xFF4A1E1E), // Vermelho escuro
                'média' || 'media' => const Color(0xFF4A3B1E), // Laranja escuro
                'baixa' => const Color(0xFF4A4A1E), // Amarelo escuro
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
                if (severity != null && severity.isNotEmpty) _buildSeverityChip(severity),
                const Spacer(),
                if (!isResolved)
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _resolveNonConformity(context, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Resolver',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                _buildActionButton(Icons.delete, Colors.red,
                    () => _confirmDelete(context, item)),
              ],
            ),
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
                  fontSize: 10,
                ),
                maxLines: 3,
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis),

            // Ação corretiva se houver
            if (item['corrective_action'] != null) ...[
              const SizedBox(height: 4),
              Text('Ação: ${item['corrective_action']}',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                  maxLines: 3,
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
                ValueListenableBuilder<int>(
                  valueListenable: _getMediaCountNotifier(item['id'] ?? ''),
                  builder: (context, count, child) {
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
                  ValueListenableBuilder<int>(
                    valueListenable:
                        _getResolutionMediaCountNotifier(item['id'] ?? ''),
                    builder: (context, resolutionCount, child) {
                      if (resolutionCount > 0) {
                        // Se tem mídias de resolução, mostrar botão de galeria
                        return _buildActionButtonV2(
                          icon: Icons.photo_library,
                          label: 'Resolvido',
                          color: Colors.green,
                          onPressed: () =>
                              _showResolutionGallery(context, item),
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
                  // Botão para desmarcar como resolvida
                  _buildActionButtonV2(
                    icon: Icons.undo,
                    label: 'Reabrir',
                    color: Colors.orange,
                    onPressed: () => _unresolveNonConformity(context, item),
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
                isReadOnly: status == 'closed',
                onMediaAdded: (_) {},
                onNonConformityUpdated: widget.onNonConformityUpdated,
              ),

            // Data de criação e resolução
            Row(
              children: [
                // Data de criação (lado esquerdo)
                if (createdAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Criada:',
                          style: TextStyle(color: Colors.white54, fontSize: 8)),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                const Spacer(),
                // Data de resolução (lado direito)
                if (isResolved)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Resolvida:',
                          style: TextStyle(color: Colors.green, fontSize: 8)),
                      Text(() {
                        try {
                          final resolvedAtData = item['resolved_at'];
                          if (resolvedAtData != null) {
                            final resolvedAt = resolvedAtData is String
                                ? DateTime.parse(resolvedAtData)
                                : resolvedAtData?.toDate?.call();
                            return resolvedAt != null
                                ? DateFormat('dd/MM/yyyy HH:mm')
                                    .format(resolvedAt)
                                : 'Agora mesmo';
                          } else {
                            // If no resolved_at, show current time as fallback
                            return DateFormat('dd/MM/yyyy HH:mm')
                                .format(DateTime.now());
                          }
                        } catch (e) {
                          return 'Agora mesmo';
                        }
                      }(),
                          style: const TextStyle(
                              color: Colors.green, fontSize: 9)),
                    ],
                  ),
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
    debugPrint(
        'NonConformityList: _resolveNonConformity called for NC ${item['id']}');
    debugPrint('NonConformityList: Item data: $item');
    debugPrint(
        'NonConformityList: Current status: ${item['status']}, is_resolved: ${item['is_resolved']}');
    
    // Show dialog with resolution options
    _showResolutionOptionsDialog(context, item);
  }

  void _showResolutionOptionsDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Resolver Não Conformidade',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Como deseja resolver esta não conformidade?',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botão Marcar como Resolvido
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _markAsResolvedWithoutPhoto(context, item);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(20),
                            child: Icon(
                              Icons.check_circle,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Marcar como\nResolvido',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Botão Capturar Foto
                Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _showResolutionCaptureDialog(context, item);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(20),
                            child: Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Capturar Foto\nda Resolução',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Botão Cancelar no canto inferior direito
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: EdgeInsets.zero,
        actions: const [], // Remove actions to use custom layout
      ),
    );
  }

  Future<void> _markAsResolvedWithoutPhoto(BuildContext context, Map<String, dynamic> item) async {
    try {
      debugPrint('NonConformityList: Marking NC ${item['id']} as resolved without photo');
      
      // Mark as resolved without resolution images
      await _markAsResolvedDirectly(item, []);
      
      // Refresh the non-conformity list to update button state
      if (widget.onNonConformityUpdated != null) {
        widget.onNonConformityUpdated!();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade marcada como resolvida!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('NonConformityList: Error marking as resolved without photo: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao resolver não conformidade: $e')),
        );
      }
    }
  }

  void _showResolutionCaptureDialog(
      BuildContext context, Map<String, dynamic> item) {
    debugPrint(
        'NonConformityList: Showing resolution capture dialog for NC ${item['id']}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InspectionCameraScreen(
          inspectionId: widget.inspectionId,
          topicId: item['topic_id'],
          itemId: item['item_id'],
          detailId: item['detail_id'],
          nonConformityId: item['id'],
          source: 'resolution_camera',
          onMediaCaptured: (capturedFiles) async {
            debugPrint(
                'NonConformityList: ${capturedFiles.length} media files captured');
            try {
              await _handleResolutionMediaCapture(context, item, capturedFiles);
            } catch (e) {
              debugPrint('NonConformityList: ERROR in onMediaCaptured: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao capturar mídia: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleResolutionMediaCapture(BuildContext context,
      Map<String, dynamic> item, List<String> imagePaths) async {
    try {
      debugPrint(
          'NonConformityList: Starting resolution media capture for NC ${item['id']}');
      final serviceFactory = EnhancedOfflineServiceFactory.instance;
      final nonConformityId = item['id'] ?? '';

      // Process and save each resolution image
      for (final imagePath in imagePaths) {
        debugPrint(
            'NonConformityList: Processing resolution image: $imagePath');
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
        debugPrint(
            'NonConformityList: Resolution image processed successfully');
      }

      // Mark as resolved with resolution images
      debugPrint(
          'NonConformityList: Checking if context is mounted: ${context.mounted}');
      debugPrint(
          'NonConformityList: About to mark NC ${item['id']} as resolved (regardless of context)');
      debugPrint(
          'NonConformityList: Current item status: ${item['status']}, is_resolved: ${item['is_resolved']}');
      debugPrint('NonConformityList: Image paths to pass: $imagePaths');

      // Mark as resolved even if context is not mounted - this is critical for data consistency
      await _markAsResolvedDirectly(item, imagePaths);
      debugPrint('NonConformityList: _markAsResolvedDirectly completed');

      debugPrint('NonConformityList: Marked as resolved, triggering refresh');
      // Refresh the non-conformity list to update button state
      if (widget.onNonConformityUpdated != null) {
        debugPrint(
            'NonConformityList: Calling onNonConformityUpdated callback');
        widget.onNonConformityUpdated!();
        debugPrint(
            'NonConformityList: onNonConformityUpdated callback completed');
      } else {
        debugPrint(
            'NonConformityList: onNonConformityUpdated callback is null');
      }

      // Show success message only if context is still mounted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imagePaths.isNotEmpty
                ? 'Não conformidade resolvida com ${imagePaths.length} imagem(ns)!'
                : 'Não conformidade resolvida!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint(
          'NonConformityList: ERROR in _handleResolutionMediaCapture: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar mídia de resolução: $e')),
        );
      }
    }
  }

  Future<void> _markAsResolvedDirectly(
      Map<String, dynamic> item, List<String> resolutionImages) async {
    debugPrint(
        'NonConformityList: ========== _markAsResolvedDirectly STARTED ==========');
    debugPrint('NonConformityList: Input item: $item');
    debugPrint('NonConformityList: Resolution images: $resolutionImages');

    final updatedItem = Map<String, dynamic>.from(item);

    // Ensure all resolution fields are properly set
    updatedItem['status'] = 'closed';
    updatedItem['is_resolved'] = true;
    updatedItem['resolved_at'] = DateTime.now().toIso8601String();
    updatedItem['resolution_images'] = resolutionImages;

    debugPrint('NonConformityList: Marking NC ${item['id']} as resolved');
    debugPrint(
        'NonConformityList: Original item status: ${item['status']}, is_resolved: ${item['is_resolved']}');
    debugPrint(
        'NonConformityList: Updated item status: ${updatedItem['status']}, is_resolved: ${updatedItem['is_resolved']}');
    debugPrint('NonConformityList: Updated item: $updatedItem');

    try {
      // Update the non-conformity directly
      debugPrint('NonConformityList: Calling widget.onEditNonConformity');
      widget.onEditNonConformity(updatedItem);
      debugPrint('NonConformityList: widget.onEditNonConformity completed');

      // Add a delay to ensure database operation completes
      await Future.delayed(const Duration(milliseconds: 1000));
      debugPrint('NonConformityList: Delay completed');

      // Force UI update with immediate state refresh
      if (mounted) {
        debugPrint('NonConformityList: Widget still mounted, updating state');
        setState(() {
          // Force rebuild

          // Also update the local item state immediately for instant feedback
          if (widget.nonConformities.isNotEmpty) {
            final index = widget.nonConformities
                .indexWhere((nc) => nc['id'] == item['id']);
            debugPrint(
                'NonConformityList: Looking for NC ${item['id']} in list, found at index: $index');
            if (index >= 0) {
              widget.nonConformities[index]['status'] = 'closed';
              widget.nonConformities[index]['is_resolved'] = true;
              widget.nonConformities[index]['resolved_at'] =
                  updatedItem['resolved_at'];
              debugPrint(
                  'NonConformityList: Updated local state for NC at index $index');
            }
          }
        });
        debugPrint('NonConformityList: State update completed');
      } else {
        debugPrint(
            'NonConformityList: Widget not mounted, skipping state update');
      }
    } catch (e) {
      debugPrint('NonConformityList: Error during direct resolution: $e');
    }
  }

  void _showCaptureDialog(BuildContext context, Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InspectionCameraScreen(
          inspectionId: widget.inspectionId,
          topicId: item['topic_id'],
          itemId: item['item_id'],
          detailId: item['detail_id'],
          source: 'camera',
          onMediaCaptured: (capturedFiles) async {
            try {
              await _handleMediaCapture(context, item, capturedFiles);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao capturar mídia: $e')),
                );
              }
            }
          },
        ),
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
      _mediaCountCache.remove('resolution_$nonConformityIdForCache');

      // Refresh the specific counters
      _refreshMediaCount(nonConformityIdForCache);
      _refreshResolutionMediaCount(nonConformityIdForCache);

      // Forçar rebuild do widget para mostrar nova contagem
      if (mounted) {
        setState(() {
          // Força rebuild do FutureBuilder
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

        // Navegar para a galeria após captura
        Navigator.of(context).pop(); // Fechar o dialog de captura se ainda estiver aberto
        _showMediaGallery(context, item);

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

  void _showMediaGallery(
      BuildContext context, Map<String, dynamic> item) async {
    try {
      final nonConformityId = item['id'] ?? '';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaGalleryScreen(
            inspectionId: widget.inspectionId,
            initialTopicId: item['topic_id'],
            initialItemId: item['item_id'],
            initialDetailId: item['detail_id'],
            initialNonConformityId:
                nonConformityId, // CRITICAL: Pass the specific NC ID
            initialIsNonConformityOnly: true,
            excludeResolutionMedia:
                true, // Exclude resolution medias from regular gallery
          ),
        ),
      );

      // Clear cache when returning from gallery to update counters
      debugPrint(
          'NonConformityList: Returned from media gallery, refreshing counts');
      _mediaCountCache.remove(nonConformityId);
      _mediaCountCache.remove('resolution_$nonConformityId');

      // Refresh the specific counters
      _refreshMediaCount(nonConformityId);
      _refreshResolutionMediaCount(nonConformityId);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir galeria: $e')),
        );
      }
    }
  }

  void _showResolutionGallery(
      BuildContext context, Map<String, dynamic> item) async {
    try {
      // Show only resolution images for this specific resolved non-conformity
      final nonConformityId = item['id'] ?? '';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaGalleryScreen(
            inspectionId: widget.inspectionId,
            initialTopicId: item['topic_id'],
            initialItemId: item['item_id'],
            initialDetailId: item['detail_id'],
            initialNonConformityId: nonConformityId, // Filter by specific NC
            initialMediaSource:
                'resolution_camera', // Filter by resolution media (primary source)
          ),
        ),
      );

      // Clear cache when returning from resolution gallery to update counters
      debugPrint(
          'NonConformityList: Returned from resolution gallery, refreshing counts');
      _mediaCountCache.remove(nonConformityId);
      _mediaCountCache.remove('resolution_$nonConformityId');

      // Refresh the specific counters
      _refreshMediaCount(nonConformityId);
      _refreshResolutionMediaCount(nonConformityId);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir galeria de resolução: $e')),
        );
      }
    }
  }

  void _unresolveNonConformity(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reabrir Não Conformidade'),
        content: const Text('Tem certeza que deseja reabrir esta não conformidade? Ela voltará ao status pendente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _markAsUnresolvedDirectly(context, item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsUnresolvedDirectly(BuildContext context, Map<String, dynamic> item) async {
    try {
      debugPrint('NonConformityList: Marking NC ${item['id']} as unresolved');
      
      final updatedItem = Map<String, dynamic>.from(item);
      
      // Mark as unresolved
      updatedItem['status'] = 'open';
      updatedItem['is_resolved'] = false;
      updatedItem['resolved_at'] = null;
      // Keep resolution images for historical record, but mark as unresolved
      
      debugPrint('NonConformityList: Updated item: $updatedItem');
      
      // Update the non-conformity directly
      widget.onEditNonConformity(updatedItem);
      
      // Refresh the non-conformity list to update button state
      if (widget.onNonConformityUpdated != null) {
        widget.onNonConformityUpdated!();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não conformidade reaberta com sucesso!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('NonConformityList: Error marking as unresolved: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao reabrir não conformidade: $e')),
        );
      }
    }
  }

  void _addResolutionMedia(BuildContext context, Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InspectionCameraScreen(
          inspectionId: widget.inspectionId,
          topicId: item['topic_id'],
          itemId: item['item_id'],
          detailId: item['detail_id'],
          source: 'camera',
          onMediaCaptured: (capturedFiles) async {
            try {
              // Process resolution media with correct type and source
              final serviceFactory = EnhancedOfflineServiceFactory.instance;
              final nonConformityId = item['id'] ?? '';

              // Process each captured file
              for (final filePath in capturedFiles) {
                await serviceFactory.mediaService.captureAndProcessMediaSimple(
                  inputPath: filePath,
                  inspectionId: widget.inspectionId,
                  type: 'image', // Default to image, will be detected by service
                  topicId: item['topic_id'],
                  itemId: item['item_id'],
                  detailId: item['detail_id'],
                  nonConformityId: nonConformityId,
                  source: 'resolution_camera', // Mark as resolution media
                );
              }

              // Limpar cache para atualizar contadores
              _mediaCountCache.remove('resolution_$nonConformityId');
              _mediaCountCache
                  .remove(nonConformityId); // Também limpar cache regular

              // Refresh the specific counters
              _refreshMediaCount(nonConformityId);
              _refreshResolutionMediaCount(nonConformityId);

              // Forçar rebuild do widget para mostrar nova contagem
              if (mounted) {
                setState(() {
                  // Força rebuild do FutureBuilder
                });
              }

              // Refresh the non-conformity list to update button state
              if (widget.onNonConformityUpdated != null) {
                widget.onNonConformityUpdated!();
              }

              if (context.mounted) {
                final message = capturedFiles.length == 1
                    ? 'Mídia de resolução adicionada com sucesso!'
                    : '${capturedFiles.length} mídias de resolução adicionadas com sucesso!';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
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
      ),
    );
  }
}
