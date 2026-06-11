import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/tts_api_service.dart';
import '../services/tflite_detection_service.dart';
import '../services/object_mapping_service.dart';
import '../services/guidance_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late CameraController _cameraController;
  late stt.SpeechToText _speechToText;
  late TTSApiService _ttsApi;
  late TFLiteDetectionService _detectionService;

  bool _isCameraInitialized = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _continuousListening = true;
  String? _targetObject;
  String _lastGuidance = 'Ứng dụng đang lắng nghe...';
  List<TFLiteDetectionResult> _lastDetections = [];
  DateTime _lastSpeechTime = DateTime.now();
  static const int _speechCooldownMs = 2000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      print('=== Starting Service Initialization ===');
      
      await _requestPermissions();
      print('✅ Permissions granted');
      
      await _initializeCamera();
      print('✅ Camera initialized');
      
      _speechToText = stt.SpeechToText();
      await _speechToText.initialize(
        onError: (error) {
          print('STT Error: $error');
          _speak('Lỗi nhận diện giọng nói: $error');
        },
        onStatus: (status) => print('STT Status: $status'),
        debugLogging: true,
      );
      print('✅ Speech-to-Text initialized');

      _ttsApi = TTSApiService();
      final healthOk = await _ttsApi.healthCheck();
      if (healthOk) {
        print('✅ TTS API backend connected');
      } else {
        print('⚠️ TTS API backend connection failed - will retry on speak');
      }
      print('✅ TTS API Service initialized');

      _detectionService = TFLiteDetectionService();
      await _detectionService.initialize();
      print('✅ Detection service initialized');

      print('=== All Services Initialized Successfully ===');
      
      if (mounted) {
        _speak('Ứng dụng Hỗ trợ di chuyển đã sẵn sàng. Đang bắt đầu lắng nghe giọng nói.');
        setState(() {});
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _startContinuousListening();
        });
      }
    } catch (e) {
      print('❌ Init error: $e');
      print('Stack trace: $e');
      if (mounted) {
        _speak('Lỗi khởi tạo');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    final permissions = [Permission.camera, Permission.microphone];
    final statuses = await permissions.request();

    for (final permission in permissions) {
      if (statuses[permission]?.isDenied ?? true) {
        throw Exception('$permission denied');
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras available');

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController.initialize();
      _startRealtimeDetection();
      _isCameraInitialized = true;
    } catch (e) {
      print('Camera init error: $e');
      rethrow;
    }
  }

  void _startRealtimeDetection() {
    _cameraController.startImageStream((image) async {
      if (_isProcessing || _targetObject == null) return;
      _isProcessing = true;

      try {
        final imageBytes = _convertCameraImageToBytes(image);
        final detections = await _detectionService.detect(imageBytes);

        if (mounted) {
          setState(() => _lastDetections = detections);

          if (_targetObject != null) {
            TFLiteDetectionResult? found;
            try {
              found = detections.firstWhere(
                (d) => d.label == _targetObject,
              );
            } catch (e) {
              found = null;
            }

            if (found != null) {
              await _handleObjectFound(found);
            } else {
              if (_shouldSpeak()) {
                await _speak(
                  'Chưa thấy ${ObjectMappingService.getVietnameseName(_targetObject!)}, vui lòng xoay camera',
                );
              }
            }
          }
        }
      } catch (e) {
        print('Detection error: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  Uint8List _convertCameraImageToBytes(CameraImage image) {
    // Simplified - trong production cần proper conversion
    return Uint8List(0);
  }

  Future<void> _handleObjectFound(TFLiteDetectionResult detection) async {
    final screenSize = MediaQuery.of(context).size;
    final zone = GuidanceService.analyzeHorizontalPosition(
      detection.centerX,
      screenSize.width,
    );
    final distance = GuidanceService.estimateDistance(
      detection.width,
      detection.height,
      screenSize.width,
      screenSize.height,
    );

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    final guidance = GuidanceService.createMovementGuidance(objectName, zone, distance);

    if (mounted) {
      setState(() => _lastGuidance = guidance);
    }

    if (_shouldSpeak()) {
      await _speak(guidance);
    }
  }

  bool _shouldSpeak() {
    final now = DateTime.now();
    return now.difference(_lastSpeechTime).inMilliseconds > _speechCooldownMs;
  }

  Future<void> _speak(String text) async {
    _lastSpeechTime = DateTime.now();
    print('🔊 Speaking: "$text"');
    try {
      await _ttsApi.speak(text, lang: 'vi');
      print('✅ TTS API speak called');
    } catch (e) {
      print('❌ TTS API error: $e');
    }
  }

  Future<void> _startContinuousListening() async {
    if (_isListening || !_continuousListening) return;
    
    print('🎤 Starting continuous listening...');
    
    if (!_speechToText.isAvailable) {
      print('❌ Speech-to-Text not available');
      Future.delayed(const Duration(seconds: 5), _startContinuousListening);
      return;
    }

    _isListening = true;
    if (mounted) setState(() {});

    print('🔴 Continuous listening started');
    try {
      await _speechToText.listen(
        onResult: (result) {
          final command = result.recognizedWords.trim();
          if (command.isEmpty) return;
          
          print('📝 Heard: "$command" (final: ${result.finalResult})');
          
          if (result.finalResult && command.isNotEmpty) {
            print('✅ Final result: $command');
            _processVoiceCommand(command);
            Future.delayed(const Duration(milliseconds: 500), _startContinuousListening);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: false,
        localeId: 'vi_VN',
      );
    } catch (e) {
      print('❌ Listen error: $e');
      _isListening = false;
      if (mounted) setState(() {});
      Future.delayed(const Duration(seconds: 3), _startContinuousListening);
    }
  }

  void _startListening() {
    print('🎤 Toggle listening (manual)');
    if (_isListening) {
      _stopListening();
    } else {
      _startContinuousListening();
    }
  }

  void _stopListening() {
    print('⏹️ Stopping listening');
    _isListening = false;
    _speechToText.stop();
    if (mounted) {
      setState(() {});
    }
    if (_continuousListening) {
      Future.delayed(const Duration(milliseconds: 500), _startContinuousListening);
    }
  }

  void _stopListeningQuiet() {
    print('⏹️ Stopping listening (quiet)');
    _speechToText.stop();
    _isListening = false;
  }

  void _processVoiceCommand(String command) {
    print('🎤 Processing voice command: "$command"');

    if (command.toLowerCase().contains('dừng') ||
        command.toLowerCase().contains('thoát')) {
      print('📍 Stop command detected');
      _stop();
      return;
    }

    final label = ObjectMappingService.parseVoiceCommand(command);
    print('Parsed label: $label');
    
    if (label != null) {
      final name = ObjectMappingService.getVietnameseName(label);
      print('✅ Object found: $name');
      _speak('Đang tìm $name');
      setState(() => _targetObject = label);
    } else {
      print('❌ Command not recognized');
      _speak('Lệnh không hiểu. Vui lòng nói lại.');
    }
  }

  void _stop() {
    _speak('Đã dừng ứng dụng');
    Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraInitialized) return;
    if (state == AppLifecycleState.paused) {
      _cameraController.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _startRealtimeDetection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    _stopListeningQuiet();
    _speechToText.cancel();
    _ttsApi.dispose();
    _detectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return HeroMode(
      enabled: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            CameraPreview(_cameraController),
            if (_lastDetections.isNotEmpty)
              CustomPaint(
                painter: DetectionPainter(_lastDetections, _targetObject),
                size: Size.infinite,
              ),
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lastGuidance,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.8),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _targetObject != null
                          ? 'Đang tìm: ${ObjectMappingService.getVietnameseName(_targetObject!)}'
                          : 'Chưa chọn object',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton(
                          backgroundColor: _isListening ? Colors.green : Colors.blue,
                          tooltip: _continuousListening ? 'Lắng nghe liên tục' : 'Tắt lắng nghe',
                          onPressed: () {
                            setState(() => _continuousListening = !_continuousListening);
                            if (_continuousListening) {
                              _startContinuousListening();
                            } else {
                              _stopListening();
                            }
                          },
                          child: Icon(
                            _continuousListening 
                              ? (_isListening ? Icons.mic : Icons.mic_none)
                              : Icons.mic_off,
                          ),
                        ),
                        FloatingActionButton(
                          backgroundColor: Colors.grey,
                          onPressed: _stop,
                          child: const Icon(Icons.stop),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<TFLiteDetectionResult> detections;
  final String? targetObject;

  DetectionPainter(this.detections, this.targetObject);

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      final isTarget = targetObject == detection.label;
      final color = isTarget ? Colors.green : Colors.blue;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final rect = Rect.fromLTWH(
        detection.x,
        detection.y,
        detection.width,
        detection.height,
      );

      canvas.drawRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(detection.x, detection.y - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
