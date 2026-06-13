import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/tts_api_service.dart';
import '../services/tflite_detection_service.dart';
import '../services/object_mapping_service.dart';
import '../services/guidance_service.dart';
import '../services/confirmation_intent_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

enum _CameraTask { idle, listening, detecting, speaking }

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late CameraController _cameraController;
  late stt.SpeechToText _speechToText;
  late TTSApiService _ttsApi;
  late TFLiteDetectionService _detectionService;
  late ConfirmationIntentService _confirmationIntentService;

  bool _isCameraInitialized = false;
  bool _isSpeechInitialized = false;
  bool _isSpeechAvailable = false;
  bool _isTtsInitialized = false;
  bool _isDetectionInitialized = false;
  bool _isListening = false;
  bool _isHandlingSpeechResult = false;
  bool _isProcessingSpeechCommand = false;
  bool _isProcessing = false;
  bool _continuousListening = false;
  bool _isNavigationActive = false;
  bool _awaitingMovementConfirmation = false;
  bool _hasHandledCurrentSpeech = false;
  _CameraTask _activeTask = _CameraTask.idle;
  String? _targetObject;
  String _lastGuidance = 'Ứng dụng đang lắng nghe...';
  String _recognizedText = '';
  String _lastSpeechCandidate = '';
  String _apiStatus = 'Chưa chụp ảnh';
  String? _lastCapturedImagePath;
  String? _lastAnalyzedImagePath;
  Size? _lastImageSize;
  List<TFLiteDetectionResult> _lastDetections = [];
  int _navigationStepCount = 0;
  DateTime _lastSpeechTime = DateTime.now();
  DateTime? _lastSpeechErrorTime;
  DateTime? _lastListenStartTime;
  DateTime? _speechBlockedUntil;
  static const int _speechCooldownMs = 2000;
  static const int _maxNavigationSteps = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      print('=== Bắt đầu khởi tạo màn hình camera ===');

      await _requestPermissions();
      print('✅ Đã cấp quyền camera và micro');

      await _initializeCamera();
      print('✅ Đã khởi tạo camera');

      await _initializeSpeechRecognizer();
      if (_isSpeechAvailable) {
        print('✅ Đã khởi tạo Speech-to-Text');
      } else {
        print('⚠️ STT: thiết bị chưa có dịch vụ nhận diện giọng nói khả dụng');
      }

      _ttsApi = TTSApiService();
      _isTtsInitialized = true;
      final healthOk = await _ttsApi.healthCheck();
      if (healthOk) {
        print('✅ Đã kết nối backend TTS');
      } else {
        print('⚠️ Chưa kết nối được backend TTS, sẽ thử lại khi đọc');
      }
      print('✅ Đã khởi tạo TTS API Service');

      _detectionService = TFLiteDetectionService();
      _confirmationIntentService = ConfirmationIntentService();
      try {
        await _detectionService.initialize();
        _isDetectionInitialized = true;
        print('✅ Đã khởi tạo TFLite Detection Service');
      } catch (e) {
        _isDetectionInitialized = false;
        print('⚠️ Detect local chưa sẵn sàng: $e');
      }

      print('=== Khởi tạo màn hình camera thành công ===');

      if (mounted) {
        _speak(
          'Ứng dụng Hỗ trợ di chuyển đã sẵn sàng. Hãy bấm mic để bắt đầu nói.',
          restartListening: false,
        );
        setState(() {});
      }
    } catch (e) {
      print('❌ Lỗi khởi tạo màn hình camera: $e');
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
      _isCameraInitialized = true;
    } catch (e) {
      print('❌ Camera: lỗi khởi tạo: $e');
      rethrow;
    }
  }
  String _handleObjectFound(TFLiteDetectionResult detection) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final zone = GuidanceService.analyzeHorizontalPosition(
      detection.centerX,
      sourceSize.width,
    );
    final distance = GuidanceService.estimateDistance(
      detection.width,
      detection.height,
      sourceSize.width,
      sourceSize.height,
    );

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    final guidance = GuidanceService.createMovementGuidance(objectName, zone, distance);

    if (mounted) {
      setState(() => _lastGuidance = guidance);
    }

    return guidance;
  }

  String _createDetailedGuidance(TFLiteDetectionResult detection) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final zone = GuidanceService.analyzeHorizontalPosition(
      detection.centerX,
      sourceSize.width,
    );
    final distance = GuidanceService.estimateDistance(
      detection.width,
      detection.height,
      sourceSize.width,
      sourceSize.height,
    );
    final objectName = ObjectMappingService.getVietnameseName(detection.label);

    final positionText = switch (zone) {
      ScreenZone.left => '$objectName nằm ở bên trái khung hình',
      ScreenZone.center => '$objectName nằm gần chính giữa, phía trước bạn',
      ScreenZone.right => '$objectName nằm ở bên phải khung hình',
    };
    final distanceText = switch (distance) {
      DistanceLevel.near => 'vật đang khá gần',
      DistanceLevel.medium => 'vật ở khoảng cách trung bình',
      DistanceLevel.far => 'vật còn khá xa',
    };
    final movementText = switch (zone) {
      ScreenZone.left =>
        'Hãy xoay người và điện thoại chậm sang trái một góc nhỏ. Sau đó tiến từng bước ngắn, giữ tay phía trước để dò đường.',
      ScreenZone.center when distance == DistanceLevel.near =>
        'Hãy đi thật chậm thẳng về phía trước. Vật đã gần, nên giảm tốc, đưa tay ra trước để tránh va chạm.',
      ScreenZone.center =>
        'Hãy giữ hướng hiện tại và đi thẳng chậm. Mỗi lần chỉ bước một bước ngắn, sau đó dừng lại nghe hướng dẫn tiếp.',
      ScreenZone.right =>
        'Hãy xoay người và điện thoại chậm sang phải một góc nhỏ. Sau đó tiến từng bước ngắn, giữ tay phía trước để dò đường.',
    };

    return '$positionText. $distanceText. $movementText';
  }

  String _createStepGuidance(TFLiteDetectionResult detection) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final zone = GuidanceService.analyzeHorizontalPosition(
      detection.centerX,
      sourceSize.width,
    );
    final distance = GuidanceService.estimateDistance(
      detection.width,
      detection.height,
      sourceSize.width,
      sourceSize.height,
    );
    final objectName = ObjectMappingService.getVietnameseName(detection.label);

    final positionText = switch (zone) {
      ScreenZone.left => '$objectName đang lệch về bên trái',
      ScreenZone.center => '$objectName đang ở phía trước',
      ScreenZone.right => '$objectName đang lệch về bên phải',
    };

    final stepText = switch ((zone, distance)) {
      (ScreenZone.left, _) =>
        'Chặng này, chỉ xoay người và điện thoại sang trái khoảng mười lăm độ. Chưa cần bước tới.',
      (ScreenZone.right, _) =>
        'Chặng này, chỉ xoay người và điện thoại sang phải khoảng mười lăm độ. Chưa cần bước tới.',
      (ScreenZone.center, DistanceLevel.far) =>
        'Chặng này, đi thẳng ba bước nhỏ. Mỗi bước thật chậm, giữ tay phía trước để dò đường.',
      (ScreenZone.center, DistanceLevel.medium) =>
        'Chặng này, đi thẳng hai bước nhỏ. Sau hai bước thì dừng lại.',
      (ScreenZone.center, DistanceLevel.near) =>
        'Chặng này, đi thẳng một bước rất nhỏ. Vật đã gần, hãy giảm tốc và đưa tay ra trước.',
    };

    return '$positionText. $stepText Sau khi làm xong, hãy nói: đã xong.';
  }

  bool _isTargetCloseEnough(TFLiteDetectionResult detection) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final zone = GuidanceService.analyzeHorizontalPosition(
      detection.centerX,
      sourceSize.width,
    );
    final areaRatio = detection.area / (sourceSize.width * sourceSize.height);

    return zone == ScreenZone.center && areaRatio >= 0.30;
  }

  Future<TFLiteDetectionResult?> _captureAndAnalyzeImage() async {
    if (!_isCameraInitialized) {
      print('⚠️ Camera: chưa sẵn sàng để chụp ảnh');
      return null;
    }

    if (!_isDetectionInitialized) {
      const message = 'TFLite chưa sẵn sàng, hãy thêm assets/models/best.tflite';
      print('⚠️ Detect local: $message');
      if (mounted) {
        setState(() => _apiStatus = message);
      }
      return null;
    }

    if (_activeTask != _CameraTask.idle) {
      final message = 'Đang bận tác vụ khác, vui lòng chờ xong rồi chụp lại';
      print('⚠️ Detect local: $message');
      if (mounted) {
        setState(() => _apiStatus = message);
      }
      return null;
    }

    if (_isListening) {
      await _stopListeningQuiet();
    }

    _activeTask = _CameraTask.detecting;
    _isProcessing = true;
    if (mounted) {
      setState(() => _apiStatus = 'Đang chụp ảnh...');
    }

    try {
      print('📷 Camera: bắt đầu chụp ảnh');
      final image = await _cameraController.takePicture();
      print('✅ Camera: đã chụp ảnh tại ${image.path}');

      if (mounted) {
        setState(() {
          _lastCapturedImagePath = image.path;
          _lastAnalyzedImagePath = null;
          _lastImageSize = null;
          _lastDetections = [];
          _apiStatus = 'Đã chụp ảnh, đang detect local bằng TFLite...';
        });
      }

      final result = await _detectionService.detectImageFile(
        File(image.path),
      );

      if (!mounted) return null;

      setState(() {
        _lastAnalyzedImagePath = result.annotatedImagePath;
        _lastImageSize = Size(
          result.imageWidth.toDouble(),
          result.imageHeight.toDouble(),
        );
        _lastDetections = result.detections;
        _apiStatus = 'Detect local xong: ${result.count} vật thể';
      });

      if (_targetObject != null && result.detections.isNotEmpty) {
        TFLiteDetectionResult? found;
        for (final detection in result.detections) {
          if (detection.label == _targetObject) {
            found = detection;
            break;
          }
        }

        if (found != null) {
          _handleObjectFound(found);
          return found;
        } else {
          setState(() {
            _lastGuidance =
                'Đã detect ảnh nhưng chưa thấy ${ObjectMappingService.getVietnameseName(_targetObject!)}';
          });
        }
      }
      return null;
    } catch (e) {
      print('❌ Detect local: lỗi khi chụp hoặc phân tích ảnh: $e');
      if (mounted) {
        setState(() => _apiStatus = 'Lỗi khi phân tích ảnh: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi phân tích ảnh: $e')),
        );
      }
      return null;
    } finally {
      _isProcessing = false;
      if (_activeTask == _CameraTask.detecting) {
        _activeTask = _CameraTask.idle;
      }
    }
  }

  Future<void> _runAutomaticSearch() async {
    if (_targetObject == null) return;

    if (!_isDetectionInitialized) {
      await _speak(
        'Tôi đã hiểu đồ vật bạn muốn tìm, nhưng mô hình nhận diện chưa sẵn sàng. Hãy kiểm tra file best tflite trong ứng dụng.',
        restartListening: false,
      );
      return;
    }

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    _isNavigationActive = true;
    _awaitingMovementConfirmation = false;
    _navigationStepCount = 0;

    await _speak(
      'Tôi sẽ chụp ảnh để tìm $objectName. Vui lòng giữ điện thoại hướng về phía trước và đứng yên trong giây lát.',
      restartListening: false,
    );
    await _captureAndContinueNavigation();
  }

  Future<void> _captureAndContinueNavigation() async {
    if (!_isNavigationActive || _targetObject == null) return;

    if (_navigationStepCount >= _maxNavigationSteps) {
      final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
      _isNavigationActive = false;
      _awaitingMovementConfirmation = false;
      await _speak(
        'Tôi đã hướng dẫn nhiều chặng nhưng vẫn chưa đưa $objectName vào khung hình đủ gần. Vui lòng dừng lại, kiểm tra an toàn xung quanh, rồi bấm mic để thử lại từ đầu.',
        restartListening: false,
      );
      return;
    }

    final found = await _captureAndAnalyzeImage();
    if (!mounted || !_isNavigationActive || _targetObject == null) return;

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    if (found == null) {
      _navigationStepCount++;
      await _speak(
        'Tôi chưa phát hiện thấy $objectName. Vui lòng xoay người và điện thoại sang phải khoảng mười lăm độ thật chậm, rồi đứng yên trong năm giây. Tôi sẽ tự chụp ảnh mới.',
        restartListening: false,
      );
      await Future.delayed(const Duration(seconds: 5));
      await _captureAndContinueNavigation();
      return;
    }

    if (_isTargetCloseEnough(found)) {
      _isNavigationActive = false;
      _awaitingMovementConfirmation = false;
      if (mounted) {
        setState(() {
          _targetObject = null;
          _navigationStepCount = 0;
          _lastGuidance =
              '$objectName đã ở rất gần. Hãy đưa tay lại gần phía trước để tìm vật.';
          _recognizedText = 'Đã thoát trạng thái tìm vật';
        });
      }
      await _speak(
        'Tôi đã thấy $objectName ở rất gần. Hãy dừng lại, đưa tay lại gần phía trước để tìm vật. Tôi sẽ thoát trạng thái tìm vật. Nếu cần tìm vật khác, hãy bật mic để tôi hỗ trợ.',
        restartListening: false,
      );
      return;
    }

    final stepGuidance = _createStepGuidance(found);
    if (mounted) {
      setState(() => _lastGuidance = stepGuidance);
    }
    await _speakAndWaitForMovement(stepGuidance);
  }

  Future<void> _speakAndWaitForMovement(String guidance) async {
    _navigationStepCount++;
    _awaitingMovementConfirmation = true;
    await _speak(guidance, restartListening: false);
    if (mounted) {
      setState(() {
        _recognizedText =
            'Sau khi di chuyển xong, hãy tự bấm mic và nói: đã xong';
      });
    }
  }

  Future<bool> _isMovementConfirmation(String command) async {
    return _confirmationIntentService.isMovementCompleted(command);
  }

  Future<void> _handleMovementConfirmation(String command) async {
    if (!_awaitingMovementConfirmation) return;

    final isConfirmed = await _isMovementConfirmation(command);
    print('🤖 Xác nhận hoàn thành chặng: "$command" => $isConfirmed');
    if (!isConfirmed) {
      await _speak(
        'Tôi chưa nghe rõ xác nhận. Nếu bạn đã làm xong chặng vừa rồi, hãy tự bấm mic và nói: đã xong.',
        restartListening: false,
      );
      return;
    }

    _awaitingMovementConfirmation = false;
    await _speak(
      'Tôi đã nhận xác nhận. Vui lòng đứng yên, tôi sẽ chụp lại để kiểm tra vị trí mới.',
      restartListening: false,
    );
    await _captureAndContinueNavigation();
  }

  bool _shouldSpeak() {
    final now = DateTime.now();
    return now.difference(_lastSpeechTime).inMilliseconds > _speechCooldownMs;
  }

  Future<void> _speak(String text, {bool restartListening = true}) async {
    if (!_isTtsInitialized || _activeTask == _CameraTask.speaking) return;

    if (_activeTask == _CameraTask.listening) {
      await _stopListeningQuiet();
    }

    _activeTask = _CameraTask.speaking;
    _lastSpeechTime = DateTime.now();
    print('🔊 TTS: bắt đầu đọc "$text"');
    try {
      await _ttsApi.speak(text, lang: 'vi');
      print('✅ TTS: đã gửi yêu cầu đọc thành công');
    } catch (e) {
      print('❌ TTS: lỗi khi đọc: $e');
    } finally {
      if (_activeTask == _CameraTask.speaking) {
        _activeTask = _CameraTask.idle;
      }
      await Future.delayed(const Duration(milliseconds: 1200));
      if (restartListening) {
        _scheduleListeningRestart();
      }
    }
  }

  Future<void> _startContinuousListening() async {
    if (_isListening || _isProcessingSpeechCommand || _activeTask != _CameraTask.idle) {
      if (_isProcessingSpeechCommand) {
        print('⚠️ STT: đang xử lý câu nói trước, chưa mở mic mới');
      }
      return;
    }

    if (!_isSpeechInitialized) {
      print('🔄 STT: chưa có phiên mic, khởi tạo mới như lúc mở app');
      await _initializeSpeechRecognizer();
    }

    print('🎤 STT: bắt đầu thu âm, hãy nói vào micro');

    final now = DateTime.now();
    if (_speechBlockedUntil != null && now.isBefore(_speechBlockedUntil!)) {
      final seconds = _speechBlockedUntil!.difference(now).inSeconds + 1;
      final message = 'STT đang bị Google giới hạn, vui lòng chờ $seconds giây rồi thử lại';
      print('⚠️ STT: $message');
      if (mounted) {
        setState(() => _recognizedText = message);
      }
      return;
    }

    if (_lastListenStartTime != null &&
        now.difference(_lastListenStartTime!).inMilliseconds < 2500) {
      const message = 'Bấm mic hơi nhanh, vui lòng chờ 2 giây rồi thử lại';
      print('⚠️ STT: $message');
      if (mounted) {
        setState(() => _recognizedText = message);
      }
      return;
    }

    if (!_isSpeechAvailable || !_speechToText.isAvailable) {
      const message =
          'STT chưa khả dụng: hãy bật/cài Google Speech Recognition trên thiết bị';
      print('❌ STT: $message');
      if (mounted) {
        setState(() => _recognizedText = message);
      }
      return;
    }

    _isListening = true;
    _activeTask = _CameraTask.listening;
    _lastListenStartTime = now;
    _recognizedText = 'Đang nghe...';
    _lastSpeechCandidate = '';
    _hasHandledCurrentSpeech = false;
    if (mounted) {
      setState(() {});
    }

    print('🔴 STT: đang thu âm');
    try {
      if (!_isSpeechAvailable || !_speechToText.isAvailable) {
        print('❌ STT: phiên SpeechRecognizer mới không khả dụng');
        _isListening = false;
        _activeTask = _CameraTask.idle;
        if (mounted) setState(() {});
        return;
      }
      await _speechToText.listen(
        onResult: (result) async {
          if (!_isListening) {
            final lateCommand = result.recognizedWords.trim();
            if (lateCommand.isNotEmpty) {
              print('⚠️ STT: bỏ qua kết quả đến muộn sau khi đã dừng mic = "$lateCommand"');
            }
            return;
          }

          final command = result.recognizedWords.trim();
          if (command.isEmpty) return;

          print('📝 STT: nghe được "$command" (kết quả cuối: ${result.finalResult})');
          _lastSpeechCandidate = command;
          if (mounted) {
            setState(() => _recognizedText = command);
          }

          if (result.finalResult && command.isNotEmpty && !_isHandlingSpeechResult) {
            _isHandlingSpeechResult = true;
            _isProcessingSpeechCommand = true;
            print('✅ STT: kết quả cuối = $command');
            try {
              await _stopListeningQuiet();
              await _handleRecognizedCommand(command);
            } finally {
              _isHandlingSpeechResult = false;
              _isProcessingSpeechCommand = false;
            }
          }
        },
        onSoundLevelChange: (level) {
          print('🎚️ STT: âm lượng mic = ${level.toStringAsFixed(2)}');
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'vi_VN',
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      print('❌ STT: lỗi khi thu âm: $e');
      _isListening = false;
      if (_activeTask == _CameraTask.listening) {
        _activeTask = _CameraTask.idle;
      }
      if (mounted) setState(() {});
    }
  }

  void _handleSpeechStatus(String status) {
    print('ℹ️ STT: trạng thái = $status');
    if (status == 'done' || status == 'notListening' || status == 'doneNoResult') {
      _isListening = false;
      if (!_isProcessingSpeechCommand) {
        _isHandlingSpeechResult = false;
      }
      if (_activeTask == _CameraTask.listening) {
        _activeTask = _CameraTask.idle;
      }
      if (mounted) {
        setState(() {
          if (_recognizedText == 'Đang nghe...' && _lastSpeechCandidate.isEmpty) {
            _recognizedText = 'Chưa nghe được text, hãy bấm mic và nói lại';
          }
        });
      }
      if (_continuousListening && !_isHandlingSpeechResult && _targetObject == null) {
        _scheduleListeningRestart();
      }
    }
  }

  void _handleSpeechError(dynamic error) {
    final now = DateTime.now();
    final isDuplicateError = _lastSpeechErrorTime != null &&
        now.difference(_lastSpeechErrorTime!).inMilliseconds < 1000;
    _lastSpeechErrorTime = now;

    final rawError = error.toString();
    final isNoMatch = rawError.contains('error_no_match');
    final isTooManyRequests = rawError.contains('error_too_many_requests');
    final isServerDisconnected = rawError.contains('error_server_disconnected');
    final message = isNoMatch
        ? 'Chưa nhận được nội dung giọng nói, hãy bấm mic và nói lại rõ hơn'
        : isTooManyRequests
        ? 'STT đang bị gọi quá nhiều lần, chờ khoảng 30 giây rồi bấm mic lại'
        : isServerDisconnected
        ? 'STT bị ngắt kết nối dịch vụ nhận diện, chờ vài giây rồi bấm mic lại'
        : rawError.contains('error_client')
        ? 'STT lỗi: thiết bị chưa chọn/cài dịch vụ nhận diện giọng nói'
        : 'STT lỗi: $rawError';

    if (isTooManyRequests || isServerDisconnected) {
      _speechBlockedUntil = DateTime.now().add(
        Duration(seconds: isTooManyRequests ? 30 : 5),
      );
    }

    if (!isDuplicateError) {
      print('❌ STT: $message');
      if (!isNoMatch && !isServerDisconnected) {
        print(
          '💡 STT: trên máy thật, hãy kiểm tra Google app/Speech Services và secure setting voice_recognition_service',
        );
      }
    }

    _isListening = false;
    _isHandlingSpeechResult = false;
    if (_activeTask == _CameraTask.listening) {
      _activeTask = _CameraTask.idle;
    }

    if (mounted) {
      setState(() {
        _recognizedText = message;
      });
    }
  }

  Future<void> _initializeSpeechRecognizer() async {
    if (_isSpeechInitialized) return;

    _speechToText = stt.SpeechToText();
    _isSpeechAvailable = await _speechToText.initialize(
      onError: _handleSpeechError,
      onStatus: _handleSpeechStatus,
      debugLogging: true,
    );
    _isSpeechInitialized = true;
  }

  Future<void> _handleRecognizedCommand(String command) async {
    final normalizedCommand = command.trim();
    if (_isSystemRecognizedText(normalizedCommand) || _hasHandledCurrentSpeech) {
      print('⚠️ STT: bỏ qua command không hợp lệ: "$normalizedCommand"');
      return;
    }

    _hasHandledCurrentSpeech = true;
    if (_awaitingMovementConfirmation) {
      await _handleMovementConfirmation(normalizedCommand);
      return;
    }

    final canSearch = await _processVoiceCommand(normalizedCommand);
    if (canSearch) {
      await _runAutomaticSearch();
    }
  }

  void _scheduleListeningRestart({
    Duration delay = const Duration(milliseconds: 500),
  }) {
    if (!_continuousListening || !_isSpeechInitialized) return;

    Future.delayed(delay, () {
      if (!mounted ||
          !_continuousListening ||
          _isListening ||
          _isProcessingSpeechCommand ||
          _activeTask != _CameraTask.idle) {
        return;
      }

      _startContinuousListening();
    });
  }
  void _startListening() {
    print('🎤 STT: bấm nút mic');
    if (_isProcessingSpeechCommand) {
      print('⚠️ STT: câu nói trước đang được xử lý, vui lòng chờ app phản hồi xong');
      return;
    }

    if (_isListening) {
      _stopListening();
    } else {
      _startContinuousListening();
    }
  }

  Future<void> _stopListening() async {
    print('⏹️ STT: dừng thu âm');
    if (_lastSpeechCandidate.trim().isEmpty) {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    final candidate = _lastSpeechCandidate.trim();
    _isListening = false;
    _isHandlingSpeechResult = false;
    if (_isSpeechInitialized) {
      await _speechToText.stop();
    }
    if (_activeTask == _CameraTask.listening) {
      _activeTask = _CameraTask.idle;
    }
    if (mounted) {
      setState(() {});
    }

    if (candidate.isNotEmpty && !_hasHandledCurrentSpeech) {
      print('✅ STT: xử lý text khi người dùng tắt mic = "$candidate"');
      _isProcessingSpeechCommand = true;
      try {
        await _handleRecognizedCommand(candidate);
      } finally {
        _isProcessingSpeechCommand = false;
      }
    }
  }

  Future<void> _stopListeningQuiet() async {
    print('⏹️ STT: dừng thu âm nội bộ');
    if (_isSpeechInitialized) {
      await _speechToText.stop();
    }
    _isListening = false;
    _isHandlingSpeechResult = false;
    if (_activeTask == _CameraTask.listening) {
      _activeTask = _CameraTask.idle;
    }
  }

  Future<bool> _processVoiceCommand(String command) async {
    print('📨 STT: xử lý text được gửi: "$command"');

    if (command.toLowerCase().contains('dừng') ||
        command.toLowerCase().contains('thoát')) {
      print('📍 STT: phát hiện lệnh dừng/thoát');
      _isNavigationActive = false;
      _awaitingMovementConfirmation = false;
      _stop();
      return false;
    }

    final label = await _parseTargetObject(command);
    print('🎯 STT: label sau khi parse = $label');

    if (label != null) {
      final name = ObjectMappingService.getVietnameseName(label);
      print('✅ STT: đã chọn mục tiêu cần tìm = $name');
      setState(() => _targetObject = label);
      await _speak(
        'Tôi đã hiểu. Bạn đang muốn tìm $name.',
        restartListening: false,
      );
      return true;
    } else {
      print('❌ STT: không hiểu nội dung text');
      await _speak(
        'Tôi chưa hiểu bạn muốn tìm vật gì. Vui lòng bấm mic và nói lại, ví dụ: tìm cái ghế, tìm cái bàn, hoặc tìm tủ lạnh.',
        restartListening: false,
      );
      return false;
    }
  }

  Future<String?> _parseTargetObject(String command) async {
    final aiLabel = await _confirmationIntentService.classifyTargetObject(command);
    if (aiLabel != null) {
      return aiLabel;
    }

    print('⚠️ OpenRouter: fallback sang mapping từ khóa local');
    return ObjectMappingService.parseVoiceCommand(command);
  }

  bool _isSystemRecognizedText(String text) {
    final normalizedText = text.trim().toLowerCase();
    return normalizedText.isEmpty ||
        normalizedText == 'đang nghe...' ||
        normalizedText.startsWith('chưa nghe được text') ||
        normalizedText.startsWith('chưa nhận được nội dung giọng nói') ||
        normalizedText.startsWith('stt đang bị') ||
        normalizedText.startsWith('stt chưa khả dụng') ||
        normalizedText.startsWith('stt lỗi') ||
        normalizedText.startsWith('bấm mic hơi nhanh') ||
        normalizedText.startsWith('đang bận') ||
        normalizedText.startsWith('sau khi di chuyển xong');
  }

  // Tạm tắt nút gửi text để test riêng luồng mic 1 và mic 2.
  // Future<void> _sendRecognizedText() async {
  //   final text = _recognizedText.trim();
  //   print('📤 STT: bấm nút gửi text với nội dung: "$text"');
  //   if (_isSystemRecognizedText(text)) {
  //     print('⚠️ STT: bỏ qua text hệ thống, không gửi xử lý: "$text"');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Chưa có text giọng nói hợp lệ để gửi')),
  //     );
  //     return;
  //   }
  //
  //   if (_activeTask != _CameraTask.idle) {
  //     print('⚠️ STT: đang bận tác vụ khác, chưa gửi text được');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Đang bận, vui lòng thử lại sau')),
  //     );
  //     return;
  //   }
  //
  //   if (_awaitingMovementConfirmation) {
  //     await _handleMovementConfirmation(text);
  //   } else {
  //     final canSearch = await _processVoiceCommand(text);
  //     if (canSearch) {
  //       await _runAutomaticSearch();
  //     }
  //   }
  // }

  void _stop() {
    _speak('Đã dừng ứng dụng');
    Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraInitialized) return;
    if (state == AppLifecycleState.paused) {
      print('ℹ️ Camera: ứng dụng tạm dừng');
    } else if (state == AppLifecycleState.resumed) {
      print('ℹ️ Camera: ứng dụng hoạt động lại');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    if (_isSpeechInitialized) {
      _speechToText.cancel();
    }
    if (_isTtsInitialized) {
      _ttsApi.dispose();
    }
    if (_isDetectionInitialized) {
      _detectionService.dispose();
    }
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
            Positioned.fill(child: _buildCameraOrImagePreview()),
            if (_lastDetections.isNotEmpty)
              CustomPaint(
                painter: DetectionPainter(
                  _lastDetections,
                  _targetObject,
                  sourceSize: _lastImageSize,
                ),
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
              left: 12,
              right: 12,
              bottom: 100,
              child: _buildStatusPanel(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomTestBar(),
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _targetObject != null
                ? 'Đang tìm: ${ObjectMappingService.getVietnameseName(_targetObject!)}'
                : 'Chưa chọn object',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            _recognizedText.isEmpty ? 'Text STT: chưa có' : 'Text STT: $_recognizedText',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Detect local: $_apiStatus',
              if (_lastAnalyzedImagePath != null) 'Ảnh phân tích: $_lastAnalyzedImagePath',
            ].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraOrImagePreview() {
    if (_lastCapturedImagePath == null) {
      return CameraPreview(_cameraController);
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Image.file(
        File(_lastCapturedImagePath!),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildBottomTestBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 86,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Colors.white24),
          ),
        ),
        child: Row(
          children: [
            _buildBottomAction(
              icon: _isListening ? Icons.mic_off : Icons.mic,
              label: _isListening ? 'Tắt mic' : 'Bật mic',
              color: _isListening ? Colors.red.shade700 : Colors.green.shade700,
              onTap: _startListening,
            ),
            const SizedBox(width: 6),
            _buildBottomAction(
              icon: Icons.camera_alt,
              label: 'Chụp ảnh',
              color: Colors.orange.shade800,
              onTap: () {
                _captureAndAnalyzeImage();
              },
            ),
            const SizedBox(width: 6),
            _buildBottomAction(
              icon: Icons.stop_circle,
              label: 'Dừng',
              color: Colors.grey.shade700,
              onTap: _stop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<TFLiteDetectionResult> detections;
  final String? targetObject;
  final Size? sourceSize;

  DetectionPainter(
    this.detections,
    this.targetObject, {
    this.sourceSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fittedImageRect = _calculateFittedImageRect(size);

    for (final detection in detections) {
      final isTarget = targetObject == detection.label;
      final color = isTarget ? Colors.green : Colors.blue;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final rect = _scaleDetectionRect(detection, fittedImageRect);

      canvas.drawRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left, (rect.top - 20).clamp(0, size.height).toDouble()),
      );
    }
  }

  Rect _calculateFittedImageRect(Size canvasSize) {
    if (sourceSize == null || sourceSize!.width <= 0 || sourceSize!.height <= 0) {
      return Offset.zero & canvasSize;
    }

    final imageAspect = sourceSize!.width / sourceSize!.height;
    final canvasAspect = canvasSize.width / canvasSize.height;

    double drawWidth;
    double drawHeight;
    if (canvasAspect > imageAspect) {
      drawHeight = canvasSize.height;
      drawWidth = drawHeight * imageAspect;
    } else {
      drawWidth = canvasSize.width;
      drawHeight = drawWidth / imageAspect;
    }

    return Rect.fromLTWH(
      (canvasSize.width - drawWidth) / 2,
      (canvasSize.height - drawHeight) / 2,
      drawWidth,
      drawHeight,
    );
  }

  Rect _scaleDetectionRect(TFLiteDetectionResult detection, Rect fittedImageRect) {
    if (sourceSize == null || sourceSize!.width <= 0 || sourceSize!.height <= 0) {
      return Rect.fromLTWH(
        detection.x,
        detection.y,
        detection.width,
        detection.height,
      );
    }

    final scaleX = fittedImageRect.width / sourceSize!.width;
    final scaleY = fittedImageRect.height / sourceSize!.height;
    return Rect.fromLTWH(
      fittedImageRect.left + detection.x * scaleX,
      fittedImageRect.top + detection.y * scaleY,
      detection.width * scaleX,
      detection.height * scaleY,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
