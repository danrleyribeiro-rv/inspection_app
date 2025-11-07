// lib/presentation/screens/media/components/media_grid.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lince_inspecoes/presentation/screens/media/media_viewer_screen.dart';
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';
import 'package:lince_inspecoes/presentation/widgets/common/cached_media_image.dart';
import 'package:lince_inspecoes/presentation/widgets/dialogs/move_media_dialog.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';

class MediaGrid extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final Function(Map<String, dynamic>) onTap;
  final Function()? onRefresh;
  final Function(Map<String, dynamic>)? onLongPress;
  final bool isMultiSelectMode;
  final Set<String> selectedMediaIds;

  const MediaGrid({
    super.key,
    required this.media,
    required this.onTap,
    this.onRefresh,
    this.onLongPress,
    this.isMultiSelectMode = false,
    this.selectedMediaIds = const {},
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
          const SnackBar(
            content: Text('Erro: IDs inválidos'),
            duration: Duration(seconds: 2),
          ),
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
          const SnackBar(
            content: Text('Erro: ID da mídia inválido'),
            duration: Duration(seconds: 2),
          ),
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
        debugPrint('MediaGrid: Deleting media with ID: $mediaId');

        // For offline-first architecture, always use media service
        await _serviceFactory.mediaService.deleteMedia(mediaId);

        debugPrint('MediaGrid: Media deleted successfully, calling refresh');

        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isOfflineMedia
                  ? 'Mídia offline excluída com sucesso!'
                  : 'Imagem excluída com sucesso!'),
              backgroundColor: Colors.green,
              duration: const Duration(milliseconds: 800),
            ),
          );
          if (widget.onRefresh != null) {
            debugPrint('MediaGrid: Calling onRefresh callback');
            // Add a small delay to ensure database transaction is completed
            await Future.delayed(const Duration(milliseconds: 50));
            await widget.onRefresh!();
            debugPrint('MediaGrid: onRefresh callback completed');
          } else {
            debugPrint('MediaGrid: No onRefresh callback available');
          }
        }
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir mídia: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
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
      useSafeArea: true, // This ensures it respects system bars
      isScrollControlled: true, // Allows better control over size
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 +
                MediaQuery.of(context).viewInsets.bottom, // Respect keyboard
          ),
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
                title: const Text('Mover Mídia(s)',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                subtitle: const Text('Mover para outro tópico, item ou detalhe',
                    style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.of(context).pop();
                  _moveMedia(context, mediaItem);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Excluir Mídia(s)',
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
              const SizedBox(height: 8), // Reduced spacing
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Simple key based on media count only to avoid excessive rebuilds
    return GridView.builder(
      key: ValueKey('media-grid-${widget.media.length}'),
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

    // Simple unique key based on media ID only
    final uniqueKey = ValueKey('media-item-${mediaItem['id']}');

    // Try multiple path formats for compatibility
    String displayPath = '';
    if (mediaItem['localPath'] != null &&
        mediaItem['localPath'].toString().isNotEmpty) {
      displayPath = mediaItem['localPath'].toString();
    } else if (mediaItem['local_path'] != null &&
        mediaItem['local_path'].toString().isNotEmpty) {
      displayPath = mediaItem['local_path'].toString();
    } else if (mediaItem['cloudUrl'] != null &&
        mediaItem['cloudUrl'].toString().isNotEmpty) {
      displayPath = mediaItem['cloudUrl'].toString();
    } else if (mediaItem['url'] != null &&
        mediaItem['url'].toString().isNotEmpty) {
      displayPath = mediaItem['url'].toString();
    }

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
    // Check if this is resolution media
    final source = mediaItem['source'] as String?;
    final isResolutionMedia =
        source == 'resolution_camera' || source == 'resolution_gallery';

    BoxDecoration decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: isNonConformity
          ? (isResolutionMedia
              ? Border.all(
                  color: Colors.green, width: 2) // Green for resolution media
              : Border.all(
                  color: Colors.red, width: 2)) // Red for regular NC media
          : Border.all(color: Colors.grey.shade700),
    );

    // Choose display widget
    Widget displayWidget;
    if (isImage) {
      // Priorizar thumbnail se disponível, depois arquivo local, depois URL
      String? imagePath;

      // 1. Verificar se há thumbnail disponível
      final thumbnailPath =
          mediaItem['thumbnail_path'] ?? mediaItem['thumbnailPath'];
      if (thumbnailPath != null && thumbnailPath.toString().isNotEmpty) {
        final thumbnailFile = File(thumbnailPath.toString());
        if (thumbnailFile.existsSync()) {
          imagePath = thumbnailPath.toString();
        }
      }

      // 2. Se não há thumbnail, usar arquivo local principal
      if (imagePath == null &&
          displayPath.isNotEmpty &&
          !displayPath.startsWith('http')) {
        final file = File(displayPath);
        if (file.existsSync()) {
          imagePath = displayPath;
        }
      }

      // 3. Se é uma URL, usar widget de cache
      if (imagePath == null &&
          (displayPath.startsWith('http') || displayPath.startsWith('https'))) {
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
      } else if (imagePath != null) {
        // Usar arquivo local (thumbnail ou original)
        displayWidget = Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, _) {
            debugPrint('MediaGrid: Error loading image: $error');
            return _buildErrorPlaceholder();
          },
        );
      } else {
        // Nenhuma imagem disponível
        debugPrint(
            'MediaGrid: No image available for media ${mediaItem['id']}');
        displayWidget = _buildErrorPlaceholder();
      }
    } else {
      // Video - verificar se há thumbnail de vídeo
      final thumbnailPath =
          mediaItem['thumbnail_path'] ?? mediaItem['thumbnailPath'];

      if (thumbnailPath != null && thumbnailPath.toString().isNotEmpty) {
        final thumbnailFile = File(thumbnailPath.toString());
        if (thumbnailFile.existsSync()) {
          // Usar thumbnail do vídeo
          displayWidget = Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                thumbnailFile,
                fit: BoxFit.cover,
              ),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((255 * 0.6).round()),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          );
        } else {
          // Placeholder para vídeo sem thumbnail
          displayWidget = _buildVideoPlaceholder();
        }
      } else {
        // Placeholder para vídeo sem thumbnail
        displayWidget = _buildVideoPlaceholder();
      }
    }

    // Check if this media is selected
    final isSelected = widget.selectedMediaIds.contains(mediaItem['id']);

    return GestureDetector(
      key: uniqueKey,
      onTap: () {
        if (widget.isMultiSelectMode) {
          widget.onTap(mediaItem);
        } else {
          final currentIndex = widget.media.indexOf(mediaItem);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaViewerScreen(
                mediaItems: widget.media,
                initialIndex: currentIndex,
              ),
            ),
          );
        }
      },
      onLongPress: () {
        if (widget.onLongPress != null) {
          widget.onLongPress!(mediaItem);
        } else {
          _showMediaActions(context, mediaItem);
        }
      },
      child: Card(
        elevation: isSelected ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? const BorderSide(color: Color(0xFF6F4B99), width: 3)
              : BorderSide.none,
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
                        isImage ? Icons.image : Icons.videocam,
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

              // Identificador de origem melhorado
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((255 * 0.8).round()),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Origem da mídia (tópico/item/detalhe)
                      Text(
                        _buildOriginText(mediaItem),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Exibir apenas informações de NC se disponível
                      if (mediaItem['is_non_conformity'] == true)
                        Text(
                          '⚠️ NC',
                          style: TextStyle(
                            color: Colors.white.withAlpha((255 * 0.8).round()),
                            fontSize: 8,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
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
                    maxLines: 3,
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

              // Selection indicator for multi-select mode
              if (widget.isMultiSelectMode)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6F4B99)
                          : Colors.black.withAlpha((255 * 0.6).round()),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
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

  // Helper method to parse metadata consistently

  Widget _buildLoadingIndicator() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: AdaptiveProgressIndicator(
          radius: 10.0,
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

  Widget _buildVideoPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.grey.shade800),
        Center(
          child: Icon(
            Icons.videocam,
            color: Colors.white.withAlpha((255 * 0.7).round()),
            size: 40,
          ),
        ),
      ],
    );
  }

  String _buildOriginText(Map<String, dynamic> mediaItem) {
    List<String> parts = [];

    if (mediaItem['topic_name'] != null) {
      parts.add('T: ${mediaItem['topic_name']}');
    }
    if (mediaItem['item_name'] != null) {
      parts.add('I: ${mediaItem['item_name']}');
    }
    if (mediaItem['detail_name'] != null) {
      parts.add('D: ${mediaItem['detail_name']}');
    }

    if (parts.isEmpty) {
      return 'Mídia da Inspeção';
    }

    return parts.join(' → ');
  }
}
