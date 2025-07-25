import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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

  Future<void> takePhoto() async {
    if (cameraController?.value.isInitialized != true || cameraController!.value.isTakingPicture) return;

    try {
      final image = await cameraController!.takePicture();
      final imageBytes = await image.readAsBytes();
      
      // Decodificar a imagem
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Erro ao decodificar imagem');
      }
      
      // Aplicar rotação baseada na orientação do dispositivo
      img.Image rotatedImage = _rotateImageBasedOnDeviceOrientation(originalImage);
      
      // Salvar a imagem corrigida
      final path = await getMediaPath("jpg");
      final file = File(path);
      await file.writeAsBytes(img.encodeJpg(rotatedImage));
      
      // Salvar automaticamente na vistoria
      await _saveMediaToInspection(path, 'image');
      
      setState(() => capturedFiles.add(path));
    } catch (e) {
      _showCaptureError('Erro ao capturar foto: $e');
    }
  }

  Future<void> startVideoRecording() async {
    if (cameraController?.value.isInitialized != true || cameraController!.value.isRecordingVideo) return;

    try {
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
      _showCaptureSuccess('Vídeo gravado!');
    } catch (e) {
      _showCaptureError('Erro ao gravar vídeo: $e');
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

  void _showCaptureSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
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

  void startCamera() async {
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
      _showCaptureError('Erro ao inicializar câmera: $e');
      
      // Try to dispose controller if it was created
      cameraController?.dispose();
      cameraController = null;
      cameraValue = null;
      
      if (mounted) {
        setState(() {});
      }
    }
  }

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
      
      if ((deviceRotation - newRotation).abs() > 0.1) {
        setState(() {
          deviceRotation = newRotation;
        });
      }
    });
  }

  img.Image _rotateImageBasedOnDeviceOrientation(img.Image originalImage) {
    // Converter radianos para graus
    double rotationDegrees = deviceRotation * 180 / math.pi;
    
    debugPrint('Camera: Device rotation: ${rotationDegrees.toStringAsFixed(1)}°');
    
    // Invertendo a lógica: manter paisagem em paisagem e retrato em retrato
    int finalRotation = 0;
    String orientationName = '';
    
    if (rotationDegrees.abs() < 45) {
      // Retrato normal (0°) - não rotacionar (manter retrato)
      finalRotation = 0;
      orientationName = 'Retrato normal';
    } else if (rotationDegrees >= 45 && rotationDegrees < 135) {
      // Paisagem esquerda (-90°) - rotacionar 90° para manter paisagem
      finalRotation = 90;
      orientationName = 'Paisagem esquerda';
    } else if (rotationDegrees.abs() >= 135) {
      // Retrato invertido (180°) - rotacionar 180° para manter retrato invertido
      finalRotation = 180;
      orientationName = 'Retrato invertido';
    } else if (rotationDegrees <= -45 && rotationDegrees > -135) {
      // Paisagem direita (90°) - rotacionar 270° para manter paisagem
      finalRotation = 270;
      orientationName = 'Paisagem direita';
    }
    
    debugPrint('Camera: $orientationName -> Aplicando rotação de $finalRotation°');
    
    // Aplicar rotação se necessário
    if (finalRotation == 0) {
      return originalImage;
    } else {
      return img.copyRotate(originalImage, angle: finalRotation);
    }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recordingTimer?.cancel();
    accelerometerSubscription?.cancel();
    cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      debugPrint('Camera: App inactive, disposing controller');
      controller.dispose();
      cameraController = null;
      cameraValue = null;
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('Camera: App resumed, restarting camera');
      if (mounted) {
        setState(() {
          cameraController = null;
          cameraValue = null;
        });
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

  Widget buildCameraButton() {
    if (isVideoMode && isRecording) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    
    double finalRotation = deviceRotation;
    
    if (deviceRotation.abs() > math.pi / 4 && deviceRotation.abs() < 3 * math.pi / 4) {
      finalRotation = -deviceRotation;
    }
    
    return Transform.rotate(
      angle: finalRotation,
      child: Image.asset(
        "assets/images/logo_lince.png", 
        height: 40,
        width: 40,
        errorBuilder: (context, error, stackTrace) {
          return Transform.rotate(
            angle: finalRotation,
            child: const Icon(Icons.camera, color: Colors.white, size: 40),
          );
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
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
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 100,
                      child: CameraPreview(cameraController!),
                    ),
                  ),
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
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Flash Button
                    GestureDetector(
                      onTap: toggleFlash,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(100, 0, 0, 0),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Mode Toggle Button
                    GestureDetector(
                      onTap: toggleMode,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(100, 0, 0, 0),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          isVideoMode ? Icons.videocam : Icons.photo_camera,
                          color: Colors.white,
                          size: 30,
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
                        if (isVideoMode) {
                          isRecording ? await stopVideoRecording() : await startVideoRecording();
                        } else {
                          await takePhoto();
                        }
                      },
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
                    
                    // Right: OK Button
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: capturedFiles.isNotEmpty
                        ? FloatingActionButton(
                            backgroundColor: Colors.green,
                            onPressed: _finishCapture,
                            child: const Icon(Icons.check, color: Colors.white, size: 24),
                          )
                        : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}