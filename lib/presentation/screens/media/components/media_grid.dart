// lib/presentation/screens/media/components/media_grid.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MediaGrid extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final Function(Map<String, dynamic>) onTap;

  const MediaGrid({
    super.key,
    required this.media,
    required this.onTap,
  });

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
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        return _buildMediaGridItem(context, mediaItem);
      },
    );
  }

  Widget _buildMediaGridItem(
      BuildContext context, Map<String, dynamic> mediaItem) {
    final bool isImage = mediaItem['type'] == 'image';
    final bool isNonConformity = mediaItem['is_non_conformity'] == true;
    final bool hasUrl =
        mediaItem['url'] != null && (mediaItem['url'] as String).isNotEmpty;
    final bool hasLocalPath = mediaItem['localPath'] != null &&
        (mediaItem['localPath'] as String).isNotEmpty;

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
        print('Error formatting date: $e');
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
      if (hasLocalPath) {
        final file = File(mediaItem['localPath']);
        if (file.existsSync()) {
          displayWidget = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (ctx, error, _) => _buildErrorPlaceholder(),
          );
        } else if (hasUrl) {
          displayWidget = Image.network(
            mediaItem['url'],
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildLoadingIndicator();
            },
            errorBuilder: (ctx, error, _) => _buildErrorPlaceholder(),
          );
        } else {
          displayWidget = _buildNoSourcePlaceholder('image');
        }
      } else if (hasUrl) {
        displayWidget = Image.network(
          mediaItem['url'],
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingIndicator();
          },
          errorBuilder: (ctx, error, _) => _buildErrorPlaceholder(),
        );
      } else {
        displayWidget = _buildNoSourcePlaceholder('image');
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
              color: Colors.white.withOpacity(0.7),
              size: 40,
            ),
          ),
          // Add thumbnail if available in the future
        ],
      );
    }

    return InkWell(
      onTap: () => onTap(mediaItem),
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
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isImage
                            ? Colors.blue.withOpacity(0.8)
                            : Colors.purple.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isImage ? Icons.photo : Icons.videocam,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
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
                      color: Colors.black.withOpacity(0.7),
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
                        Colors.black.withOpacity(0.7),
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
                      color: Colors.grey.withOpacity(0.8),
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

  Widget _buildNoSourcePlaceholder(String type) {
    return Container(
      color: Colors.grey.shade800,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == 'image' ? Icons.image_not_supported : Icons.videocam_off,
            color: Colors.grey.shade400,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            'Sem fonte',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
