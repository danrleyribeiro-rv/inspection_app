import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert'; // For utf8.encode

class CachedMapImage extends StatefulWidget {
  final String mapUrl;
  final double height;
  final BoxFit fit;

  const CachedMapImage({
    super.key,
    required this.mapUrl,
    this.height = 80,
    this.fit = BoxFit.cover,
  });

  @override
  State<CachedMapImage> createState() => _CachedMapImageState();
}

class _CachedMapImageState extends State<CachedMapImage> {
  File? _cachedImageFile;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isOnline = false;

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
      final fileName = _generateFileName(widget.mapUrl);
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(appDir.path, 'map_cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final cachedFilePath = p.join(cacheDir.path, fileName);
      final cachedFile = File(cachedFilePath);
      
      if (await cachedFile.exists()) {
        // We have cached image, use it
        if (mounted) {
          setState(() {
            _cachedImageFile = cachedFile;
            _isLoading = false;
          });
        }
        log('[CachedMapImage] Using cached image for URL: ${widget.mapUrl}');
        return;
      }

      // No cached image, check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult.contains(ConnectivityResult.wifi) || 
                  connectivityResult.contains(ConnectivityResult.mobile);

      if (_isOnline) {
        // Online and no cache, download and cache
        log('[CachedMapImage] Downloading and caching image for URL: ${widget.mapUrl}');
        final response = await http.get(Uri.parse(widget.mapUrl));
        
        if (response.statusCode == 200) {
          await cachedFile.writeAsBytes(response.bodyBytes);
          if (mounted) {
            setState(() {
              _cachedImageFile = cachedFile;
              _isLoading = false;
              _hasError = false;
            });
          }
          log('[CachedMapImage] Successfully downloaded and cached image');
        } else {
          log('[CachedMapImage] Failed to download image: HTTP ${response.statusCode}');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
        }
      } else {
        // Offline and no cache - still show placeholder but without error
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
        log('[CachedMapImage] Offline and no cached image available');
      }
    } catch (e) {
      log('[CachedMapImage] Error loading image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _generateFileName(String url) {
    final bytes = utf8.encode(url); // data being hashed
    final digest = md5.convert(bytes);
    return '${digest.toString()}.png'; // Assuming PNG for map tiles
  }

  Widget _buildPlaceholder({bool error = false}) {
    return Container(
      height: widget.height,
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.map_outlined,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 4),
          Text(
            error ? 'Erro ao carregar mapa' : 'Carregando mapa...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPlaceholder();
    }

    // Always try to show cached image first (online or offline)
    if (_cachedImageFile != null && _cachedImageFile!.existsSync()) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Image.file(
          _cachedImageFile!,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) {
            log('[CachedMapImage] Error displaying cached image: $error');
            return _buildPlaceholder(error: true);
          },
        ),
      );
    }

    // Only show error if we have an error
    if (_hasError) {
      return _buildPlaceholder(error: true);
    }

    // If no cached image and no error, show loading placeholder
    return _buildPlaceholder();
  }
}