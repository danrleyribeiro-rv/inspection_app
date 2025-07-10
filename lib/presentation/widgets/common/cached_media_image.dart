import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lince_inspecoes/services/features/media_service.dart'; // Use MediaService
import 'dart:developer';

class CachedMediaImage extends StatefulWidget {
  final String mediaUrl; // This will now primarily be a cloud URL
  final String? mediaId; // This will be the ID to look up in local storage
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

  final MediaService _mediaService =
      MediaService.instance; // Get MediaService instance

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      if (widget.mediaId != null) {
        final file = await _mediaService
            .getMediaFile(widget.mediaId!); // Get file from MediaService
        if (file != null && await file.exists()) {
          if (mounted) {
            setState(() {
              _localFile = file;
              _isLoading = false;
            });
          }
          log('[CachedMediaImage] Using local media file: ${file.path}');
          return;
        }
      }

      // If no local file found or mediaId is null, fallback to network image
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      log('[CachedMediaImage] No local media found, will use network image for: ${widget.mediaUrl}');
    } catch (e) {
      log('[CachedMediaImage] Error loading media: $e');
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
      return widget.errorBuilder!(
          context, _errorMessage ?? 'Unknown error', null);
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
