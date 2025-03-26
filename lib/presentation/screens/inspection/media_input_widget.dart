// lib/presentation/screens/inspection/media_input_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';

class MediaInputWidget extends StatefulWidget {
  final dynamic mediaRequirements;
  final String itemKey;
  final String detailName;
  final int inspectionId;
  final List<dynamic> rooms;
  final Map<int, int> roomIndexToIdMap;
  final Map<String, int> itemIndexToIdMap;

  const MediaInputWidget({
    super.key,
    required this.mediaRequirements,
    required this.itemKey,
    required this.detailName,
    required this.inspectionId,
    required this.rooms,
    required this.roomIndexToIdMap,
    required this.itemIndexToIdMap,
  });

  @override
  State<MediaInputWidget> createState() => _MediaInputWidgetState();
}

class _MediaInputWidgetState extends State<MediaInputWidget> {
  final _supabase = Supabase.instance.client;
  List<String> _imageUrls = [];
  List<String> _videoUrls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);

    try {
      final itemKeyParts = widget.itemKey.split('-');
      print("itemKeyParts: $itemKeyParts");

      int? roomId;
      int? roomItemId;

      try {
        roomId = int.tryParse(itemKeyParts[0].split('_')[1]);
        roomItemId = int.tryParse(itemKeyParts[1].split('_')[1]);
        print("Parsed roomId: $roomId, roomItemId: $roomItemId");
      } catch (e) {
        print("Error parsing room or item ID: $e");
        return;
      }

      if (roomId == null || roomItemId == null) {
        print("Room ID or Room Item ID is null.");
        return;
      }

      final detailsData = await _supabase
          .from('item_details')
          .select('id')
          .eq('room_item_id', roomItemId)
          .eq('detail_name', widget.detailName)
          .limit(1);

      print("detailsData: $detailsData");

      int? detailId;
      if (detailsData.isNotEmpty) {
        detailId = detailsData[0]['id'];
      }

      print("detailId: $detailId");


      final mediaList = await _supabase
          .from('media')
          .select('url, type')
          .eq('inspection_id', widget.inspectionId)
          .eq('room_id', roomId)
          .eq('room_item_id', roomItemId) // Now roomItemId is guaranteed to be non-null
          .filter('detail_id', 'is',
              detailId) // Always use filter/is for nullable
          .order('created_at', ascending: false);

      print("mediaList: $mediaList");

      if (mounted) {
        setState(() {
          _imageUrls = [];
          _videoUrls = [];
          for (final media in mediaList) {
            if (media['type'] == 'image') {
              _imageUrls.add(media['url'] as String);
            } else if (media['type'] == 'video') {
              _videoUrls.add(media['url'] as String);
            }
          }
        });
      }
    } catch (e) {
      print("Error in _loadMedia: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<(int? roomId, int? roomItemId, int? detailId)> _getIds() async {
    final itemKeyParts = widget.itemKey.split('-');
    if (itemKeyParts.length < 2) {
      print("Invalid itemKey format: ${widget.itemKey}");
      return (null, null, null);
    }
    final roomKey = itemKeyParts[0];
    final itemKey = itemKeyParts[1];

    // Extrai roomIndex e itemIndex do itemKey.  Fundamental!
    final roomIndex = int.parse(roomKey.split('_')[1]);
    final itemIndex = int.parse(itemKey.split('_')[1]);

    // 1. Usa o roomIndex para pegar o roomId do mapa. Muito mais simples!
    int? roomId = widget.roomIndexToIdMap[roomIndex];
    if (roomId == null) {
      print("Error: roomId is null for roomIndex: $roomIndex");
      return (null, null, null);
    }


    // 2. Usa roomIndex e itemIndex para pegar o itemID do mapa.
    int? roomItemId = widget.itemIndexToIdMap['$roomIndex-$itemIndex'];
    if (roomItemId == null) {
      print("Error: roomItemId is null for roomIndex: $roomIndex, itemIndex: $itemIndex");
      return (null, null, null);
    }


    // 3. Verifica se o detail existe, e cria se necessário (igual ao anterior)
    final detailsData = await _supabase
        .from('item_details')
        .select('id')
        .eq('room_item_id', roomItemId) //  <--  Adicionado !
        .eq('detail_name', widget.detailName)
        .limit(1);

    int? detailId = detailsData.isNotEmpty ? detailsData[0]['id'] : null;

    if (detailId == null) {
      print('Warning: DetailId está null, isso não deveria acontecer!');  //Não deve mais ocorrer
      return (null, null, null);

    }

    return (roomId, roomItemId, detailId);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_imageUrls.length >= (widget.mediaRequirements['images']?['max'] ?? 0)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Maximum number of images reached (${widget.mediaRequirements['images']?['max'] ?? 0})')),
      );
      return;
    }

    final picker = ImagePicker();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final XFile? pickedFile = await picker.pickImage(
        source: source, maxWidth: 800, maxHeight: 800, imageQuality: 70);

    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      // Agora, _getIds() simplesmente busca os valores dos mapas.
      final (roomId, roomItemId, detailId) = await _getIds();
      if (roomId == null || roomItemId == null || detailId == null) {  //Verifica detailId também
        print("Error: roomId, roomItemId, or detailId is null in _pickImage."); // Log detalhado
        return;
      }


      final fileExt = p.extension(pickedFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'image_${roomId}_${roomItemId}_${detailId ?? "general"}_$timestamp$fileExt';
      final filePath =
          '/inspections/${widget.inspectionId}/$roomId/$roomItemId/${detailId ?? "general"}/$fileName';

      final storageResponse = await _supabase.storage
          .from('inspection_media')
          .upload(filePath, File(pickedFile.path));

      if (storageResponse.isNotEmpty) {
        final String publicUrl = _supabase.storage
            .from('inspection_media')
            .getPublicUrl(filePath);

        await _supabase.from('media').insert({
          'type': 'image',
          'url': publicUrl,
          'inspection_id': widget.inspectionId,
          'room_id': roomId, // roomId is checked for null above
          'room_item_id': roomItemId, // roomItemId is checked for null above
          'detail_id': detailId,
          'section': widget.detailName
        });

        if (mounted) {
          setState(() => _imageUrls.add(publicUrl));
        }
      }
    } catch (e) {
      print("Error during image upload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_videoUrls.length >= (widget.mediaRequirements['videos']?['max'] ?? 0)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Maximum number of videos reached (${widget.mediaRequirements['videos']?['max'] ?? 0})')),
      );
      return;
    }

    final picker = ImagePicker();

    // Force Landscape Mode BEFORE picking
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final XFile? pickedFile = await picker.pickVideo(
        source: source, maxDuration: const Duration(minutes: 1));

    // Reset Orientation here:
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      // Agora, _getIds() simplesmente busca os valores dos mapas.
      final (roomId, roomItemId, detailId) = await _getIds();
      if (roomId == null || roomItemId == null || detailId == null) { //Verifica detailId
        print("Error: roomId, roomItemId, or detailId is null in _pickVideo"); //Log Detalhado
        return;
      }


      final fileExt = p.extension(pickedFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'video_${roomId}_${roomItemId}_${detailId ?? "general"}_$timestamp$fileExt';
      final filePath =
          '/inspections/${widget.inspectionId}/$roomId/$roomItemId/${detailId ?? "general"}/$fileName';

      final storageResponse = await _supabase.storage
          .from('inspection_media')
          .upload(filePath, File(pickedFile.path),
              fileOptions: const FileOptions(contentType: 'video/mp4'));

      if (storageResponse.isNotEmpty) {
        final String publicUrl = _supabase.storage
            .from('inspection_media')
            .getPublicUrl(filePath);

        await _supabase.from('media').insert({
          'type': 'video',
          'url': publicUrl,
          'inspection_id': widget.inspectionId, // Use directly!
          'room_id': roomId, // Use the *actual* ID!
          'room_item_id': roomItemId, // Use the *actual* ID!
          'detail_id': detailId, // Use detailId, can be null.
          'section': widget.detailName,
        });

        if (mounted) {
          setState(() => _videoUrls.add(publicUrl));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMedia(String url, String type) async {
    try {
      setState(() => _isLoading = true);
      final uri = Uri.parse(url);
      final decodedPath = Uri.decodeFull(uri.path);
      final bucketName = 'inspection_media';
      final filePath = decodedPath.replaceFirst('/$bucketName/', '');

      await _supabase.storage.from(bucketName).remove([filePath]);
      await _supabase.from('media').delete().eq('url', url);

      if (mounted) {
        setState(() {
          if (type == 'image') {
            _imageUrls.remove(url);
          } else if (type == 'video') {
            _videoUrls.remove(url);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Media:'),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _pickVideo(ImageSource.camera),
              icon: const Icon(Icons.videocam),
              label: const Text('Record Video'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading) const CircularProgressIndicator(),

        // Display Images
        if (_imageUrls.isNotEmpty)
          SizedBox(
            height: 100, // Fixed height for horizontal list
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.network(_imageUrls[index],
                          width: 100, height: 100, fit: BoxFit.cover),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _removeMedia(_imageUrls[index], 'image'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Display Videos
        if (_videoUrls.isNotEmpty)
          SizedBox(
            height: 100, // Fixed height for horizontal list
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _videoUrls.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey,
                          child: const Center(
                              child: Icon(Icons.play_arrow,
                                  size: 50, color: Colors.white))),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _removeMedia(_videoUrls[index], 'video'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}