// lib/presentation/screens/media/components/media_grid.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_viewer_screen.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/common/cached_media_image.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/move_media_dialog.dart';

class MediaGrid extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final Function(Map<String, dynamic>) onTap;
  final Function()? onRefresh;

  const MediaGrid({
    super.key,
    required this.media,
    required this.onTap,
    this.onRefresh,
  });

  @override
  State<MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<MediaGrid> {
  EnhancedOfflineServiceFactory get _serviceFactory =>
      EnhancedOfflineServiceFactory.instance;

  Future<void> _moveMedia(
      BuildContext context, Map<String, dynamic> mediaItem) async {
    final inspectionId = mediaItem['inspection_id'] as String? ??
        mediaItem['inspectionId'] as String?;
    final mediaId = mediaItem['id'] as String?;

    if (inspectionId == null || mediaId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: IDs inválidos')),
        );
      }
      return;
    }

    // Check if this is offline media
    final isOfflineMedia = mediaItem['source'] == 'offline';

    // Criar descrição da localização atual
    String currentLocation = '';
    if (mediaItem['topic_name'] != null) {
      currentLocation += 'Tópico: ${mediaItem['topic_name']}';
    }
    if (mediaItem['item_name'] != null) {
      currentLocation += ' → Item: ${mediaItem['item_name']}';
    }
    if (mediaItem['detail_name'] != null) {
      currentLocation += ' → Detalhe: ${mediaItem['detail_name']}';
    }
    if (mediaItem['is_non_conformity'] == true) {
      currentLocation += ' (NC)';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MoveMediaDialog(
        inspectionId: inspectionId,
        mediaId: mediaId,
        currentLocation: currentLocation.isEmpty
            ? 'Localização não especificada'
            : currentLocation,
        isOfflineMode: isOfflineMedia,
      ),
    );

    if (result == true && widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  Future<void> _deleteMedia(
      BuildContext context, Map<String, dynamic> mediaItem) async {
    final mediaId = mediaItem['id'] as String?;

    if (mediaId == null) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID da mídia inválido')),
        );
      }
      return;
    }

    // Check if this is offline media
    final isOfflineMedia = mediaItem['source'] == 'offline';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(isOfflineMedia
            ? 'Tem certeza que deseja excluir esta mídia? Esta ação não pode ser desfeita e a mídia será removida permanentemente do armazenamento offline.'
            : 'Tem certeza que deseja excluir esta imagem? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // For offline-first architecture, always use media service
        await _serviceFactory.mediaService.deleteMedia(mediaId);

        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isOfflineMedia
                  ? 'Mídia offline excluída com sucesso!'
                  : 'Imagem excluída com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          if (widget.onRefresh != null) {
            widget.onRefresh!();
          }
        }
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir mídia: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showMediaActions(BuildContext context, Map<String, dynamic> mediaItem) {
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
            ListTile(
              leading: const Icon(Icons.move_up, color: Color(0xFF6F4B99)),
              title: const Text('Mover Mídia',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Mover para outro tópico, item ou detalhe',
                  style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.of(context).pop();
                _moveMedia(context, mediaItem);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir Mídia',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(
                mediaItem['source'] == 'offline'
                    ? 'Remover permanentemente esta mídia offline'
                    : 'Remover permanentemente esta imagem',
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _deleteMedia(context, mediaItem);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: widget.media.length,
      itemBuilder: (context, index) {
        final mediaItem = widget.media[index];
        return _buildMediaGridItem(context, mediaItem);
      },
    );
  }

  Widget _buildMediaGridItem(
      BuildContext context, Map<String, dynamic> mediaItem) {
    final bool isImage = mediaItem['type'] == 'image';
    final bool isNonConformity = mediaItem['is_non_conformity'] == true;
    final String displayPath =
        mediaItem['local_path'] ?? mediaItem['url'] ?? '';
    final String? status = mediaItem['status'] as String?;

    // Format date
    String formattedDate = '';
    if (mediaItem['created_at'] != null) {
      try {
        DateTime date;
        if (mediaItem['created_at'] is Timestamp) {
          date = mediaItem['created_at'].toDate();
        } else if (mediaItem['created_at'] is String) {
          date = DateTime.parse(mediaItem['created_at']);
        } else {
          date = DateTime.now();
        }
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);
      } catch (e) {
        debugPrint('Error formatting date: $e');
      }
    }

    // Create a decoration for the card with consistent dark theme colors
    BoxDecoration decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: isNonConformity
          ? Border.all(color: Colors.red, width: 2)
          : Border.all(color: Colors.grey.shade700),
    );

    // Choose display widget
    Widget displayWidget;
    if (isImage) {
      // displayPath is never null here based on earlier logic
      // Determinar se é arquivo local ou URL
      if (displayPath.startsWith('http') || displayPath.startsWith('https')) {
        // É uma URL - usar widget de cache
        displayWidget = CachedMediaImage(
          mediaUrl: displayPath,
          mediaId: mediaItem['id'] as String?,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingIndicator();
          },
          errorBuilder: (ctx, error, _) => _buildErrorPlaceholder(),
        );
      } else {
        // É um arquivo local
        displayWidget = Image.file(
          File(displayPath),
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, _) => _buildErrorPlaceholder(),
        );
      }
    } else {
      // Video
      displayWidget = Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Center(
            child: Icon(
              Icons.videocam,
              color: Colors.white.withAlpha((255 * 0.7).round()),
              size: 40,
            ),
          ),
          // Add thumbnail if available in the future
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        final currentIndex = widget.media.indexOf(mediaItem);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaViewerScreen(
              mediaItems: widget.media,
              initialIndex: currentIndex,
            ),
          ),
        );
      },
      onLongPress: () {
        _showMediaActions(context, mediaItem);
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        color: Colors.grey[850], // Consistent dark theme
        child: Container(
          decoration: decoration,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main media display
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(7), // Slightly smaller to show border
                child: displayWidget,
              ),

              // Indicators and badges
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNonConformity)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    if (isNonConformity) const SizedBox(width: 4),

                    // Status indicator
                    if (status != null) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status)
                              .withAlpha((255 * 0.8).round()),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isImage
                            ? const Color(0xFF6F4B99)
                                .withAlpha((255 * 0.8).round())
                            : Colors.purple.withAlpha((255 * 0.8).round()),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _getMediaIcon(mediaItem, isImage),
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Botão de ações no canto superior direito
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _showMediaActions(context, mediaItem),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

              // Informações de tópico/item/detalhe
              if (mediaItem['topic_name'] != null)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((255 * 0.7).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mediaItem['topic_name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Date
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha((255 * 0.7).round()),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Observation indicator if available
              if (mediaItem['observation'] != null &&
                  (mediaItem['observation'] as String).isNotEmpty)
                Positioned(
                  bottom: 16,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha((255 * 0.8).round()),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.comment,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Métodos auxiliares para status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'uploaded':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
        return const Color(0xFF6F4B99);
      case 'local':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'uploaded':
        return Icons.cloud_done;
      case 'pending':
        return Icons.cloud_upload;
      case 'processing':
        return Icons.refresh;
      case 'local':
        return Icons.storage;
      default:
        return Icons.help_outline;
    }
  }

  IconData _getMediaIcon(Map<String, dynamic> mediaItem, bool isImage) {
    final source = mediaItem['source'] as String?;

    // Parse metadata if it's a JSON string
    Map<String, dynamic>? metadata;
    if (mediaItem['metadata'] != null) {
      if (mediaItem['metadata'] is String) {
        try {
          metadata = Map<String, dynamic>.from(
              jsonDecode(mediaItem['metadata'] as String));
        } catch (e) {
          debugPrint('MediaGrid._getMediaIcon: Error parsing metadata: $e');
        }
      } else if (mediaItem['metadata'] is Map) {
        metadata = mediaItem['metadata'] as Map<String, dynamic>?;
      }
    }

    final metadataSource = metadata?['source'] as String?;

    // Verificar se é da camera (source direto ou no metadata)
    final isFromCamera = source == 'camera' || metadataSource == 'camera';

    // Debug log para verificar os valores
    debugPrint(
        'MediaGrid._getMediaIcon: source=$source, metadataSource=$metadataSource, isFromCamera=$isFromCamera');

    if (isImage) {
      return isFromCamera ? Icons.camera_alt : Icons.folder;
    } else {
      return isFromCamera ? Icons.videocam : Icons.video_library;
    }
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.red,
          size: 32,
        ),
      ),
    );
  }

  // Method removed - not used anywhere
}
