import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:image/image.dart' as img;
import 'package:lince_inspecoes/services/enhanced_offline_service_factory.dart';

class InspectionCameraScreen extends StatefulWidget {
  final String inspectionId;
  final String? topicId;
  final String? itemId;
  final String? detailId;
  final String? nonConformityId;
  final String? source;
  final Function(List<String> capturedFiles)? onMediaCaptured;

  const InspectionCameraScreen({
    super.key,
    required this.inspectionId,
    this.topicId,
    this.itemId,
    this.detailId,
    this.nonConformityId,
    this.source,
    this.onMediaCaptured,
  });

  @override
  State<InspectionCameraScreen> createState() => _InspectionCameraScreenState();
}

class _InspectionCameraScreenState extends State<InspectionCameraScreen> with WidgetsBindingObserver {
  CameraController? cameraController;
  Future<void>? cameraValue;
  bool isFlashOn = false;
  bool isRecording = false;
  bool isVideoMode = false;
  bool _isButtonTapped = false;
  List<String> capturedFiles = [];
  Timer? recordingTimer;
  int recordingDuration = 0;
  double deviceRotation = 0.0;
  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;
  final EnhancedOfflineServiceFactory _serviceFactory = EnhancedOfflineServiceFactory.instance;

  Future<String> getMediaPath(String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    return '${directory.path}/$fileName';
  }

  bool isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ext == "mp4" || ext == "mov";
  }

  void toggleFlash() async {
    if (cameraController?.value.isInitialized != true) return;
    isFlashOn = !isFlashOn;
    await cameraController!.setFlashMode(
        isFlashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  void toggleMode() {
    setState(() {
      isVideoMode = !isVideoMode;
    });
  }

  bool _isCapturing = false;

  Future<void> takePhoto() async {
    // Evitar múltiplas capturas simultâneas
    if (_isCapturing ||
        cameraController?.value.isInitialized != true ||
        cameraController!.value.isTakingPicture) {
      debugPrint('Camera: Photo capture blocked - capturing: $_isCapturing, initialized: ${cameraController?.value.isInitialized}, taking: ${cameraController?.value.isTakingPicture}');
      return;
    }

    _isCapturing = true;

    try {
      // Verificar se o controller ainda está válido antes de usar
      final controller = cameraController;
      if (controller == null || !controller.value.isInitialized) {
        throw Exception('Camera controller não está disponível');
      }

      debugPrint('Camera: Taking photo...');
      final image = await controller.takePicture();
      final imageBytes = await image.readAsBytes();

      // Decodificar a imagem
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Erro ao decodificar imagem');
      }

      // Rotaciona a imagem para corresponder à orientação do dispositivo no momento da captura.
      // A imagem decodificada (originalImage) já vem orientada em pé (retrato).
      // `deviceRotation` nos dá a orientação do aparelho, então rotacionamos para corresponder.
      final angle = deviceRotation * 180 / math.pi;
      final correctedImage = img.copyRotate(originalImage, angle: angle);

      // Salvar a imagem corrigida
      final path = await getMediaPath("jpg");
      final file = File(path);
      await file.writeAsBytes(img.encodeJpg(correctedImage));

      // Salvar automaticamente na vistoria
      await _saveMediaToInspection(path, 'image');

      if (mounted) {
        setState(() => capturedFiles.add(path));
      }

      debugPrint('Camera: Photo captured successfully: $path');
    } catch (e) {
      debugPrint('Camera: Error capturing photo: $e');
      if (mounted) {
        _showCaptureError('Erro ao capturar foto: $e');
      }
    } finally {
      _isCapturing = false;
    }
  }

  DeviceOrientation _getOrientationFromRotation(double rotation) {
    final degrees = rotation * 180 / math.pi;
    // The video was being saved inverted, so we swap the landscape orientations
    // to correct the final output.
    if (degrees > 45 && degrees < 135) { // deviceRotation is pi/2 (Landscape Left)
      return DeviceOrientation.landscapeRight; // Return opposite
    } else if (degrees < -45 && degrees > -135) { // deviceRotation is -pi/2 (Landscape Right)
      return DeviceOrientation.landscapeLeft; // Return opposite
    } else if (degrees >= 135 || degrees <= -135) {
      return DeviceOrientation.portraitDown;
    } else {
      return DeviceOrientation.portraitUp;
    }
  }

  Future<void> startVideoRecording() async {
    if (cameraController?.value.isInitialized != true || cameraController!.value.isRecordingVideo) return;

    try {
      final orientation = _getOrientationFromRotation(deviceRotation);
      await cameraController!.lockCaptureOrientation(orientation);
      await cameraController!.startVideoRecording();
      isRecording = true;
      startRecordingTimer();
      setState(() {});
    } catch (e) {
      _showCaptureError('Erro ao iniciar gravação: $e');
    }
  }

  Future<void> stopVideoRecording() async {
    if (cameraController?.value.isInitialized != true || cameraController!.value.isRecordingVideo != true) return;

    try {
      final video = await cameraController!.stopVideoRecording();
      final path = await getMediaPath("mp4");
      final file = File(path);
      await file.writeAsBytes(await video.readAsBytes());
      
      // Salvar automaticamente na vistoria
      await _saveMediaToInspection(path, 'video');
      
      isRecording = false;
      stopRecordingTimer();
      setState(() => capturedFiles.add(path));
      
      // Mostrar feedback visual
    } catch (e) {
      _showCaptureError('Erro ao gravar vídeo: $e');
    } finally {
      // Always unlock orientation
      await cameraController?.unlockCaptureOrientation();
    }
  }

  Future<void> _saveMediaToInspection(String filePath, String type) async {
    try {
      await _serviceFactory.mediaService.captureAndProcessMediaSimple(
        inputPath: filePath,
        inspectionId: widget.inspectionId,
        type: type,
        topicId: widget.topicId,
        itemId: widget.itemId,
        detailId: widget.detailId,
        nonConformityId: widget.nonConformityId,
        source: widget.source ?? 'camera',
      );
    } catch (e) {
      debugPrint('Erro ao salvar mídia na vistoria: $e');
      rethrow;
    }
  }

  void _showCaptureError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isInitializing = false;

  void startCamera() async {
    if (_isDisposed || _isInitializing) {
      debugPrint('Camera: Initialization blocked - disposed: $_isDisposed, initializing: $_isInitializing');
      return;
    }

    // Check if camera is already initialized
    if (cameraController?.value.isInitialized == true) {
      debugPrint('Camera: Camera already initialized');
      return;
    }

    _isInitializing = true;

    try {
      debugPrint('Camera: Starting camera initialization...');

      // Check camera permission first
      final cameraPermission = await Permission.camera.status;
      debugPrint('Camera: Permission status: $cameraPermission');

      if (cameraPermission.isDenied) {
        debugPrint('Camera: Requesting camera permission...');
        final result = await Permission.camera.request();
        if (result.isDenied) {
          _showCaptureError('Permissão de câmera negada');
          return;
        }
      }

      if (cameraPermission.isPermanentlyDenied) {
        _showCaptureError('Permissão de câmera permanentemente negada. Vá para as configurações do app.');
        return;
      }

      final cameras = await availableCameras();
      debugPrint('Camera: Found ${cameras.length} cameras');
      
      if (cameras.isEmpty) {
        debugPrint('Camera: No cameras available');
        _showCaptureError('Nenhuma câmera disponível');
        return;
      }

      // Find back camera, fallback to any available camera
      CameraDescription selectedCamera;
      try {
        selectedCamera = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.back);
        debugPrint('Camera: Using back camera: ${selectedCamera.name}');
      } catch (e) {
        selectedCamera = cameras.first;
        debugPrint('Camera: Back camera not found, using: ${selectedCamera.name}');
      }

      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high, // Changed from ultraHigh to high for better performance
        enableAudio: true,
      );
      
      debugPrint('Camera: Initializing camera controller...');
      cameraValue = cameraController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Camera: Initialization timeout');
          throw Exception('Camera initialization timeout');
        },
      );
      
      await cameraValue;
      debugPrint('Camera: Camera initialized successfully');
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Camera: Error initializing camera: $e');
      if (mounted) {
        _showCaptureError('Erro ao inicializar câmera: $e');
      }

      // Try to dispose controller if it was created
      cameraController?.dispose();
      cameraController = null;
      cameraValue = null;

      if (mounted) {
        setState(() {});
      }
    } finally {
      _isInitializing = false;
    }
  }

  Timer? _rotationDebounceTimer;
  double _pendingRotation = 0.0;

  void startAccelerometerListener() {
    accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      double angle = math.atan2(event.x, event.y);
      double newRotation = 0.0;

      if (angle >= -math.pi/4 && angle < math.pi/4) {
        newRotation = 0.0;
      } else if (angle >= math.pi/4 && angle < 3*math.pi/4) {
        newRotation = -math.pi / 2;
      } else if (angle >= 3*math.pi/4 || angle < -3*math.pi/4) {
        newRotation = math.pi;
      } else {
        newRotation = math.pi / 2;
      }

      // Only update if the rotation actually changed
      if ((deviceRotation - newRotation).abs() > 0.1) {
        _pendingRotation = newRotation;

        // Cancel previous timer
        _rotationDebounceTimer?.cancel();

        // Set new timer with debounce to avoid rapid changes
        _rotationDebounceTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted && (deviceRotation - _pendingRotation).abs() > 0.1) {
            setState(() {
              deviceRotation = _pendingRotation;
            });
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startCamera();
    startAccelerometerListener();
  }

  void startRecordingTimer() {
    recordingDuration = 0;
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        recordingDuration++;
      });
    });
  }

  void stopRecordingTimer() {
    recordingTimer?.cancel();
    recordingTimer = null;
    recordingDuration = 0;
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    debugPrint('Camera: Disposing camera screen...');
    WidgetsBinding.instance.removeObserver(this);
    recordingTimer?.cancel();
    _rotationDebounceTimer?.cancel();
    accelerometerSubscription?.cancel();

    // Dispose camera controller safely
    final controller = cameraController;
    if (controller != null) {
      debugPrint('Camera: Disposing camera controller...');
      controller.dispose();
      cameraController = null;
      cameraValue = null;
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    final CameraController? controller = cameraController;

    if (state == AppLifecycleState.inactive) {
      debugPrint('Camera: App inactive, disposing controller');
      if (controller != null && controller.value.isInitialized) {
        controller.dispose();
        cameraController = null;
        cameraValue = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('Camera: App resumed, checking if camera needs restart');
      if (mounted && cameraController == null) {
        debugPrint('Camera: Restarting camera after resume');
        startCamera();
      }
    }
  }

  Widget buildLatestCapturedImage() {
    if (capturedFiles.isEmpty) return const SizedBox.shrink();
    
    const double imageSize = 70.0; // Same size as camera button
    
    return Stack(
      children: [
        Container(
          width: imageSize,
          height: imageSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35), // Circular like camera button
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: isVideoFile(capturedFiles.last)
                ? Container(
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 30,
                    ),
                  )
                : Image.file(
                    File(capturedFiles.last),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.image,
                          color: Colors.white,
                          size: 30,
                        ),
                      );
                    },
                  ),
          ),
        ),
        // Counter badge on top-right corner
        if (capturedFiles.length > 1)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                '${capturedFiles.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  double getIconRotation() {
    double finalRotation = deviceRotation;

    if (deviceRotation.abs() > math.pi / 4 && deviceRotation.abs() < 3 * math.pi / 4) {
      finalRotation = -deviceRotation;
    }

    return finalRotation;
  }

  Widget buildCameraButton() {
    if (isVideoMode && isRecording) {
      return Transform.rotate(
        angle: getIconRotation(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
    }

    return Transform.rotate(
      angle: getIconRotation(),
      child: Image.asset(
        "assets/images/logo_lince.png",
        height: 40,
        width: 40,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.camera, color: Colors.white, size: 40);
        },
      ),
    );
  }

  void _finishCapture() async {
    try {
      // Properly dispose camera resources before exiting
      debugPrint('Camera: Finishing capture, disposing camera resources');
      
      // Stop any ongoing recording
      recordingTimer?.cancel();
      
      // Dispose camera controller to release buffer resources
      await cameraController?.dispose();
      cameraController = null;
      cameraValue = null;
      
      // Call callback with captured files
      if (widget.onMediaCaptured != null) {
        widget.onMediaCaptured!(capturedFiles);
      }
      
      // Safe navigation after cleanup
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Camera: Error during finish capture: $e');
      // Still try to navigate even if cleanup fails
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _closeCamera() async {
    try {
      // Properly dispose camera resources before closing
      debugPrint('Camera: Closing camera, disposing camera resources');
      
      // Stop any ongoing recording
      recordingTimer?.cancel();
      
      // Dispose camera controller to release buffer resources
      await cameraController?.dispose();
      cameraController = null;
      cameraValue = null;
      
      // Safe navigation after cleanup
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Camera: Error during close camera: $e');
      // Still try to navigate even if cleanup fails
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;

    // Calculate rotation for the preview based on device orientation
    // On iOS, the camera preview needs to be rotated to match the device orientation
    int quarterTurns = 0;
    if (deviceRotation.abs() > 0.1) {
      // Rotate the preview to match the UI orientation
      // The UI elements rotate by -deviceRotation, so the preview should too
      quarterTurns = -(deviceRotation / (math.pi / 2)).round();
    }

    // Calculate 4:3 frame dimensions
    double frameWidth, frameHeight;
    if (isPortrait) {
      // Portrait: width is screen width, height is width * 4/3
      frameWidth = size.width;
      frameHeight = frameWidth * 4 / 3;
    } else {
      // Landscape: height is screen height, width is height * 4/3
      frameHeight = size.height;
      frameWidth = frameHeight * 4 / 3;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Blurred background camera preview
          FutureBuilder(
            future: cameraValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Camera: FutureBuilder error: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Erro na câmera',
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque para tentar novamente',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            cameraValue = null;
                            cameraController = null;
                          });
                          startCamera();
                        },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                );
              }

              if (cameraValue != null &&
                  snapshot.connectionState == ConnectionState.done &&
                  cameraController?.value.isInitialized == true) {
                return Stack(
                  children: [
                    // Blurred background
                    SizedBox(
                      width: size.width,
                      height: size.height,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 100,
                          child: RotatedBox(
                            key: ValueKey('blur_$quarterTurns'),
                            quarterTurns: quarterTurns,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: CameraPreview(cameraController!),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Dark overlay on blurred area
                    Container(
                      width: size.width,
                      height: size.height,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    // Centered 4:3 frame with sharp preview
                    Center(
                      child: ClipRect(
                        child: SizedBox(
                          width: frameWidth,
                          height: frameHeight,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: 100,
                              child: RotatedBox(
                                key: ValueKey('preview_$quarterTurns'),
                                quarterTurns: quarterTurns,
                                child: CameraPreview(cameraController!),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Inicializando câmera...',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          
          // Top Controls
          SafeArea(
            child: Align(
              alignment: isPortrait ? Alignment.topRight : Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: 10, right: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Close Button
                    GestureDetector(
                      onTap: _closeCamera,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(100, 0, 0, 0),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Transform.rotate(
                          angle: getIconRotation(),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Flash Button
                    GestureDetector(
                      onTap: toggleFlash,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(100, 0, 0, 0),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Transform.rotate(
                          angle: getIconRotation(),
                          child: Icon(
                            isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Recording Timer
          if (isRecording)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.rotate(
                  angle: getIconRotation(),
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDuration(recordingDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          
          // Bottom Controls Row: Images | Camera | OK Button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Latest Captured Image with counter
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: capturedFiles.isNotEmpty
                        ? buildLatestCapturedImage()
                        : const SizedBox.shrink(),
                    ),

                    // Center: Camera Button
                    GestureDetector(
                      onTap: () async {
                        setState(() {
                          _isButtonTapped = true;
                        });
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            setState(() {
                              _isButtonTapped = false;
                            });
                          }
                        });

                        if (isVideoMode) {
                          isRecording ? await stopVideoRecording() : await startVideoRecording();
                        } else {
                          await takePhoto();
                        }
                      },
                      child: AnimatedScale(
                        scale: _isButtonTapped ? 0.9 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: buildCameraButton(),
                          ),
                        ),
                      ),
                    ),

                    // Right: OK Button
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: capturedFiles.isNotEmpty
                        ? FloatingActionButton(
                            backgroundColor: Colors.green,
                            onPressed: _finishCapture,
                            child: Transform.rotate(
                              angle: getIconRotation(),
                              child: const Icon(Icons.check, color: Colors.white, size: 24),
                            ),
                          )
                        : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Mode Toggle Button - positioned on the right side
          Positioned(
            bottom: 30,
            right: 30,
            child: SafeArea(
              child: GestureDetector(
                onTap: toggleMode,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(100, 0, 0, 0),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Transform.rotate(
                    angle: getIconRotation(),
                    child: Icon(
                      isVideoMode ? Icons.photo_camera : Icons.videocam,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}