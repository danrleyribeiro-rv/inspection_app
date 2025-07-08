// lib/presentation/widgets/media/custom_camera_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

enum CaptureMode { photo, video }

class CustomCameraWidget extends StatefulWidget {
  final Function(List<String> localPaths, String type) onMediaCaptured;
  final bool allowVideo;

  const CustomCameraWidget({
    super.key,
    required this.onMediaCaptured,
    this.allowVideo = true,
  });

  @override
  State<CustomCameraWidget> createState() => _CustomCameraWidgetState();
}

class _CustomCameraWidgetState extends State<CustomCameraWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  CaptureMode _captureMode = CaptureMode.photo;
  FlashMode _flashMode = FlashMode.auto;
  bool _isRecording = false;
  bool _isTakingPicture = false;

  final List<String> _capturedMediaPaths = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initializeCamera([int cameraIndex = 0]) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('Nenhuma câmera encontrada.');
        return;
      }

      _selectedCameraIndex = (cameraIndex < _cameras.length) ? cameraIndex : 0;
      await _setupController();
    } catch (e) {
      debugPrint('Erro ao inicializar câmera: $e');
    }
  }

  Future<void> _setupController() async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final camera = _cameras[_selectedCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: widget.allowVideo,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      if (mounted) setState(() {});
    } on CameraException catch (e) {
      debugPrint('Erro ao configurar câmera: ${e.code} - ${e.description}');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initializeCamera(newIndex);
  }

  Future<void> _toggleFlash() async {
    if (_isRecording) return;
    final modes = [FlashMode.auto, FlashMode.always, FlashMode.off];
    final currentIndex = modes.indexOf(_flashMode);
    _flashMode = modes[(currentIndex + 1) % modes.length];
    await _controller?.setFlashMode(_flashMode);
    if (mounted) setState(() {});
  }

  void _switchCaptureMode() {
    if (!widget.allowVideo || _isRecording || _capturedMediaPaths.isNotEmpty) return;
    setState(() {
      _captureMode = _captureMode == CaptureMode.photo
          ? CaptureMode.video
          : CaptureMode.photo;
    });
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture) return;
    
    setState(() => _isTakingPicture = true);
    
    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        setState(() {
          _capturedMediaPaths.add(image.path);
        });
      }
    } catch (e) {
      debugPrint('Erro ao capturar foto: $e');
    } finally {
      if (mounted) {
        setState(() => _isTakingPicture = false);
      }
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Erro ao iniciar gravação: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isRecording) return;
    try {
      final video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _capturedMediaPaths.add(video.path);
        _finishCapture();
      });
    } catch (e) {
      debugPrint('Erro ao parar gravação: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }
  
  void _finishCapture() {
    if (_capturedMediaPaths.isNotEmpty) {
      widget.onMediaCaptured(
        List.from(_capturedMediaPaths),
        _captureMode == CaptureMode.photo ? 'image' : 'video'
      );
    }
    Navigator.of(context).pop();
  }

  void _removeCapturedMedia(int index) {
    setState(() {
      _capturedMediaPaths.removeAt(index);
    });
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRect(
          child: Transform.scale(
            scale: _controller!.value.aspectRatio / (3/4),
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.auto: return Icons.flash_auto;
      case FlashMode.always: return Icons.flash_on;
      case FlashMode.off: return Icons.flash_off;
      default: return Icons.flash_auto;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildCameraPreview()),
            _buildTopBar(),
            _buildBottomBar(),
            if (_isRecording) _buildRecordingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black.withValues(alpha: 0.3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (widget.allowVideo && _capturedMediaPaths.isEmpty)
              GestureDetector(
                onTap: _switchCaptureMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt, color: _captureMode == CaptureMode.photo ? Colors.white : Colors.white54, size: 20),
                      const SizedBox(width: 8),
                      Icon(Icons.videocam, color: _captureMode == CaptureMode.video ? Colors.white : Colors.white54, size: 20),
                    ],
                  ),
                ),
              ),
            IconButton(
              icon: Icon(_getFlashIcon(), color: Colors.white),
              onPressed: _toggleFlash,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Column(
          children: [
            _buildThumbnailGallery(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.flip_camera_ios,
                      color: _cameras.length < 2 ? Colors.grey : Colors.white,
                      size: 32,
                    ),
                    onPressed: _switchCamera,
                  ),
                  _buildCaptureButton(),
                  SizedBox(
                    width: 64,
                    height: 48,
                    child: _capturedMediaPaths.isNotEmpty
                        ? FloatingActionButton(
                            onPressed: _finishCapture,
                            backgroundColor: Colors.green,
                            child: const Icon(Icons.check, color: Colors.white),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _captureMode == CaptureMode.photo
          ? _capturePhoto
          : (_isRecording ? _stopVideoRecording : _startVideoRecording),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
          ),
          if (_isTakingPicture)
            const SizedBox(width: 70, height: 70, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4)),
          if (!_isTakingPicture)
            Container(
              width: _isRecording ? 30 : 58,
              height: _isRecording ? 30 : 58,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(_isRecording ? 8 : 58),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGallery() {
    if (_capturedMediaPaths.isEmpty) {
      return const SizedBox(height: 80);
    }
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _capturedMediaPaths.length,
        itemBuilder: (context, index) {
          final path = _capturedMediaPaths[index];
          return Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                  image: DecorationImage(
                    image: FileImage(File(path)),
                    fit: BoxFit.cover,
                  ),
                ),
                child: _captureMode == CaptureMode.video ? const Icon(Icons.play_circle_fill, color: Colors.white70, size: 30) : null,
              ),
              InkWell(
                onTap: () => _removeCapturedMedia(index),
                child: Container(
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
              SizedBox(width: 6),
              Text('REC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}