import 'dart:io';
import 'package:flutter/material.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'dart:developer';

class CachedMediaImage extends StatefulWidget {
  final String mediaUrl;
  final String? mediaId;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const CachedMediaImage({
    super.key,
    required this.mediaUrl,
    this.mediaId,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<CachedMediaImage> createState() => _CachedMediaImageState();
}

class _CachedMediaImageState extends State<CachedMediaImage> {
  File? _localFile;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    
    try {
      final cacheService = ServiceFactory().cacheService;
      
      // First, try to find local cached media by URL or ID
      if (widget.mediaId != null) {
        final cachedMedia = cacheService.getOfflineMedia(widget.mediaId!);
        if (cachedMedia != null && cachedMedia.isDownloadedFromCloud) {
          final file = File(cachedMedia.localPath);
          if (await file.exists()) {
            if (mounted) {
              setState(() {
                _localFile = file;
                _isLoading = false;
              });
            }
            log('[CachedMediaImage] Using cached media file: ${cachedMedia.localPath}');
            return;
          }
        }
      }
      
      // If no local file found, will fallback to network image
      // The download process should have cached the media already
      
      // No local cache found - this should fallback to network image
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      log('[CachedMediaImage] No cached media found, will use network image');
      
    } catch (e) {
      log('[CachedMediaImage] Error loading cached image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _errorMessage ?? 'Unknown error', null);
    }
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // If we have a local file, use it
    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder,
      );
    }
    
    // Fallback to network image if no local cache
    return Image.network(
      widget.mediaUrl,
      fit: widget.fit,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: widget.errorBuilder,
    );
  }
}