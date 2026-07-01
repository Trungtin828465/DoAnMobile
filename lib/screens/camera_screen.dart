import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:webview_flutter/webview_flutter.dart';
import '../services/tts_api_service.dart';
import '../services/tflite_detection_service.dart';
import '../services/object_mapping_service.dart';
import '../services/guidance_service.dart';
import '../services/confirmation_intent_service.dart';
import '../services/vision_verification_service.dart';
import '../models/user_model.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.user,
    required this.initialRoomLayout,
  });

  final User user;
  final Map<String, dynamic> initialRoomLayout;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

enum _CameraTask { idle, listening, detecting, speaking }

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  static const EventChannel _hardwareKeyChannel =
      EventChannel('com.example.doan/hardware_keys');
  static const MethodChannel _audioFeedbackChannel =
      MethodChannel('com.example.doan/audio_feedback');

  late CameraController _cameraController;
  late stt.SpeechToText _speechToText;
  late TTSApiService _ttsApi;
  late TFLiteDetectionService _detectionService;
  late ConfirmationIntentService _confirmationIntentService;
  late VisionVerificationService _visionVerificationService;

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
  bool _awaitingReadyForMovement = false;
  bool _hasAskedReadyForMovement = false;
  bool _movementGuidanceStarted = false;
  bool _hasAddedFinalTableApproachStep = false;
  bool _hasAddedFinalLaptopApproachStep = false;
  bool _hasHandledCurrentSpeech = false;
  _CameraTask _activeTask = _CameraTask.idle;
  String? _targetObject;
  String? _mapReferenceObject;
  String _lastGuidance = 'Ứng dụng đang lắng nghe...';
  String _recognizedText = '';
  String _lastSpeechCandidate = '';
  String _apiStatus = 'Chưa chụp ảnh';
  String _mapPositionStatus = 'Chưa xác định vị trí. Hãy bấm mic để bắt đầu tìm vật.';
  String? _lastCapturedImagePath;
  String? _lastAnalyzedImagePath;
  Size? _lastImageSize;
  List<TFLiteDetectionResult> _lastDetections = [];
  TFLiteDetectionResult? _pendingTargetDetection;
  TFLiteDetectionResult? _lastConfirmedTargetDetection;
  TFLiteDetectionResult? _lastLowConfidenceTargetDetection;
  Map<String, dynamic>? _activeRoomLayout;
  String? _lastLowConfidenceImagePath;
  Offset? _estimatedUserPosition;
  double _estimatedUserHeadingDegrees = 0;
  WebViewController? _navigationSceneController;
  final GlobalKey<ScaffoldState> _cameraScaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _activityLogController = ScrollController();
  StreamSubscription<dynamic>? _hardwareKeySubscription;
  bool _isNavigationSceneReady = false;
  int _navigationStepCount = 0;
  int? _lastSuggestedStepCount;
  int _scanRotationDegrees = 0;
  int _lastScanRotationDegrees = 0;
  DateTime _lastSpeechTime = DateTime.now();
  DateTime? _lastHardwareMicButtonTime;
  DateTime? _lastSpeechErrorTime;
  DateTime? _lastListenStartTime;
  DateTime? _speechBlockedUntil;
  final List<String> _activityLogs = [];
  static const int _speechCooldownMs = 2000;
  static const int _maxNavigationSteps = 8;
  static const double _visualConfirmThreshold = 0.5;
  static const double _lowConfidenceTargetThreshold = 0.1;
  static const double _layoutReferenceThreshold = 0.1;
  static const double _strongVisualThreshold = 0.5;
  static const Map<String, String> _navigationModelAssets = {
    'bed': 'assets/model/bed.glb',
    'sofa': 'assets/model/sofa.glb',
    'chair': 'assets/model/chair.glb',
    'table': 'assets/model/table.glb',
    'wardrobe': 'assets/model/wardrobe.glb',
    'refrigerator': 'assets/model/refrigerator.glb',
    'tv': 'assets/model/tv.glb',
    'door': 'assets/model/door.glb',
    'window': 'assets/model/window.glb',
    'fan': 'assets/model/fan.glb',
    'laptop': 'assets/model/laptop.glb',
    'washing_machine': 'assets/model/washing_machine.glb',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeHardwareButtonListener();
    _initializeServices();
  }

  void _initializeHardwareButtonListener() {
    _hardwareKeySubscription = _hardwareKeyChannel.receiveBroadcastStream().listen(
      (event) {
        final key = event?.toString() ?? '';
        if (key != 'volume_up' && key != 'volume_down' && key != 'camera') {
          return;
        }

        print('Nút Bluetooth: nhận phím $key, chuyển thành nút mic');
        _handleHardwareMicButton();
      },
      onError: (error) {
        print('Nút Bluetooth: lỗi lắng nghe phím cứng: $error');
      },
    );
  }

  void _handleHardwareMicButton() {
    final now = DateTime.now();
    if (_lastHardwareMicButtonTime != null &&
        now.difference(_lastHardwareMicButtonTime!).inMilliseconds < 700) {
      print('Nút Bluetooth: bỏ qua do bấm quá nhanh');
      return;
    }

    _lastHardwareMicButtonTime = now;
    _startListening();
  }

  void _addActivityLog(String actor, String message) {
    final cleanedMessage = message.trim();
    if (cleanedMessage.isEmpty) return;

    final line = '$actor: $cleanedMessage';
    if (!mounted) {
      _activityLogs.add(line);
      return;
    }

    setState(() {
      _activityLogs.add(line);
      if (_activityLogs.length > 120) {
        _activityLogs.removeRange(0, _activityLogs.length - 120);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_activityLogController.hasClients) return;
      _activityLogController.animateTo(
        _activityLogController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _createDetectionLog(List<TFLiteDetectionResult> detections) {
    final visibleDetections =
        detections.where(_shouldUseDetectionForNavigation).toList();

    if (visibleDetections.isEmpty) {
      return 'Không phát hiện vật nào trong ảnh.';
    }

    return visibleDetections
        .map((detection) {
          final name = ObjectMappingService.getVietnameseName(detection.label);
          final confidence = (detection.confidence * 100).toStringAsFixed(0);
          return '$name $confidence%';
        })
        .join(', ');
  }

  bool _shouldUseDetectionForNavigation(TFLiteDetectionResult detection) {
    return detection.label != 'door';
  }

  Future<void> _initializeServices() async {
    try {
      print('=== Bắt đầu khởi tạo màn hình camera ===');

      await _requestPermissions();
      print('Đã cấp quyền camera và micro');

      await _initializeCamera();
      print('Đã khởi tạo camera');

      await _initializeSpeechRecognizer();
      if (_isSpeechAvailable) {
        print('Đã khởi tạo Speech-to-Text');
      } else {
        print('STT: thiết bị chưa có dịch vụ nhận diện giọng nói khả dụng');
      }

      _ttsApi = TTSApiService();
      _isTtsInitialized = true;
      final healthOk = await _ttsApi.healthCheck();
      if (healthOk) {
        print('Đã kết nối backend TTS');
      } else {
        print('Chưa kết nối được backend TTS, sẽ thử lại khi đọc');
      }
      print('Đã khởi tạo TTS API Service');

      await _loadActiveRoomLayout();
      await _initializeNavigationScene();

      _detectionService = TFLiteDetectionService();
      _confirmationIntentService = ConfirmationIntentService();
      _visionVerificationService = VisionVerificationService();
      try {
        await _detectionService.initialize();
        _isDetectionInitialized = true;
        print('Đã khởi tạo TFLite Detection Service');
      } catch (e) {
        _isDetectionInitialized = false;
        print('Detect local chưa sẵn sàng: $e');
      }

      print('=== Khởi tạo màn hình camera thành công ===');

      if (mounted) {
        _addActivityLog(
          'Hệ thống',
          'Ứng dụng hỗ trợ người di chuyển đang hoạt động. Hãy bấm mic để bắt đầu nói.',
        );
        _speak(
          'Ứng dụng Hỗ trợ di chuyển đã sẵn sàng. Hãy bấm mic để bắt đầu nói.',
          restartListening: false,
        );
        setState(() {});
      }
    } catch (e) {
      print('Camera: lỗi khởi tạo: $e');
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
      print('Camera: lỗi khởi tạo: $e');
      rethrow;
    }
  }

  Future<void> _loadActiveRoomLayout() async {
    try {
      if (widget.initialRoomLayout.isEmpty) {
        print('Layout: chưa chọn layout để hỗ trợ camera');
        return;
      }

      _activeRoomLayout = Map<String, dynamic>.from(widget.initialRoomLayout);
      final roomName = (_activeRoomLayout?['RoomName'] ?? 'phòng').toString();
      final objectCount = _layoutObjects.length;
      print('Layout: đã chọn "$roomName" với $objectCount vật để hỗ trợ camera');

      if (mounted) {
        setState(() {
          _apiStatus = 'Đã chọn layout: $roomName ($objectCount vật)';
        });
      }
    } catch (error) {
      print('Layout: lỗi đọc layout đã chọn: $error');
    }
  }

  Future<void> _initializeNavigationScene() async {
    if (_activeRoomLayout == null) return;

    try {
      print('Layout 3D: đang dựng scene demo điều hướng');
      final modelSources = await _loadNavigationModelSources();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFD7D7D7))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _isNavigationSceneReady = true;
              _syncTargetMarkerToScene();
              _syncUserMarkerToScene();
              if (mounted) setState(() {});
              print('Layout 3D: đã render scene điều hướng');
            },
          ),
        );

      _navigationSceneController = controller;
      if (mounted) setState(() {});

      await controller.loadHtmlString(
        _buildNavigationSceneHtml(
          widthM: _roomWidthMeters,
          depthM: _roomDepthMeters,
          heightM: _readRoomDouble('Height', 2.7),
          modelSources: modelSources,
          savedObjects: _layoutObjects,
        ),
      );
    } catch (error) {
      print('Layout 3D: lỗi dựng scene điều hướng: $error');
    }
  }

  Future<Map<String, String>> _loadNavigationModelSources() async {
    final sources = <String, String>{};
    for (final entry in _navigationModelAssets.entries) {
      try {
        final data = await rootBundle.load(entry.value);
        sources[entry.key] =
            'data:model/gltf-binary;base64,${base64Encode(data.buffer.asUint8List())}';
      } catch (error) {
        print('Layout 3D: không load được model ${entry.key}: $error');
      }
    }
    return sources;
  }

  void _syncUserMarkerToScene() {
    final position = _estimatedUserPosition;
    final controller = _navigationSceneController;
    if (!_isNavigationSceneReady || position == null || controller == null) {
      return;
    }

    final label = jsonEncode(_mapPositionStatus);
    controller.runJavaScript(
      'window.updateUserMarker(${position.dx}, ${position.dy}, '
      '$_estimatedUserHeadingDegrees, $label);',
    );
  }

  void _syncTargetMarkerToScene() {
    final controller = _navigationSceneController;
    if (!_isNavigationSceneReady || controller == null) return;

    controller.runJavaScript(
      'window.setTargetObject(${jsonEncode(_targetObject)});',
    );
  }

  String _buildNavigationSceneHtml({
    required double widthM,
    required double depthM,
    required double heightM,
    required Map<String, String> modelSources,
    required List<Map<String, dynamic>> savedObjects,
  }) {
    final sourceJson = jsonEncode(modelSources);
    final savedObjectsJson = jsonEncode(savedObjects);
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #d7d7d7; }
    canvas { touch-action: none; }
    .badge {
      position: fixed; left: 12px; top: 12px; z-index: 2;
      background: rgba(255,255,255,.88); color: #0f172a;
      padding: 8px 10px; border-radius: 14px;
      font-family: Arial, sans-serif; font-size: 12px; font-weight: 700;
      box-shadow: 0 8px 22px rgba(0,0,0,.12);
    }
  </style>
</head>
<body>
<div class="badge" id="status">Layout 3D điều hướng</div>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script>
const ROOM = { width: $widthM, depth: $depthM, height: $heightM };
const MODEL_SOURCES = $sourceJson;
const SAVED_OBJECTS = $savedObjectsJson;
const OBJECT_SIZE = {
  bed: 1.55, sofa: 1.25, chair: .7, table: 1.0, wardrobe: 1.15,
  refrigerator: 1.2, tv: .9, door: 1.9, window: 1.1, fan: .8,
  laptop: .45, washing_machine: .85
};
const VERTICAL_TYPES = new Set(['window', 'tv', 'laptop']);

let scene, camera, renderer, orbitControls, loader;
let userMarker, userArrow, targetMarker;
let pendingTargetType = null;
const objects = [];

init();
animate();

function init() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0xd7d7d7);

  camera = new THREE.PerspectiveCamera(42, window.innerWidth / window.innerHeight, 0.01, 100);
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(window.devicePixelRatio || 1);
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.outputEncoding = THREE.sRGBEncoding;
  document.body.appendChild(renderer.domElement);

  orbitControls = new THREE.OrbitControls(camera, renderer.domElement);
  orbitControls.enableDamping = true;
  orbitControls.dampingFactor = .08;
  orbitControls.minDistance = Math.max(ROOM.width, ROOM.depth) * .55;
  orbitControls.maxDistance = Math.max(ROOM.width, ROOM.depth) * 3.2;
  orbitControls.maxPolarAngle = Math.PI * .48;

  loader = new THREE.GLTFLoader();
  addLights();
  addRoom();
  createMarkers();
  resetCamera();
  loadSavedObjects();
  window.addEventListener('resize', onResize);
}

function addLights() {
  scene.add(new THREE.HemisphereLight(0xffffff, 0xb8b8b8, 1.25));
  const light = new THREE.DirectionalLight(0xffffff, 1.05);
  light.position.set(3, 6, 4);
  scene.add(light);
}

function addRoom() {
  const floorTexture = createWoodTexture();
  floorTexture.wrapS = THREE.RepeatWrapping;
  floorTexture.wrapT = THREE.RepeatWrapping;
  floorTexture.repeat.set(Math.max(2, ROOM.width), Math.max(2, ROOM.depth));

  const floor = new THREE.Mesh(
    new THREE.PlaneGeometry(ROOM.width, ROOM.depth),
    new THREE.MeshStandardMaterial({ map: floorTexture, roughness: .86 })
  );
  floor.rotation.x = -Math.PI / 2;
  floor.name = 'floor';
  scene.add(floor);

  const wallMaterial = new THREE.MeshStandardMaterial({
    color: 0xdde7ea, roughness: .9, transparent: true,
    opacity: .24, side: THREE.DoubleSide
  });

  const back = new THREE.Mesh(new THREE.PlaneGeometry(ROOM.width, ROOM.height), wallMaterial);
  back.position.set(0, ROOM.height / 2, -ROOM.depth / 2);
  scene.add(back);

  const left = new THREE.Mesh(new THREE.PlaneGeometry(ROOM.depth, ROOM.height), wallMaterial);
  left.position.set(-ROOM.width / 2, ROOM.height / 2, 0);
  left.rotation.y = Math.PI / 2;
  scene.add(left);

  const right = new THREE.Mesh(new THREE.PlaneGeometry(ROOM.depth, ROOM.height), wallMaterial);
  right.position.set(ROOM.width / 2, ROOM.height / 2, 0);
  right.rotation.y = -Math.PI / 2;
  scene.add(right);

  const edges = new THREE.LineSegments(
    new THREE.EdgesGeometry(new THREE.BoxGeometry(ROOM.width, ROOM.height, ROOM.depth)),
    new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: .86 })
  );
  edges.position.y = ROOM.height / 2;
  scene.add(edges);
}

function createWoodTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#d6a85d';
  ctx.fillRect(0, 0, 512, 512);
  ctx.strokeStyle = 'rgba(104,67,28,.34)';
  ctx.lineWidth = 2;
  for (let y = 0; y < 512; y += 42) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(512, y + 12);
    ctx.stroke();
  }
  for (let x = 0; x < 512; x += 70) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + 18, 512);
    ctx.stroke();
  }
  ctx.strokeStyle = 'rgba(255,231,178,.30)';
  for (let y = 15; y < 512; y += 38) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.bezierCurveTo(150, y + 22, 330, y - 22, 512, y + 8);
    ctx.stroke();
  }
  return new THREE.CanvasTexture(canvas);
}

function loadSavedObjects() {
  if (!Array.isArray(SAVED_OBJECTS)) return;
  SAVED_OBJECTS.forEach(saved => {
    const type = saved.ClassName || saved.ObjectName;
    if (type) addModel(type, saved);
  });
}

function addModel(type, saved) {
  const source = MODEL_SOURCES[type];
  if (!source) return;

  loader.load(source, gltf => {
    const model = gltf.scene;
    model.userData.type = type;
    model.traverse(child => {
      if (child.isMesh) {
        child.castShadow = true;
        child.receiveShadow = true;
        if (child.material) child.material.side = THREE.DoubleSide;
      }
    });
    normalizeModel(model, OBJECT_SIZE[type] || 1);
    centerModelGeometry(model);

    const root = new THREE.Group();
    root.userData.type = type;
    root.add(model);
    const savedY = Number(saved.PosY || 0);
    const fallbackY = type === 'laptop' && savedY === 0 ? .72 : savedY;
    root.position.set(Number(saved.PosX || 0), fallbackY, Number(saved.PosZ || 0));
    root.rotation.set(Number(saved.RotationX || 0), Number(saved.RotationY || 0), Number(saved.RotationZ || 0));
    const savedScale = Number(saved.Scale || 1);
    root.scale.set(savedScale, savedScale, savedScale);
    keepObjectInsideRoom(root, type);
    objects.push(root);
    scene.add(root);
    if (pendingTargetType) setTargetObject(pendingTargetType);
  });
}

function normalizeModel(model, targetSize) {
  const box = new THREE.Box3().setFromObject(model);
  const size = new THREE.Vector3();
  box.getSize(size);
  const maxSide = Math.max(size.x, size.y, size.z) || 1;
  model.scale.multiplyScalar(targetSize / maxSide);
}

function centerModelGeometry(model) {
  const box = new THREE.Box3().setFromObject(model);
  const center = new THREE.Vector3();
  box.getCenter(center);
  model.position.x -= center.x;
  model.position.z -= center.z;
  model.position.y -= box.min.y;
}

function keepObjectInsideRoom(object, type) {
  const halfW = ROOM.width / 2;
  const halfD = ROOM.depth / 2;
  const box = new THREE.Box3().setFromObject(object);
  if (box.min.x < -halfW) object.position.x += -halfW - box.min.x;
  if (box.max.x > halfW) object.position.x -= box.max.x - halfW;
  if (box.min.z < -halfD) object.position.z += -halfD - box.min.z;
  if (box.max.z > halfD) object.position.z -= box.max.z - halfD;
  const refreshed = new THREE.Box3().setFromObject(object);
  if (VERTICAL_TYPES.has(type)) {
    if (refreshed.min.y < 0) object.position.y += -refreshed.min.y;
    const refreshedTop = new THREE.Box3().setFromObject(object);
    if (refreshedTop.max.y > ROOM.height) {
      object.position.y -= refreshedTop.max.y - ROOM.height;
    }
  } else {
    object.position.y -= refreshed.min.y;
  }
}

function createMarkers() {
  userMarker = new THREE.Group();
  const ring = new THREE.Mesh(
    new THREE.RingGeometry(.18, .28, 48),
    new THREE.MeshBasicMaterial({ color: 0x2563eb, side: THREE.DoubleSide, transparent: true, opacity: .92 })
  );
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = .035;
  userMarker.add(ring);

  const dot = new THREE.Mesh(
    new THREE.SphereGeometry(.13, 32, 16),
    new THREE.MeshStandardMaterial({ color: 0x1d4ed8, roughness: .35 })
  );
  dot.position.y = .18;
  userMarker.add(dot);

  userArrow = new THREE.ArrowHelper(
    new THREE.Vector3(0, 0, 1),
    new THREE.Vector3(0, .16, 0),
    .75,
    0x1d4ed8,
    .22,
    .12
  );
  userMarker.add(userArrow);
  userMarker.visible = false;
  scene.add(userMarker);

  targetMarker = new THREE.Mesh(
    new THREE.RingGeometry(.38, .48, 56),
    new THREE.MeshBasicMaterial({ color: 0x22c55e, side: THREE.DoubleSide, transparent: true, opacity: .95 })
  );
  targetMarker.rotation.x = -Math.PI / 2;
  targetMarker.position.y = .05;
  targetMarker.visible = false;
  scene.add(targetMarker);
}

function updateUserMarker(x, z, headingDegrees, label) {
  if (!userMarker) return;
  userMarker.position.set(Number(x || 0), 0, Number(z || 0));
  const radians = THREE.MathUtils.degToRad(Number(headingDegrees || 0));
  const direction = new THREE.Vector3(Math.sin(radians), 0, Math.cos(radians)).normalize();
  userArrow.setDirection(direction);
  userMarker.visible = true;
  const status = document.getElementById('status');
  if (status) status.textContent = label || 'Đã định vị người dùng';
}

function setTargetObject(type) {
  pendingTargetType = type;
  if (!targetMarker || !type) {
    if (targetMarker) targetMarker.visible = false;
    return;
  }
  const target = objects.find(object => object.userData.type === type);
  if (!target) {
    targetMarker.visible = false;
    return;
  }
  targetMarker.position.x = target.position.x;
  targetMarker.position.z = target.position.z;
  targetMarker.visible = true;
}

function resetCamera() {
  const maxSide = Math.max(ROOM.width, ROOM.depth);
  camera.position.set(ROOM.width * .05, maxSide * 1.55, ROOM.depth * .48);
  orbitControls.target.set(0, 0, 0);
  orbitControls.update();
}

function onResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}

function animate() {
  requestAnimationFrame(animate);
  orbitControls.update();
  renderer.render(scene, camera);
}

window.updateUserMarker = updateUserMarker;
window.setTargetObject = setTargetObject;
window.resetNavigationCamera = resetCamera;
</script>
</body>
</html>
''';
  }

  List<Map<String, dynamic>> get _layoutObjects {
    final objects = _activeRoomLayout?['Objects'];
    if (objects is! List) return [];
    return objects
        .whereType<Map>()
        .map((object) => Map<String, dynamic>.from(object))
        .toList();
  }

  Map<String, dynamic>? _findLayoutObject(String className) {
    for (final object in _layoutObjects) {
      if ((object['ClassName'] ?? '').toString() == className) {
        return object;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _findLayoutObjects(String className) {
    return _layoutObjects
        .where((object) => (object['ClassName'] ?? '').toString() == className)
        .toList();
  }

  bool _canVerifyLabelWithGemini(String label) {
    return _activeRoomLayout != null && _findLayoutObject(label) != null;
  }

  String _objectDisplayName(String label) {
    switch (label) {
      case 'bed':
        return 'Giường';
      case 'sofa':
        return 'Sofa';
      case 'chair':
        return 'Ghế';
      case 'table':
        return 'Bàn';
      case 'wardrobe':
        return 'Tủ';
      case 'refrigerator':
        return 'Tủ lạnh';
      case 'tv':
        return 'TV';
      case 'door':
        return 'Cửa';
      case 'window':
        return 'Cửa sổ';
      case 'fan':
        return 'Quạt';
      case 'laptop':
        return 'Laptop';
      case 'washing_machine':
        return 'Máy giặt';
      default:
        return label;
    }
  }

  double _readRoomDouble(String key, double fallback) {
    final value = _activeRoomLayout?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double get _roomWidthMeters => _readRoomDouble('Width', 5);
  double get _roomDepthMeters => _readRoomDouble('Depth', 3);

  TFLiteDetectionResult? _bestLayoutDetection(
    List<TFLiteDetectionResult> detections, {
    String? preferredLabel,
  }) {
    if (preferredLabel != null) {
      TFLiteDetectionResult? preferred;
      for (final detection in detections) {
        if (!_shouldUseDetectionForNavigation(detection)) continue;
        if (detection.label != preferredLabel) continue;
        if (detection.confidence < _layoutReferenceThreshold) continue;
        if (_findLayoutObject(detection.label) == null) continue;
        if (preferred == null || detection.confidence > preferred.confidence) {
          preferred = detection;
        }
      }

      if (preferred != null) {
        final objectName =
            ObjectMappingService.getVietnameseName(preferred.label);
        final percent = (preferred.confidence * 100).toStringAsFixed(0);
        print(
          ' Layout map: ưu tiên vật đích $objectName $percent% để định vị',
        );
        _addActivityLog(
          'Layout',
          'Ưu tiên $objectName $percent% vì đây là vật cần tìm.',
        );
        return preferred;
      }
    }

    TFLiteDetectionResult? best;
    for (final detection in detections) {
      if (!_shouldUseDetectionForNavigation(detection)) continue;
      if (detection.confidence < _layoutReferenceThreshold) continue;
      if (_findLayoutObject(detection.label) == null) continue;
      if (best == null || detection.confidence > best.confidence) {
        best = detection;
      }
    }
    if (best != null && best.confidence < _strongVisualThreshold) {
      final objectName = ObjectMappingService.getVietnameseName(best.label);
      final percent = (best.confidence * 100).toStringAsFixed(0);
      print(
        ' Layout map: $objectName chỉ $percent% nhưng có trong layout, dùng làm mốc định vị',
      );
      _addActivityLog(
        'Layout',
        '$objectName $percent% có trong layout, dùng làm mốc hỗ trợ.',
      );
    }
    return best;
  }

  double _estimateUserDistanceFromObject(TFLiteDetectionResult detection) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final distance = GuidanceService.estimateDistance(
      detection.width,
      detection.height,
      sourceSize.width,
      sourceSize.height,
    );

    return switch (distance) {
      DistanceLevel.near => 0.8,
      DistanceLevel.medium => 1.5,
      DistanceLevel.far => 2.4,
    };
  }

  Offset _clampPointInsideRoom(Offset point) {
    final halfWidth = _roomWidthMeters / 2;
    final halfDepth = _roomDepthMeters / 2;
    const margin = 0.2;
    return Offset(
      point.dx.clamp(-halfWidth + margin, halfWidth - margin).toDouble(),
      point.dy.clamp(-halfDepth + margin, halfDepth - margin).toDouble(),
    );
  }

  void _updateEstimatedUserPosition(TFLiteDetectionResult detection) {
    if (_activeRoomLayout == null) return;

    final layoutObject = _findLayoutObject(detection.label);
    if (layoutObject == null) return;

    final objectPosition = Offset(
      _readDouble(layoutObject, 'PosX'),
      _readDouble(layoutObject, 'PosZ'),
    );
    var objectToUser = Offset.zero - objectPosition;
    if (objectToUser.distance < 0.05) {
      objectToUser = const Offset(0, 1);
    }

    final direction = objectToUser / objectToUser.distance;
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final zone = GuidanceService.analyzeHorizontalPosition(
      detection.centerX,
      sourceSize.width,
    );
    final lateralAdjust = switch (zone) {
      ScreenZone.left => 0.35,
      ScreenZone.center => 0.0,
      ScreenZone.right => -0.35,
    };
    final perpendicular = Offset(-direction.dy, direction.dx);
    final distance = _estimateUserDistanceFromObject(detection);
    final userPosition = _clampPointInsideRoom(
      objectPosition + direction * distance + perpendicular * lateralAdjust,
    );
    final userToObject = objectPosition - userPosition;
    final heading = math.atan2(userToObject.dx, userToObject.dy) * 180 / math.pi;
    final objectName = _objectDisplayName(detection.label);
    final percent = (detection.confidence * 100).toStringAsFixed(0);

    print(
      ' Layout map: ước lượng vị trí người dùng từ $objectName ($percent%) '
      '=> x=${userPosition.dx.toStringAsFixed(2)}, z=${userPosition.dy.toStringAsFixed(2)}',
    );

    if (!mounted) return;
    setState(() {
      _estimatedUserPosition = userPosition;
      _estimatedUserHeadingDegrees = heading;
      _mapReferenceObject = detection.label;
      _mapPositionStatus = 'Vị trí ước lượng từ $objectName';
    });
    _addActivityLog(
      'Layout',
      'Cập nhật vị trí người dùng theo mốc $objectName ($percent%).',
    );
    _syncUserMarkerToScene();
  }

  String _handleObjectFound(TFLiteDetectionResult detection) {
    if (detection.label == _targetObject) {
      _lastConfirmedTargetDetection = detection;
    }

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
    final verticalText = _createImageVerticalGuidance(detection, objectName);

    return '$positionText. $distanceText. $verticalText $movementText';
  }

  String _createStepGuidance(TFLiteDetectionResult detection) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final objectName = ObjectMappingService.getVietnameseName(detection.label);
    final stepCount = _nextMovementStepCount(detection, sourceSize);

    final horizontalAdjustment = _createHorizontalAdjustmentGuidance(
      detection,
      sourceSize,
    );
    final verticalAdjustment = _createCameraTiltGuidance(
      detection,
      sourceSize,
      objectName,
    );

    if (horizontalAdjustment != null || verticalAdjustment != null) {
      final stepText = _createMovementStepText(
        stepCount,
        horizontalDirection: horizontalAdjustment,
      );
      final cameraText = verticalAdjustment == null
          ? ''
          : ' Sau khi dừng lại, $verticalAdjustment';

      return '$objectName đang nằm trong khung hình nhưng hơi lệch. $stepText$cameraText Sau khi làm xong, hãy nói: đã xong.';
    }

    final stepText = _createMovementStepText(stepCount);
    final verticalText = _createImageVerticalGuidance(detection, objectName);

    return '$objectName đang nằm trong khung hình phía trước. $verticalText $stepText Sau khi làm xong, hãy nói: đã xong.';
  }

  bool _isTargetCloseEnough(TFLiteDetectionResult detection) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final zone = GuidanceService.analyzeHorizontalPosition(
      detection.centerX,
      sourceSize.width,
    );
    final areaRatio = detection.area / (sourceSize.width * sourceSize.height);
    final widthRatio = detection.width / sourceSize.width;
    final heightRatio = detection.height / sourceSize.height;

    if (detection.label == 'laptop') {
      return _isLaptopCloseEnough(
        detection: detection,
        sourceSize: sourceSize,
        zone: zone,
        areaRatio: areaRatio,
        widthRatio: widthRatio,
        heightRatio: heightRatio,
      );
    }

    final isNearByEdge = (_isDetectionAtBottomEdge(detection, sourceSize) ||
            _isDetectionAtTopEdge(detection, sourceSize)) &&
        areaRatio >= 0.24 &&
        (widthRatio >= 0.55 || heightRatio >= 0.78);
    if (isNearByEdge) {
      final objectName = ObjectMappingService.getVietnameseName(detection.label);
      print(
        ' Điều hướng: $objectName sát mép ảnh và thật sự đủ lớn, coi là đã rất gần area=${areaRatio.toStringAsFixed(3)}, width=${widthRatio.toStringAsFixed(2)}, height=${heightRatio.toStringAsFixed(2)}',
      );
      return true;
    }

    if (areaRatio >= 0.34 || (widthRatio >= 0.70 && heightRatio >= 0.55)) {
      final objectName = ObjectMappingService.getVietnameseName(detection.label);
      print(
        ' Điều hướng: $objectName chiếm nhiều khung hình, coi là rất gần area=${areaRatio.toStringAsFixed(3)}, width=${widthRatio.toStringAsFixed(2)}, height=${heightRatio.toStringAsFixed(2)}',
      );
      return true;
    }

    return zone == ScreenZone.center &&
        areaRatio >= 0.30 &&
        (widthRatio >= 0.55 || heightRatio >= 0.65);
  }

  bool _isLaptopCloseEnough({
    required TFLiteDetectionResult detection,
    required Size sourceSize,
    required ScreenZone zone,
    required double areaRatio,
    required double widthRatio,
    required double heightRatio,
  }) {
    final centerYRatio = detection.centerY / sourceSize.height;
    final isAtUsefulEdge = _isDetectionAtBottomEdge(detection, sourceSize) ||
        _isDetectionAtTopEdge(detection, sourceSize);
    final isCloseByArea = areaRatio >= 0.16;
    final isCloseByPartialView =
        isAtUsefulEdge && areaRatio >= 0.08 && widthRatio >= 0.34;
    final isCloseOnTableLevel =
        zone == ScreenZone.center && centerYRatio >= 0.42 && areaRatio >= 0.10;

    final isClose =
        isCloseByArea || isCloseByPartialView || isCloseOnTableLevel;
    if (isClose) {
      print(
        ' Điều hướng laptop: dùng ngưỡng riêng cho vật nhỏ, coi là gần area=${areaRatio.toStringAsFixed(3)}, width=${widthRatio.toStringAsFixed(2)}, height=${heightRatio.toStringAsFixed(2)}, centerY=${centerYRatio.toStringAsFixed(2)}',
      );
    }
    return isClose;
  }

  String _createMovementStepText(
    int stepCount, {
    String? horizontalDirection,
  }) {
    final directionText = horizontalDirection == null
        ? 'đi thẳng'
        : 'đi hơi chếch $horizontalDirection';

    return switch (stepCount) {
      3 =>
        'Chặng này $directionText ba bước nhỏ. Mỗi bước thật chậm, giữ tay phía trước để dò đường.',
      2 =>
        'Chặng này $directionText hai bước nhỏ. Sau hai bước thì dừng lại.',
      _ =>
        'Chặng này $directionText một bước rất nhỏ. Hãy giảm tốc và giữ tay phía trước để dò đường.',
    };
  }

  bool _isDetectionAtBottomEdge(
    TFLiteDetectionResult detection,
    Size sourceSize,
  ) {
    final bottomRatio = (detection.y + detection.height) / sourceSize.height;
    final centerRatio = detection.centerY / sourceSize.height;
    return bottomRatio >= 0.96 || centerRatio >= 0.82;
  }

  bool _isDetectionAtTopEdge(
    TFLiteDetectionResult detection,
    Size sourceSize,
  ) {
    final topRatio = detection.y / sourceSize.height;
    final centerRatio = detection.centerY / sourceSize.height;
    return topRatio <= 0.04 || centerRatio <= 0.18;
  }

  String? _createHorizontalAdjustmentGuidance(
    TFLiteDetectionResult detection,
    Size sourceSize,
  ) {
    final centerRatio = detection.centerX / sourceSize.width;
    final leftRatio = detection.x / sourceSize.width;
    final rightRatio = (detection.x + detection.width) / sourceSize.width;

    if (leftRatio <= 0.02 || centerRatio < 0.32) {
      return 'sang trái';
    }

    if (rightRatio >= 0.98 || centerRatio > 0.68) {
      return 'sang phải';
    }

    return null;
  }

  String? _createCameraTiltGuidance(
    TFLiteDetectionResult detection,
    Size sourceSize,
    String objectName,
  ) {
    final centerRatio = detection.centerY / sourceSize.height;

    if (centerRatio < 0.28) {
      return 'nâng camera lên một chút để nhìn rõ $objectName hơn.';
    }

    if (centerRatio > 0.72) {
      return 'hạ camera xuống một chút để nhìn rõ $objectName hơn.';
    }

    return null;
  }

  int _nextMovementStepCount(
    TFLiteDetectionResult detection,
    Size sourceSize,
  ) {
    final areaRatio = detection.area / (sourceSize.width * sourceSize.height);
    final rawStepCount = detection.label == 'laptop'
        ? areaRatio < 0.05
            ? 2
            : 1
        : areaRatio < 0.06
            ? 3
            : areaRatio < 0.14
                ? 2
                : 1;
    final cappedStepCount = _lastSuggestedStepCount == null
        ? rawStepCount
        : math.min(rawStepCount, _lastSuggestedStepCount!);
    _lastSuggestedStepCount = cappedStepCount;

    if (rawStepCount > cappedStepCount) {
      print(
        ' Điều hướng: giới hạn chặng từ $rawStepCount bước xuống $cappedStepCount bước để chặng sau không lớn hơn chặng trước',
      );
    }

    return cappedStepCount;
  }

  String _createCloseReachGuidance(
    TFLiteDetectionResult detection,
    String objectName,
  ) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;

    if (detection.label == 'laptop') {
      if (_isDetectionAtBottomEdge(detection, sourceSize)) {
        return '$objectName đã ở rất gần và nằm thấp trong khung hình. Hãy dừng lại, đưa tay thật chậm xuống mặt bàn hoặc mặt kệ phía trước để dò laptop.';
      }

      if (_isDetectionAtTopEdge(detection, sourceSize)) {
        return '$objectName đã ở rất gần nhưng nằm cao trong khung hình. Hãy dừng lại, đưa tay chậm lên mặt bàn hoặc kệ phía trước, không với quá nhanh.';
      }

      return '$objectName đã ở gần. Hãy dừng lại, đưa tay chậm lên mặt bàn hoặc mặt phẳng phía trước để dò laptop.';
    }

    if (_isDetectionAtBottomEdge(detection, sourceSize)) {
      return '$objectName đã ở rất gần và nằm thấp phía trước. Hãy dừng lại, hạ tay xuống thấp và dò thật chậm để tìm vật.';
    }

    if (_isDetectionAtTopEdge(detection, sourceSize)) {
      return '$objectName đã ở rất gần và nằm cao phía trước. Hãy dừng lại, đưa tay lên cao từ từ để dò vật, không với quá nhanh.';
    }

    return '$objectName đã ở rất gần. Hãy dừng lại, đưa tay lại gần phía trước để tìm vật.';
  }

  String _createImageVerticalGuidance(
    TFLiteDetectionResult detection,
    String objectName,
  ) {
    final sourceSize = _lastImageSize ?? MediaQuery.of(context).size;
    final centerRatio = detection.centerY / sourceSize.height;

    if (detection.label == 'laptop') {
      if (centerRatio >= 0.66) {
        return '$objectName nằm thấp trong khung hình, có thể đang ở mép bàn hoặc gần phía dưới camera. Khi đến gần, hãy hạ tay chậm xuống mặt bàn để dò.';
      }

      if (centerRatio <= 0.34) {
        return '$objectName nằm cao trong khung hình, có thể đang ở trên kệ hoặc mặt bàn cao. Khi đến gần, hãy đưa tay lên chậm và dò mặt phẳng phía trước.';
      }

      return '$objectName đang ở khoảng giữa khung hình. Laptop thường nằm trên bàn hoặc kệ, hãy đưa tay chậm về mặt phẳng phía trước để dò.';
    }

    if (centerRatio >= 0.66) {
      return '$objectName đang nằm ở phía dưới khung hình. Khi đến gần, hãy hạ tay xuống thấp và dò chậm phía dưới để lấy hoặc chạm vào vật.';
    }

    if (centerRatio <= 0.34) {
      return '$objectName đang nằm ở phía trên khung hình. Vật có thể ở cao, ví dụ treo trên tường hoặc đặt trên kệ; hãy đưa tay lên cao từ từ, không với quá nhanh.';
    }

    return '$objectName đang ở khoảng giữa khung hình. Hãy đưa tay ra phía trước ở tầm ngang người để dò vật.';
  }

  double _readDouble(Map<String, dynamic> object, String key, [double fallback = 0]) {
    final value = object[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String? _createLayoutGuidance({
    required bool visualConfirmed,
    TFLiteDetectionResult? detection,
  }) {
    if (_targetObject == null || _activeRoomLayout == null) return null;

    final target = _findLayoutObject(_targetObject!);
    if (target == null) return null;

    final roomDepth =
        double.tryParse((_activeRoomLayout?['Depth']).toString()) ?? 3.0;
    final userX = 0.0;
    final userZ = roomDepth / 2;
    final targetX = _readDouble(target, 'PosX');
    final targetZ = _readDouble(target, 'PosZ');
    final dx = targetX - userX;
    final dz = targetZ - userZ;
    final distance = math.sqrt(dx * dx + dz * dz);
    final targetName = ObjectMappingService.getVietnameseName(_targetObject!);
    final horizontalText = dx.abs() < 0.35
        ? '$targetName nằm gần hướng thẳng phía trước theo layout'
        : dx < 0
            ? '$targetName nằm lệch bên trái theo layout'
            : '$targetName nằm lệch bên phải theo layout';

    final distanceText = distance < 1.2
        ? 'khoảng cách trên layout đang khá gần'
        : distance < 2.5
            ? 'khoảng cách trên layout ở mức trung bình'
            : 'khoảng cách trên layout còn khá xa';

    final stepText = dx.abs() >= 0.55
        ? dx < 0
            ? 'Chặng này hãy xoay người nhẹ sang trái khoảng 45 độ, chưa cần bước nhanh.'
            : 'Chặng này hãy xoay người nhẹ sang phải khoảng 45 độ, chưa cần bước nhanh.'
        : distance > 2.5
            ? 'Chặng này đi thẳng ba bước nhỏ, mỗi bước thật chậm.'
            : distance > 1.2
                ? 'Chặng này đi thẳng hai bước nhỏ rồi dừng lại.'
                : 'Chặng này đi thẳng một bước rất nhỏ, giảm tốc và đưa tay ra trước.';

    final visualText = visualConfirmed
        ? 'Đã phát hiện $targetName.'
        : 'Chưa nhìn thấy rõ $targetName.';
    final imagePositionText = detection == null
        ? ''
        : ' ${_createImageVerticalGuidance(detection, targetName)}';

    return '$visualText$imagePositionText $horizontalText, $distanceText. $stepText Sau khi làm xong, hãy nói: đã xong.';
  }
  Map<String, dynamic>? _findLayoutBlocker({
    required double userX,
    required double userZ,
    required double targetX,
    required double targetZ,
    required String targetClass,
  }) {
    final vx = targetX - userX;
    final vz = targetZ - userZ;
    final lengthSquared = vx * vx + vz * vz;
    if (lengthSquared <= 0.0001) return null;

    Map<String, dynamic>? nearest;
    double nearestT = double.infinity;

    for (final object in _layoutObjects) {
      final className = (object['ClassName'] ?? '').toString();
      if (className == targetClass || className.isEmpty) continue;

      final ox = _readDouble(object, 'PosX');
      final oz = _readDouble(object, 'PosZ');
      final t = (((ox - userX) * vx) + ((oz - userZ) * vz)) / lengthSquared;
      if (t <= 0.08 || t >= 0.95) continue;

      final closestX = userX + t * vx;
      final closestZ = userZ + t * vz;
      final distanceX = ox - closestX;
      final distanceZ = oz - closestZ;
      final distanceToPath =
          math.sqrt(distanceX * distanceX + distanceZ * distanceZ);
      final objectRadius =
          math.max(_readDouble(object, 'Width'), _readDouble(object, 'Depth')) / 2;

      if (distanceToPath <= objectRadius + 0.35 && t < nearestT) {
        nearest = object;
        nearestT = t;
      }
    }

    return nearest;
  }

  TFLiteDetectionResult? _bestReliableDetection({
    bool includeTarget = false,
    double minConfidence = _layoutReferenceThreshold,
    double? maxConfidence,
  }) {
    TFLiteDetectionResult? best;

    for (final detection in _lastDetections) {
      if (!_shouldUseDetectionForNavigation(detection)) continue;
      if (detection.confidence < minConfidence) continue;
      if (maxConfidence != null && detection.confidence >= maxConfidence) {
        continue;
      }
      if (_findLayoutObject(detection.label) == null) continue;
      if (!includeTarget && detection.label == _targetObject) continue;

      if (best == null || detection.confidence > best.confidence) {
        best = detection;
      }
    }

    return best;
  }

  TFLiteDetectionResult? _bestTargetDetectionInRange(
    List<TFLiteDetectionResult> detections, {
    required double minConfidence,
    double? maxConfidence,
  }) {
    if (_targetObject == null) return null;

    TFLiteDetectionResult? best;
    for (final detection in detections) {
      if (!_shouldUseDetectionForNavigation(detection)) continue;
      if (detection.label != _targetObject) continue;
      if (detection.confidence < minConfidence) continue;
      if (maxConfidence != null && detection.confidence >= maxConfidence) {
        continue;
      }
      if (best == null || detection.confidence > best.confidence) {
        best = detection;
      }
    }
    return best;
  }

  Future<TFLiteDetectionResult?> _verifyLowConfidenceTargetIfNeeded() async {
    final lowDetection = _lastLowConfidenceTargetDetection;
    final imagePath = _lastLowConfidenceImagePath;
    if (_targetObject == null ||
        lowDetection == null ||
        imagePath == null) {
      return null;
    }

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    final candidatePercent =
        (lowDetection.confidence * 100).toStringAsFixed(0);
    _addActivityLog(
      'OpenRouter',
      'Gửi crop-box $objectName $candidatePercent% để xác minh.',
    );

    final isConfirmed = await _verifyDetectionWithGemini(
      imagePath: imagePath,
      detection: lowDetection,
      expectedLabel: _targetObject!,
      logName: objectName,
    );

    if (isConfirmed) {
      print(
        ' OpenRouter Vision: xác nhận $objectName từ box TFLite thấp $candidatePercent%',
      );
      _handleObjectFound(lowDetection);
      return lowDetection;
    }

    _addActivityLog(
      'OpenRouter',
      'Không xác nhận crop-box là $objectName. Bỏ qua box nghi ngờ.',
    );
    return null;
  }

  Future<bool> _verifyDetectionWithGemini({
    required String imagePath,
    required TFLiteDetectionResult detection,
    required String expectedLabel,
    required String logName,
  }) async {
    if (!_canVerifyLabelWithGemini(expectedLabel)) {
      print(
        ' OpenRouter: bỏ qua crop-box $logName vì label không có trong layout',
      );
      _addActivityLog(
        'OpenRouter',
        'Bỏ qua $logName vì vật này không có trong layout.',
      );
      return false;
    }

    final result = await _visionVerificationService.verifyDetection(
      imageFile: File(imagePath),
      detection: detection,
      expectedLabel: expectedLabel,
    );

    if (result == null) {
      final errorDetail = _visionVerificationService.lastError;
      _addActivityLog(
        'OpenRouter',
        errorDetail == null || errorDetail.isEmpty
            ? 'Chưa xác minh được crop-box $logName. Bỏ qua để tránh xử lý sai.'
            : 'Chưa xác minh được crop-box $logName. Lỗi: $errorDetail',
      );
      return false;
    }

    final openRouterPercent = (result.confidence * 100).toStringAsFixed(0);
    final tflitePercent = (detection.confidence * 100).toStringAsFixed(0);
    final reasonText = result.reason.trim().isEmpty
        ? ''
        : ' Lý do: ${result.reason.trim()}.';
    final isConfirmed = result.isCorrect && result.confidence >= 0.55;
    _addActivityLog(
      'OpenRouter',
      isConfirmed
          ? 'Xác nhận crop-box $logName: đúng. TFLite $tflitePercent%, OpenRouter $openRouterPercent%.$reasonText'
          : 'Xác nhận crop-box $logName: chưa đủ chắc. TFLite $tflitePercent%, OpenRouter $openRouterPercent%.$reasonText',
    );
    return isConfirmed;
  }

  Future<bool> _handleMissingTargetDuringMovement(String objectName) async {
    final imagePath = _lastCapturedImagePath;
    if (imagePath == null || _targetObject == null) return false;

    _addActivityLog(
      'OpenRouter',
      'TFLite tạm mất box $objectName trong lúc đang di chuyển, kiểm tra lại toàn ảnh.',
    );

    final result = await _visionVerificationService.verifyTargetInFullImage(
      imageFile: File(imagePath),
      expectedLabel: _targetObject!,
    );

    if (!mounted || !_isNavigationActive || _targetObject == null) {
      return true;
    }

    if (result != null && result.isCorrect && result.confidence >= 0.5) {
      final percent = (result.confidence * 100).toStringAsFixed(0);
      final previousTargetPercent = _lastConfirmedTargetDetection == null
          ? null
          : (_lastConfirmedTargetDetection!.confidence * 100)
              .toStringAsFixed(0);
      final reasonText = result.reason.trim().isEmpty
          ? ''
          : ' Lý do: ${result.reason.trim()}.';
      _addActivityLog(
        'OpenRouter',
        previousTargetPercent == null
            ? 'Xác nhận toàn ảnh vẫn có $objectName ($percent%).$reasonText'
            : 'Xác nhận toàn ảnh vẫn có $objectName ($percent%). Box mục tiêu gần nhất trước đó $previousTargetPercent%.$reasonText',
      );

      if (_targetObject == 'laptop') {
        final guidance =
            '$objectName đã ở rất gần '
            'Hãy dừng lại, đưa tay thật chậm lên mặt bàn hoặc mặt kệ phía trước để dò laptop. '
            'Tôi sẽ thoát trạng thái tìm vật.';
        _isNavigationActive = false;
        _awaitingMovementConfirmation = false;
        _awaitingReadyForMovement = false;
        _hasAskedReadyForMovement = false;
        _movementGuidanceStarted = false;
        _hasAddedFinalTableApproachStep = false;
        _hasAddedFinalLaptopApproachStep = false;
        _pendingTargetDetection = null;
        _lastConfirmedTargetDetection = null;
        _lastLowConfidenceTargetDetection = null;
        _lastLowConfidenceImagePath = null;
        _lastSuggestedStepCount = null;
        _scanRotationDegrees = 0;
        _lastScanRotationDegrees = 0;
        if (mounted) {
          setState(() {
            _targetObject = null;
            _navigationStepCount = 0;
            _lastGuidance = guidance;
            _recognizedText = 'Đã thoát trạng thái tìm vật';
          });
          _syncTargetMarkerToScene();
        }
        await _speak(
          '$guidance Nếu cần tìm vật khác, hãy bật mic để tôi hỗ trợ.',
          restartListening: false,
        );
        return true;
      }

      final guidance =
          'Tôi vẫn xác nhận thấy $objectName, nhưng mô hình chưa vẽ được box rõ. '
          'Hãy giữ hướng hiện tại, tiến một bước nhỏ thật chậm và đưa tay ra phía trước để dò vật. '
          'Sau khi làm xong, hãy nói: đã xong.';
      if (mounted) {
        setState(() => _lastGuidance = guidance);
      }
      await _speakAndWaitForMovement(guidance);
      return true;
    }

    final errorDetail = _visionVerificationService.lastError;
    _addActivityLog(
      'OpenRouter',
      errorDetail == null || errorDetail.isEmpty
          ? 'Chưa xác nhận được toàn ảnh có $objectName.'
          : 'Chưa xác nhận được toàn ảnh có $objectName. Lỗi: $errorDetail',
    );

    if (_targetObject == 'laptop' && _isLikelyVeryCloseToLaptopFrame()) {
      final guidance =
          '$objectName có thể đang ở rất gần hoặc bị cắt khỏi khung hình, nên mô hình chưa nhận ra chính xác. '
          'Hãy dừng lại, đưa tay thật chậm lên mặt bàn hoặc mặt kệ phía trước để dò laptop. '
          'Nếu đã chạm được vật, hãy bật mic và nói: tôi thấy vật rồi.';
      if (mounted) {
        setState(() => _lastGuidance = guidance);
      }
      _addActivityLog(
        'Điều hướng',
        'Laptop có dấu hiệu quá gần/cắt khung hình, ưu tiên hướng dẫn dò tại chỗ thay vì báo còn xa.',
      );
      await _speakAndWaitForMovement(guidance);
      return true;
    }

    final guidance =
        'Tôi chưa thấy rõ $objectName trong ảnh mới. Có thể bạn đang đứng quá gần, camera bị lệch hoặc vật bị cắt khỏi khung hình. '
        'Hãy giữ nguyên vị trí, lùi nhẹ nửa bước nếu an toàn, rồi đưa camera chậm lên xuống để lấy trọn vật. '
        'Sau khi làm xong, hãy nói: đã xong.';
    if (mounted) {
      setState(() => _lastGuidance = guidance);
    }
    await _speakAndWaitForMovement(guidance);
    return true;
  }

  bool _isLikelyVeryCloseToLaptopFrame() {
    final imageSize = _lastImageSize;
    if (imageSize == null || _lastDetections.isEmpty) return false;

    for (final detection in _lastDetections) {
      final areaRatio = detection.area / (imageSize.width * imageSize.height);
      final widthRatio = detection.width / imageSize.width;
      final heightRatio = detection.height / imageSize.height;
      final touchesEdge = detection.x <= imageSize.width * 0.04 ||
          detection.y <= imageSize.height * 0.04 ||
          detection.x + detection.width >= imageSize.width * 0.96 ||
          detection.y + detection.height >= imageSize.height * 0.96;
      if (areaRatio >= 0.22 || widthRatio >= 0.70 || heightRatio >= 0.58) {
        return true;
      }
      if (touchesEdge && areaRatio >= 0.12) {
        return true;
      }
    }

    return false;
  }

  Future<void> _handleConfirmedTargetDuringNavigation(
    TFLiteDetectionResult found,
  ) async {
    if (_targetObject == null) return;

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    if (!_awaitingReadyForMovement && !_hasAskedReadyForMovement) {
      _pendingTargetDetection = found;
      _awaitingReadyForMovement = true;
      _hasAskedReadyForMovement = true;
      _awaitingMovementConfirmation = false;
      final message =
          'Đã phát hiện $objectName. Hãy bật mic và nói: sẵn sàng.';
      if (mounted) {
        setState(() {
          _lastGuidance = message;
          _recognizedText = 'Hãy bật mic và nói: sẵn sàng';
        });
      }
      await _speak(message, restartListening: false);
      return;
    }

    await _startMovementToDetectedTarget(found);
  }

  double _normalizeAngle(double angle) {
    var normalized = angle;
    while (normalized > 180) {
      normalized -= 360;
    }
    while (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }

  int _roundToStepAngle(double angle) {
    final absoluteAngle = angle.abs();
    if (absoluteAngle < 68) return 45;
    if (absoluteAngle < 135) return 90;
    return 180;
  }

  String _createDefaultScanGuidance() {
    final objectName = _targetObject == null
        ? 'vật cần tìm'
        : ObjectMappingService.getVietnameseName(_targetObject!);
    _lastScanRotationDegrees = 45;
    return 'Chưa phát hiện rõ $objectName trong ảnh. Vui lòng xoay nhẹ người và điện thoại sang phải khoảng 45 độ, không cần thật chính xác, rồi đứng yên 3 giây để tôi chụp lại.';
  }

  String _createLayoutScanGuidance(TFLiteDetectionResult reference) {
    if (_targetObject == null || _activeRoomLayout == null) {
      return _createDefaultScanGuidance();
    }

    final target = _findLayoutObject(_targetObject!);
    final seenObject = _findLayoutObject(reference.label);
    final targetName = ObjectMappingService.getVietnameseName(_targetObject!);
    final seenName = ObjectMappingService.getVietnameseName(reference.label);
    final seenPercent = (reference.confidence * 100).toStringAsFixed(0);
    print(
      ' Layout: detect thấy $seenName ($seenPercent%), dùng làm mốc để tìm $targetName',
    );

    if (target == null || seenObject == null) {
      print('Layout: thiếu tọa độ $seenName hoặc $targetName trong phòng');
      _lastScanRotationDegrees = 45;
      return 'Tôi thấy $seenName. Hãy xoay nhẹ sang phải khoảng 45 độ, không cần thật chính xác, rồi đứng yên 3 giây để tôi chụp lại.';
    }

    final targetX = _readDouble(target, 'PosX');
    final targetZ = _readDouble(target, 'PosZ');
    final seenX = _readDouble(seenObject, 'PosX');
    final seenZ = _readDouble(seenObject, 'PosZ');

    final targetAngle = math.atan2(targetX, targetZ);
    final seenAngle = math.atan2(seenX, seenZ);
    final deltaDegrees =
        _normalizeAngle((targetAngle - seenAngle) * 180 / math.pi);
    final roundedAngle = _roundToStepAngle(deltaDegrees);
    print(
      ' Layout: góc lệch từ $seenName tới $targetName = ${deltaDegrees.toStringAsFixed(1)} độ',
    );

    if (deltaDegrees.abs() < 20) {
      _lastScanRotationDegrees = 0;
      return 'Tôi thấy $seenName. Dựa vào layout, hãy giữ hướng hiện tại, sau đó đứng yên 3 giây để tôi chụp lại.';
    }

    if (deltaDegrees.abs() >= 150) {
      _lastScanRotationDegrees = 180;
      return 'Tôi thấy $seenName. Dựa vào layout, hãy quay người 180 độ thật chậm, rồi đứng yên 3 giây để tôi chụp lại.';
    }

    final direction = deltaDegrees < 0 ? 'phải' : 'trái';
    _lastScanRotationDegrees = roundedAngle;
    print(
      ' Layout: hướng xoay đề xuất = $direction $roundedAngle độ',
    );
    return 'Tôi thấy $seenName. Dựa vào layout, hãy xoay người và điện thoại sang $direction khoảng $roundedAngle độ thật chậm, rồi đứng yên 3 giây để tôi chụp lại.';
  }

  Future<TFLiteDetectionResult?> _captureAndAnalyzeImage() async {
    if (!_isCameraInitialized) {
      print('Camera: chưa sẵn sàng để chụp ảnh');
      return null;
    }

    if (!_isDetectionInitialized) {
      const message = 'TFLite chưa sẵn sàng, hãy thêm assets/models/best.tflite';
      print('Detect local: $message');
      if (mounted) {
        setState(() => _apiStatus = message);
      }
      return null;
    }

    if (_activeTask != _CameraTask.idle) {
      final message = 'Đang bận tác vụ khác, vui lòng chờ xong rồi chụp lại';
      print('Detect local: $message');
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
    _lastLowConfidenceTargetDetection = null;
    _lastLowConfidenceImagePath = null;
    if (mounted) {
      setState(() => _apiStatus = 'Đang chụp ảnh...');
    }

    try {
      print('Camera: bắt đầu chụp ảnh');
      _addActivityLog('Camera', 'Bắt đầu chụp ảnh.');
      final image = await _cameraController.takePicture();
      print('Camera: đã chụp ảnh tại ${image.path}');
      _addActivityLog('Camera', 'Đã chụp ảnh, đang phân tích vật thể.');

      if (mounted) {
        setState(() {
          _lastCapturedImagePath = image.path;
          _lastAnalyzedImagePath = null;
          _lastImageSize = null;
          _lastDetections = [];
          _apiStatus = 'Đã chụp ảnh, đang detect local bằng TFLite...';
        });
      }

      final result = await _detectionService.detectImageFile(File(image.path));

      if (!mounted) return null;

      final usableDetections =
          result.detections.where(_shouldUseDetectionForNavigation).toList();

      setState(() {
        _lastAnalyzedImagePath = result.annotatedImagePath;
        _lastImageSize = Size(
          result.imageWidth.toDouble(),
          result.imageHeight.toDouble(),
        );
        _lastDetections = usableDetections;
        _apiStatus = 'Detect local xong: ${usableDetections.length} vật thể';
      });
      _addActivityLog('Detect', _createDetectionLog(usableDetections));

      if (_targetObject != null && usableDetections.isNotEmpty) {
        final found = _bestTargetDetectionInRange(
          usableDetections,
          minConfidence: _visualConfirmThreshold,
        );

        if (found != null) {
          print(
            ' Detect local: đã xác nhận vật mục tiêu >= ${(_visualConfirmThreshold * 100).toStringAsFixed(0)}%',
          );
          _handleObjectFound(found);
          return found;
        }

        final lowConfidenceTarget = _bestTargetDetectionInRange(
          usableDetections,
          minConfidence: _lowConfidenceTargetThreshold,
          maxConfidence: _visualConfirmThreshold,
        );
        if (lowConfidenceTarget != null) {
          final objectName =
              ObjectMappingService.getVietnameseName(lowConfidenceTarget.label);
          final percent =
              (lowConfidenceTarget.confidence * 100).toStringAsFixed(0);
          if (_canVerifyLabelWithGemini(lowConfidenceTarget.label)) {
            _lastLowConfidenceTargetDetection = lowConfidenceTarget;
            _lastLowConfidenceImagePath = image.path;
            print(
              ' Detect local: nghi ngờ $objectName $percent%, có trong layout nên cần OpenRouter xác minh crop-box',
            );
            _addActivityLog(
              'Detect',
              'Nghi ngờ $objectName $percent%, chờ OpenRouter xác minh crop-box.',
            );
            setState(() {
              _lastGuidance =
                  'Có thể đã thấy $objectName nhưng độ tin cậy còn thấp.';
            });
            final mapReference = _bestLayoutDetection(
              usableDetections,
              preferredLabel: lowConfidenceTarget.label,
            );
            if (mapReference != null) {
              _updateEstimatedUserPosition(mapReference);
            }
            return null;
          } else {
            print(
              ' Detect local: bỏ qua $objectName $percent% vì không có trong layout',
            );
            _addActivityLog(
              'Detect',
              'Bỏ qua $objectName $percent% vì không có trong layout.',
            );
          }
        } else {
          setState(() {
            _lastGuidance =
                'Đã detect ảnh nhưng chưa thấy rõ vật mục tiêu với độ tin cậy từ 10% trở lên';
          });
        }
      }

      final mapReference = _bestLayoutDetection(usableDetections);
      if (mapReference != null) {
        _updateEstimatedUserPosition(mapReference);
      } else {
        print('Layout map: chưa có vật detect đủ tin cậy để định vị');
      }
      return null;
    } catch (e) {
      print('Detect local: lỗi khi chụp hoặc phân tích ảnh: $e');
      _addActivityLog('Detect', 'Lỗi khi chụp hoặc phân tích ảnh: $e');
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
        'Tôi đã hiểu đồ vật bạn muốn tìm, nhưng mô hình nhận diện chưa sẵn sàng. Hãy kiểm tra file best.tflite trong ứng dụng.',
        restartListening: false,
      );
      return;
    }

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    _isNavigationActive = true;
    _awaitingMovementConfirmation = false;
    _awaitingReadyForMovement = false;
    _hasAskedReadyForMovement = false;
    _movementGuidanceStarted = false;
    _hasAddedFinalTableApproachStep = false;
    _hasAddedFinalLaptopApproachStep = false;
    _pendingTargetDetection = null;
    _lastConfirmedTargetDetection = null;
    _lastLowConfidenceTargetDetection = null;
    _lastLowConfidenceImagePath = null;
    _navigationStepCount = 0;
    _lastSuggestedStepCount = null;
    _scanRotationDegrees = 0;
    _lastScanRotationDegrees = 0;

    if (_activeRoomLayout != null && _findLayoutObject(_targetObject!) == null) {
      print(
        ' Layout: $objectName chưa có trong layout, vẫn ưu tiên camera detect và dùng quét 45 độ',
      );
      _addActivityLog(
        'Layout',
        '$objectName chưa có trong layout, vẫn tiếp tục tìm bằng camera.',
      );
    }

    final sameTargetObjects = _findLayoutObjects(_targetObject!);
    if (sameTargetObjects.length > 1) {
      await _speak(
        'Trong layout có ${sameTargetObjects.length} $objectName. Tôi sẽ ưu tiên vị trí phù hợp nhất theo ảnh camera và đưa bạn lần lượt đến từng vị trí nếu cần.',
        restartListening: false,
      );
    }

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
      _awaitingReadyForMovement = false;
      _hasAskedReadyForMovement = false;
      _movementGuidanceStarted = false;
      _hasAddedFinalTableApproachStep = false;
      _hasAddedFinalLaptopApproachStep = false;
      _pendingTargetDetection = null;
      _lastConfirmedTargetDetection = null;
      _lastLowConfidenceTargetDetection = null;
      _lastLowConfidenceImagePath = null;
      _lastSuggestedStepCount = null;
      _scanRotationDegrees = 0;
      _lastScanRotationDegrees = 0;
      await _speak(
        'Tôi vẫn chưa thấy rõ $objectName. Vui lòng đứng yên, xoay nhẹ sang phải khoảng 45 độ rồi bấm mic để thử lại từ đầu.',
        restartListening: false,
      );
      return;
    }

    final found = await _captureAndAnalyzeImage();
    if (!mounted || !_isNavigationActive || _targetObject == null) return;

    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    if (found != null) {
      await _handleConfirmedTargetDuringNavigation(found);
      return;
    }

    if (_movementGuidanceStarted) {
      final lowConfidenceTarget = _lastLowConfidenceTargetDetection;
      if (lowConfidenceTarget != null) {
        final detectedName =
            ObjectMappingService.getVietnameseName(lowConfidenceTarget.label);
        final percent =
            (lowConfidenceTarget.confidence * 100).toStringAsFixed(0);
        print(
          ' Điều hướng: đang đi từng chặng, vẫn bám theo $detectedName dù confidence $percent%',
        );
        _addActivityLog(
          'Detect',
          'Đang trong lộ trình, vẫn bám theo $detectedName $percent%.',
        );
        await _handleConfirmedTargetDuringNavigation(lowConfidenceTarget);
        return;
      }

      final handledByVisionFallback =
          await _handleMissingTargetDuringMovement(objectName);
      if (handledByVisionFallback) {
        return;
      }
    } else {
      final lowConfidenceTarget = _lastLowConfidenceTargetDetection;
      if (lowConfidenceTarget != null) {
        final verifiedLowConfidenceTarget =
            await _verifyLowConfidenceTargetIfNeeded();
        if (!mounted || !_isNavigationActive || _targetObject == null) return;
        if (verifiedLowConfidenceTarget != null) {
          await _handleConfirmedTargetDuringNavigation(
            verifiedLowConfidenceTarget,
          );
          return;
        }
      } else {
        final betterReference = _bestReliableDetection(
          minConfidence: _layoutReferenceThreshold,
        );
        if (betterReference != null) {
          final targetName =
              ObjectMappingService.getVietnameseName(_targetObject!);
          final refName =
              ObjectMappingService.getVietnameseName(betterReference.label);
          print(
            ' Detect: chưa có box $targetName đủ ngưỡng thấp, dùng $refName làm mốc layout',
          );
        }
      }
    }

    if (found == null) {
      if (!_movementGuidanceStarted && _scanRotationDegrees >= 360) {
        await _stopNavigationBecauseScanCompleted(objectName);
        return;
      }

      TFLiteDetectionResult? reliableReference = _bestReliableDetection(
        minConfidence: _strongVisualThreshold,
      );
      if (reliableReference == null) {
        final lowReference = _bestReliableDetection(
          minConfidence: _layoutReferenceThreshold,
          maxConfidence: _strongVisualThreshold,
        );
        final imagePath = _lastCapturedImagePath;
        if (lowReference != null && imagePath != null) {
          final seenName =
              ObjectMappingService.getVietnameseName(lowReference.label);
          final seenPercent =
              (lowReference.confidence * 100).toStringAsFixed(0);
          _addActivityLog(
            'OpenRouter',
            'Gửi crop-box $seenName $seenPercent% để xác minh vật mốc layout.',
          );
          final isReferenceConfirmed = await _verifyDetectionWithGemini(
            imagePath: imagePath,
            detection: lowReference,
            expectedLabel: lowReference.label,
            logName: seenName,
          );
          if (isReferenceConfirmed) {
            reliableReference = lowReference;
          } else {
            print(
              ' Layout: bỏ qua vật mốc ${lowReference.label} vì OpenRouter không xác nhận',
            );
          }
        }
      }
      final scanGuidance = reliableReference == null
          ? _createDefaultScanGuidance()
          : _createLayoutScanGuidance(reliableReference);
      if (reliableReference != null) {
        final seenName =
            ObjectMappingService.getVietnameseName(reliableReference.label);
        final seenPercent =
            (reliableReference.confidence * 100).toStringAsFixed(0);
        print(
          ' Layout: dùng $seenName ($seenPercent%) làm vật mốc để tìm $objectName',
        );
      }
      _navigationStepCount++;
      if (mounted) {
        setState(() => _lastGuidance = scanGuidance);
      }
      await _speak(scanGuidance, restartListening: false);
      _scanRotationDegrees += _lastScanRotationDegrees;
      print(
        ' Quét ảnh: đã yêu cầu xoay tổng cộng $_scanRotationDegrees độ',
      );
      await Future.delayed(const Duration(seconds: 3));
      await _captureAndContinueNavigation();
      return;
    }
  }

  Future<void> _stopNavigationBecauseScanCompleted(String objectName) async {
    _isNavigationActive = false;
    _awaitingMovementConfirmation = false;
    _awaitingReadyForMovement = false;
    _hasAskedReadyForMovement = false;
    _movementGuidanceStarted = false;
    _hasAddedFinalTableApproachStep = false;
    _hasAddedFinalLaptopApproachStep = false;
    _pendingTargetDetection = null;
    _lastConfirmedTargetDetection = null;
    _lastLowConfidenceTargetDetection = null;
    _lastLowConfidenceImagePath = null;
    _lastSuggestedStepCount = null;
    _scanRotationDegrees = 0;
    _lastScanRotationDegrees = 0;
    if (mounted) {
      setState(() {
        _lastGuidance =
            'Không tìm thấy $objectName trong khu vực hiện tại.';
      });
    }
    await _speak(
      'Tôi vẫn chưa thấy rõ $objectName. Vui lòng xoay nhẹ sang phải khoảng 45 độ, rồi bấm mic để thử lại.',
      restartListening: false,
    );
  }

  Future<void> _startMovementToDetectedTarget(
    TFLiteDetectionResult found,
  ) async {
    if (_targetObject == null) return;
    _movementGuidanceStarted = true;
    final objectName = ObjectMappingService.getVietnameseName(_targetObject!);
    if (_isTargetCloseEnough(found)) {
      if (_targetObject == 'table' && !_hasAddedFinalTableApproachStep) {
        _hasAddedFinalTableApproachStep = true;
        final tableGuidance =
            '$objectName đã nằm rất rõ trong khung hình. '
            'Chặng cuối này hãy tiến nhẹ hai bước thật chậm, giữ tay phía trước để dò cạnh bàn. '
            'Sau hai bước thì dừng lại và đưa tay dò cạnh bàn thật chậm. Tôi sẽ thoát trạng thái tìm vật.';
        _isNavigationActive = false;
        _awaitingMovementConfirmation = false;
        _awaitingReadyForMovement = false;
        _hasAskedReadyForMovement = false;
        _movementGuidanceStarted = false;
        _hasAddedFinalTableApproachStep = false;
        _hasAddedFinalLaptopApproachStep = false;
        _pendingTargetDetection = null;
        _lastConfirmedTargetDetection = null;
        _lastLowConfidenceTargetDetection = null;
        _lastLowConfidenceImagePath = null;
        _scanRotationDegrees = 0;
        _lastScanRotationDegrees = 0;
        if (mounted) {
          setState(() {
            _targetObject = null;
            _navigationStepCount = 0;
            _lastSuggestedStepCount = null;
            _lastGuidance = tableGuidance;
            _recognizedText = 'Đã thoát trạng thái tìm vật';
          });
          _syncTargetMarkerToScene();
        }
        _addActivityLog(
          'Điều hướng',
          'Bàn có box lớn nhưng thực tế thường còn cách một đoạn, thêm chặng cuối 2 bước rồi kết thúc nhiệm vụ.',
        );
        await _speak(
          '$tableGuidance Nếu cần tìm vật khác, hãy bật mic để tôi hỗ trợ.',
          restartListening: false,
        );
        return;
      }

      if (_targetObject == 'laptop' && !_hasAddedFinalLaptopApproachStep) {
        _hasAddedFinalLaptopApproachStep = true;
        final laptopGuidance =
            '$objectName là vật nhỏ nên tôi sẽ căn chỉnh thêm một chặng cuối. '
            'Hãy tiến nhẹ một bước rất nhỏ, giữ tay phía trước. Nếu phía trước là mặt bàn hoặc kệ, hãy đưa tay thật chậm lên mặt phẳng đó để dò laptop. '
            'Sau khi làm xong, hãy nói: đã xong.';
        if (mounted) {
          setState(() => _lastGuidance = laptopGuidance);
        }
        _addActivityLog(
          'Điều hướng',
          'Laptop là vật nhỏ, thêm chặng cuối 1 bước rất nhỏ để căn chỉnh trước khi kết thúc.',
        );
        await _speakAndWaitForMovement(laptopGuidance);
        return;
      }

      final closeGuidance = _createCloseReachGuidance(found, objectName);
      _isNavigationActive = false;
      _awaitingMovementConfirmation = false;
      _awaitingReadyForMovement = false;
      _hasAskedReadyForMovement = false;
      _movementGuidanceStarted = false;
      _hasAddedFinalTableApproachStep = false;
      _hasAddedFinalLaptopApproachStep = false;
      _pendingTargetDetection = null;
      _lastConfirmedTargetDetection = null;
      _lastLowConfidenceTargetDetection = null;
      _lastLowConfidenceImagePath = null;
      _scanRotationDegrees = 0;
      _lastScanRotationDegrees = 0;
      if (mounted) {
        setState(() {
          _targetObject = null;
          _navigationStepCount = 0;
          _lastSuggestedStepCount = null;
          _lastGuidance = closeGuidance;
          _recognizedText = 'Đã thoát trạng thái tìm vật';
        });
        _syncTargetMarkerToScene();
      }
      await _speak(
        '$closeGuidance Tôi sẽ thoát trạng thái tìm vật. Nếu cần tìm vật khác, hãy bật mic để tôi hỗ trợ.',
        restartListening: false,
      );
      return;
    }

    _awaitingReadyForMovement = false;
    _pendingTargetDetection = null;
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

  bool _isUserFoundObjectCommand(String command) {
    final normalized = command.toLowerCase().trim();
    return normalized.contains('thấy vật') ||
        normalized.contains('thay vat') ||
        normalized.contains('đã thấy') ||
        normalized.contains('da thay') ||
        normalized.contains('tìm thấy') ||
        normalized.contains('tim thay') ||
        normalized.contains('đã tìm thấy') ||
        normalized.contains('da tim thay') ||
        normalized.contains('tìm được') ||
        normalized.contains('tim duoc') ||
        normalized.contains('đã tìm được') ||
        normalized.contains('da tim duoc') ||
        normalized.contains('thấy rồi') ||
        normalized.contains('thay roi') ||
        normalized.contains('chạm được') ||
        normalized.contains('cham duoc') ||
        normalized.contains('đã chạm') ||
        normalized.contains('da cham') ||
        normalized.contains('sờ thấy') ||
        normalized.contains('so thay') ||
        normalized.contains('đã sờ') ||
        normalized.contains('da so') ||
        normalized.contains('đụng được') ||
        normalized.contains('dung duoc') ||
        normalized.contains('cầm được') ||
        normalized.contains('cam duoc') ||
        normalized.contains('lấy được') ||
        normalized.contains('lay duoc') ||
        normalized.contains('cảm ơn') ||
        normalized.contains('cam on');
  }

  Future<void> _finishNavigationByUserFoundObject() async {
    final objectName = _targetObject == null
        ? 'vật'
        : ObjectMappingService.getVietnameseName(_targetObject!);
    _isNavigationActive = false;
    _awaitingMovementConfirmation = false;
    _awaitingReadyForMovement = false;
    _hasAskedReadyForMovement = false;
    _movementGuidanceStarted = false;
    _hasAddedFinalTableApproachStep = false;
    _hasAddedFinalLaptopApproachStep = false;
    _pendingTargetDetection = null;
    _lastConfirmedTargetDetection = null;
    _lastLowConfidenceTargetDetection = null;
    _lastLowConfidenceImagePath = null;
    _lastSuggestedStepCount = null;
    _scanRotationDegrees = 0;
    _lastScanRotationDegrees = 0;
    if (mounted) {
      setState(() {
        _targetObject = null;
        _navigationStepCount = 0;
        _lastGuidance = 'Người dùng đã tìm thấy $objectName.';
        _recognizedText = 'Đã thoát trạng thái tìm vật';
      });
      _syncTargetMarkerToScene();
    }
    _addActivityLog(
      'Người dùng',
      'Người dùng báo đã thấy hoặc chạm được $objectName, kết thúc nhiệm vụ.',
    );
    await _speak(
      'Oke, tôi đã hiểu. Nếu cần tìm vật gì khác, hãy bật mic để tôi hỗ trợ.',
      restartListening: false,
    );
  }

  bool _isReadyForMovementCommand(String command) {
    final normalized = command.toLowerCase().trim();
    return normalized.contains('sẵn sàng') ||
        normalized.contains('san sang') ||
        normalized.contains('bắt đầu') ||
        normalized.contains('bat dau') ||
        normalized.contains('đi được') ||
        normalized.contains('di duoc') ||
        normalized.contains('ok đi') ||
        normalized.contains('oke đi') ||
        normalized == 'ok' ||
        normalized == 'oke';
  }

  Future<void> _handleReadyForMovement(String command) async {
    if (!_awaitingReadyForMovement) return;

    if (!_isReadyForMovementCommand(command)) {
      await _speak(
        'Tôi chưa nghe rõ. Nếu bạn đã sẵn sàng di chuyển, hãy bật mic và nói: sẵn sàng.',
        restartListening: false,
      );
      return;
    }

    final detection = _pendingTargetDetection;
    if (detection == null) {
      _awaitingReadyForMovement = false;
      await _speak(
        'Tôi chưa có vị trí vật đủ rõ. Vui lòng đứng yên, tôi sẽ chụp lại.',
        restartListening: false,
      );
      await _captureAndContinueNavigation();
      return;
    }

    await _speak('Bắt đầu hướng dẫn di chuyển.', restartListening: false);
    await _startMovementToDetectedTarget(detection);
  }

  Future<void> _handleMovementConfirmation(String command) async {
    if (!_awaitingMovementConfirmation) return;

    if (_isUserFoundObjectCommand(command)) {
      print('Người dùng báo đã thấy/chạm được vật: "$command"');
      await _finishNavigationByUserFoundObject();
      return;
    }

    final isConfirmed = await _isMovementConfirmation(command);
    print('Xác nhận hoàn thành chặng: "$command" => $isConfirmed');
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
    print('TTS: bắt đầu đọc "$text"');
    _addActivityLog('Hệ thống', text);
    try {
      await _ttsApi.speak(text, lang: 'vi');
      print('TTS: đã gửi yêu cầu đọc thành công');
    } catch (e) {
      print('TTS: lỗi khi đọc: $e');
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
        print('STT: đang xử lý câu nói trước, chưa mở mic mới');
      }
      return;
    }

    if (!_isSpeechInitialized) {
      print('STT: chưa có phiên mic, khởi tạo mới như lúc mở app');
      await _initializeSpeechRecognizer();
    }

    print('STT: bắt đầu thu âm, hãy nói vào micro');

    final now = DateTime.now();
    if (_speechBlockedUntil != null && now.isBefore(_speechBlockedUntil!)) {
      final seconds = _speechBlockedUntil!.difference(now).inSeconds + 1;
      final message = 'STT đang bị Google giới hạn, vui lòng chờ $seconds giây rồi thử lại';
      print('STT: $message');
      if (mounted) {
        setState(() => _recognizedText = message);
      }
      return;
    }

    if (_lastListenStartTime != null &&
        now.difference(_lastListenStartTime!).inMilliseconds < 2500) {
      const message = 'Bấm mic hơi nhanh, vui lòng chờ 2 giây rồi thử lại';
      print('STT: $message');
      if (mounted) {
        setState(() => _recognizedText = message);
      }
      return;
    }

    if (!_isSpeechAvailable || !_speechToText.isAvailable) {
      const message =
          'STT chưa khả dụng: hãy bật/cài Google Speech Recognition trên thiết bị';
      print('STT: $message');
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

    print('STT: đang thu âm');
    try {
      if (!_isSpeechAvailable || !_speechToText.isAvailable) {
        print('STT: phiên SpeechRecognizer mới không khả dụng');
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
              print('STT: bỏ qua kết quả đến muộn sau khi đã dừng mic = "$lateCommand"');
            }
            return;
          }

          final command = result.recognizedWords.trim();
          if (command.isEmpty) return;

          print('STT: nghe được "$command" (kết quả cuối: ${result.finalResult})');
          _lastSpeechCandidate = command;
          if (mounted) {
            setState(() => _recognizedText = command);
          }

          if (result.finalResult && command.isNotEmpty && !_isHandlingSpeechResult) {
            _isHandlingSpeechResult = true;
            _isProcessingSpeechCommand = true;
            print('STT: kết quả cuối = $command');
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
          print('STT: âm lượng mic = ${level.toStringAsFixed(2)}');
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'vi_VN',
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      print('STT: lỗi khi thu âm: $e');
      _isListening = false;
      if (_activeTask == _CameraTask.listening) {
        _activeTask = _CameraTask.idle;
      }
      if (mounted) setState(() {});
    }
  }

  void _handleSpeechStatus(String status) {
    print('STT: trạng thái = $status');
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
      print('STT: $message');
      if (!isNoMatch && !isServerDisconnected) {
        print(
          ' STT: trên máy thật, hãy kiểm tra Google app/Speech Services và secure setting voice_recognition_service',
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
      print('STT: bỏ qua command không hợp lệ: "$normalizedCommand"');
      return;
    }

    _hasHandledCurrentSpeech = true;
    _addActivityLog('Người', normalizedCommand);

    if (_isEmergencyStopCommand(normalizedCommand)) {
      print('STT: lệnh dừng khẩn cấp');
      _stop();
      return;
    }

    if ((_isNavigationActive ||
            _awaitingReadyForMovement ||
            _awaitingMovementConfirmation) &&
        _isUserFoundObjectCommand(normalizedCommand)) {
      print('STT: người dùng báo đã tìm thấy/chạm được vật');
      await _finishNavigationByUserFoundObject();
      return;
    }

    if ((_isNavigationActive ||
            _awaitingReadyForMovement ||
            _awaitingMovementConfirmation) &&
        _looksLikeNewSearchCommand(normalizedCommand)) {
      print('STT: phát hiện người dùng đổi vật cần tìm');
      _resetNavigationStateForNewSearch();
      final canSearch = await _processVoiceCommand(normalizedCommand);
      if (canSearch) {
        await _runAutomaticSearch();
      }
      return;
    }

    if (_awaitingReadyForMovement) {
      await _handleReadyForMovement(normalizedCommand);
      return;
    }

    if (_awaitingMovementConfirmation) {
      await _handleMovementConfirmation(normalizedCommand);
      return;
    }

    final canSearch = await _processVoiceCommand(normalizedCommand);
    if (canSearch) {
      await _runAutomaticSearch();
    }
  }

  bool _isEmergencyStopCommand(String command) {
    final normalized = command.toLowerCase();
    return normalized.contains('dừng') ||
        normalized.contains('dung') ||
        normalized.contains('hủy') ||
        normalized.contains('huy') ||
        normalized.contains('thoát') ||
        normalized.contains('thoat');
  }

  bool _looksLikeNewSearchCommand(String command) {
    final normalized = command.toLowerCase();
    return normalized.contains('tìm') ||
        normalized.contains('tim') ||
        normalized.contains('kiếm') ||
        normalized.contains('kiem');
  }

  void _resetNavigationStateForNewSearch() {
    _isNavigationActive = false;
    _awaitingMovementConfirmation = false;
    _awaitingReadyForMovement = false;
    _hasAskedReadyForMovement = false;
    _movementGuidanceStarted = false;
    _hasAddedFinalTableApproachStep = false;
    _hasAddedFinalLaptopApproachStep = false;
    _pendingTargetDetection = null;
    _lastConfirmedTargetDetection = null;
    _lastLowConfidenceTargetDetection = null;
    _lastLowConfidenceImagePath = null;
    _navigationStepCount = 0;
    _lastSuggestedStepCount = null;
    _scanRotationDegrees = 0;
    _lastScanRotationDegrees = 0;
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
    print('STT: bấm nút mic');
    if (_isProcessingSpeechCommand) {
      print('STT: câu nói trước đang được xử lý, vui lòng chờ app phản hồi xong');
      return;
    }

    if (_isListening) {
      _playMicTapFeedback(isStarting: false);
      _addActivityLog('Mic', 'Đã tắt mic.');
      _stopListening();
    } else {
      _playMicTapFeedback(isStarting: true);
      _addActivityLog('Mic', 'Đã bật mic, hãy nói vào micro.');
      _startContinuousListening();
    }
  }

  void _playMicTapFeedback({required bool isStarting}) {
    unawaited(_playMicTone(isStarting: isStarting));
    if (isStarting) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _playMicTone({required bool isStarting}) async {
    try {
      await _audioFeedbackChannel.invokeMethod<void>(
        'playMicTone',
        {'isStarting': isStarting},
      );
    } catch (_) {
      SystemSound.play(
        isStarting ? SystemSoundType.click : SystemSoundType.alert,
      );
    }
  }

  Future<void> _stopListening() async {
    print('STT: dừng thu âm');
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
      print('STT: xử lý text khi người dùng tắt mic = "$candidate"');
      _isProcessingSpeechCommand = true;
      try {
        await _handleRecognizedCommand(candidate);
      } finally {
        _isProcessingSpeechCommand = false;
      }
    }
  }

  Future<void> _stopListeningQuiet() async {
    print('STT: dừng thu âm nội bộ');
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
    print('STT: xử lý text được gửi: "$command"');

    if (_isEmergencyStopCommand(command)) {
      print('STT: phát hiện lệnh dừng/thoát');
      _isNavigationActive = false;
      _awaitingMovementConfirmation = false;
      _awaitingReadyForMovement = false;
      _hasAskedReadyForMovement = false;
      _movementGuidanceStarted = false;
      _pendingTargetDetection = null;
      _lastSuggestedStepCount = null;
      _scanRotationDegrees = 0;
      _lastScanRotationDegrees = 0;
      _stop();
      return false;
    }

    final label = await _parseTargetObject(command);
    print('STT: label sau khi parse = $label');

    if (label != null) {
      final name = ObjectMappingService.getVietnameseName(label);
      print('STT: đã chọn mục tiêu cần tìm = $name');
      setState(() => _targetObject = label);
      _syncTargetMarkerToScene();
      await _speak(
        'Tôi đã hiểu. Bạn đang muốn tìm $name.',
        restartListening: false,
      );
      return true;
    }

    print('STT: không hiểu nội dung text');
    await _speak(
      'Tôi chưa hiểu bạn muốn tìm vật gì. Vui lòng bấm mic và nói lại, ví dụ: tìm cái ghế, tìm cái bàn, hoặc tìm tủ lạnh.',
      restartListening: false,
    );
    return false;
  }
  Future<String?> _parseTargetObject(String command) async {
    final aiLabel = await _confirmationIntentService.classifyTargetObject(command);
    if (aiLabel != null) {
      return aiLabel;
    }

    print('OpenRouter: fallback sang mapping từ khóa local');
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

  void _stop() {
    _isNavigationActive = false;
    _awaitingMovementConfirmation = false;
    _awaitingReadyForMovement = false;
    _hasAskedReadyForMovement = false;
    _movementGuidanceStarted = false;
    _hasAddedFinalTableApproachStep = false;
    _hasAddedFinalLaptopApproachStep = false;
    _pendingTargetDetection = null;
    _lastConfirmedTargetDetection = null;
    _lastLowConfidenceTargetDetection = null;
    _lastLowConfidenceImagePath = null;
    _lastSuggestedStepCount = null;
    _scanRotationDegrees = 0;
    _lastScanRotationDegrees = 0;
    _speak('Đã dừng ứng dụng');
    Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraInitialized) return;
    if (state == AppLifecycleState.paused) {
      print('App: tạm rời màn hình, giữ trạng thái camera/TTS');
      if (_isTtsInitialized) {
        _ttsApi.stop();
      }
      if (_activeTask == _CameraTask.speaking) {
        _activeTask = _CameraTask.idle;
      }
    } else if (state == AppLifecycleState.resumed) {
      print('App: quay lại màn hình, kiểm tra lại TTS');
      if (_isTtsInitialized) {
        _ttsApi = TTSApiService();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hardwareKeySubscription?.cancel();
    _activityLogController.dispose();
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

    final showLayoutMap = _activeRoomLayout != null;

    return HeroMode(
      enabled: false,
      child: Scaffold(
        key: _cameraScaffoldKey,
        drawerEnableOpenDragGesture: true,
        drawer: _buildDetectionDrawer(),
        backgroundColor: showLayoutMap ? const Color(0xFFE5E7EB) : Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: showLayoutMap
                  ? _buildLayoutNavigationView()
                  : _buildCameraOrImagePreview(),
            ),
            if (showLayoutMap)
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.01,
                    child: CameraPreview(_cameraController),
                  ),
                ),
              ),
            if (!showLayoutMap && _lastDetections.isNotEmpty)
              CustomPaint(
                painter: DetectionPainter(
                  _lastDetections,
                  _targetObject,
                  sourceSize: _lastImageSize,
                ),
                size: Size.infinite,
              ),
            Positioned(
              left: 0,
              top: 96,
              child: _buildDetectionDrawerHandle(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomTestBar(),
      ),
    );
  }

  Widget _buildLayoutNavigationView() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
          child: Column(
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _navigationSceneController == null
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
                            children: [
                              WebViewWidget(controller: _navigationSceneController!),
                              if (!_isNavigationSceneReady)
                                Container(
                                  color: const Color(0xFFD7D7D7),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                flex: 3,
                child: _buildActivityLogPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLogPanel() {
    final logs = _activityLogs.isEmpty
        ? const ['Hệ thống: Ứng dụng hỗ trợ người di chuyển đang hoạt động.']
        : _activityLogs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0F2F1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.article_outlined, color: Color(0xFF2AAEB3), size: 18),
              SizedBox(width: 8),
              Text(
                'Nhật ký thao tác',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: _activityLogController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _activityLogController,
                padding: const EdgeInsets.only(right: 8),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final line = logs[index];
                  final isUser = line.startsWith('Người:');
                  final isSystem = line.startsWith('Hệ thống:');
                  final isMic = line.startsWith('Mic:');
                  final color = isUser
                      ? const Color(0xFF047857)
                      : isSystem
                          ? const Color(0xFF111827)
                          : isMic
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF475569);
                  return Text(
                    line,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight:
                          isUser || isSystem ? FontWeight.w700 : FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionDrawerHandle() {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _cameraScaffoldKey.currentState?.openDrawer(),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
          child: Container(
            width: 44,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.70),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.image_search_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionDrawer() {
    final imagePath = _lastAnalyzedImagePath ?? _lastCapturedImagePath;

    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F7F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.image_search_outlined,
                      color: Color(0xFF2AAEB3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ảnh detect',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (imagePath == null)
                Container(
                  height: 190,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Chưa có ảnh detect',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(imagePath),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _apiStatus,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Vật phát hiện',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _lastDetections.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa phát hiện vật nào.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _lastDetections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final detection = _lastDetections[index];
                          final name = ObjectMappingService.getVietnameseName(detection.label);
                          final confidence = (detection.confidence * 100).toStringAsFixed(0);
                          final isTarget = detection.label == _targetObject;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isTarget
                                  ? const Color(0xFFE0F7F6)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTarget
                                    ? const Color(0xFF2AAEB3)
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isTarget ? Icons.flag_rounded : Icons.check_circle_outline,
                                  color: isTarget
                                      ? const Color(0xFF2AAEB3)
                                      : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$confidence%',
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: const Border(
            top: BorderSide(color: Color(0xFFE0F2F1)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, -6),
            ),
          ],
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
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
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

class RoomNavigationMapPainter extends CustomPainter {
  RoomNavigationMapPainter({
    required this.roomWidth,
    required this.roomDepth,
    required this.objects,
    required this.userPosition,
    required this.userHeadingDegrees,
    required this.targetObject,
    required this.referenceObject,
    required this.objectNameBuilder,
  });

  final double roomWidth;
  final double roomDepth;
  final List<Map<String, dynamic>> objects;
  final Offset? userPosition;
  final double userHeadingDegrees;
  final String? targetObject;
  final String? referenceObject;
  final String Function(String label) objectNameBuilder;

  double _readDouble(Map<String, dynamic> object, String key, [double fallback = 0]) {
    final value = object[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final safeWidth = roomWidth <= 0 ? 5.0 : roomWidth;
    final safeDepth = roomDepth <= 0 ? 3.0 : roomDepth;
    const padding = 26.0;
    final scale = math.min(
      (size.width - padding * 2) / safeWidth,
      (size.height - padding * 2) / safeDepth,
    );
    final roomSize = Size(safeWidth * scale, safeDepth * scale);
    final roomRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: roomSize.width,
      height: roomSize.height,
    );

    _drawBackground(canvas, size);
    _drawRoom(canvas, roomRect, scale);
    _drawObjects(canvas, roomRect, scale);
    _drawUserAndRoute(canvas, roomRect, scale);
    _drawLegend(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawRoom(Canvas canvas, Rect roomRect, double scale) {
    final floorPaint = Paint()..color = const Color(0xFFD4A75D);
    final wallPaint = Paint()
      ..color = const Color(0xFF94A3B8).withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final gridPaint = Paint()
      ..color = const Color(0xFF8B5E34).withOpacity(0.18)
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(roomRect, const Radius.circular(8)),
      floorPaint,
    );

    for (double x = roomRect.left; x <= roomRect.right; x += 0.5 * scale) {
      canvas.drawLine(Offset(x, roomRect.top), Offset(x, roomRect.bottom), gridPaint);
    }
    for (double y = roomRect.top; y <= roomRect.bottom; y += 0.5 * scale) {
      canvas.drawLine(Offset(roomRect.left, y), Offset(roomRect.right, y), gridPaint);
    }

    canvas.drawRect(roomRect, wallPaint);
    canvas.drawRect(roomRect, borderPaint);
  }

  void _drawObjects(Canvas canvas, Rect roomRect, double scale) {
    for (final object in objects) {
      final className = (object['ClassName'] ?? object['ObjectName'] ?? '').toString();
      if (className.isEmpty) continue;

      final position = Offset(
        _readDouble(object, 'PosX'),
        _readDouble(object, 'PosZ'),
      );
      final center = _toCanvasPoint(position, roomRect, scale);
      final objectWidth = math.max(_readDouble(object, 'Width', 0.45), 0.28) * scale;
      final objectDepth = math.max(_readDouble(object, 'Depth', 0.45), 0.28) * scale;
      final rotation = _readDouble(object, 'RotationY');
      final isTarget = className == targetObject;
      final isReference = className == referenceObject;

      final fillColor = isTarget
          ? const Color(0xFF22C55E)
          : isReference
              ? const Color(0xFFF97316)
              : const Color(0xFF64748B);
      final strokeColor = isTarget
          ? const Color(0xFF166534)
          : isReference
              ? const Color(0xFF9A3412)
              : const Color(0xFF334155);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: objectWidth,
        height: objectDepth,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = fillColor.withOpacity(isTarget || isReference ? 0.92 : 0.72),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isTarget || isReference ? 3 : 1.4,
      );
      canvas.restore();

      _drawText(
        canvas,
        objectNameBuilder(className),
        center + Offset(-objectWidth / 2, -objectDepth / 2 - 16),
        color: const Color(0xFF0F172A),
        fontSize: isTarget ? 12 : 10,
        fontWeight: isTarget ? FontWeight.w800 : FontWeight.w600,
      );
    }
  }

  void _drawUserAndRoute(Canvas canvas, Rect roomRect, double scale) {
    final user = userPosition;
    if (user == null) {
      _drawText(
        canvas,
        'Chưa xác định vị trí',
        Offset(roomRect.center.dx - 70, roomRect.center.dy - 10),
        color: const Color(0xFF475569),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      );
      return;
    }

    final userPoint = _toCanvasPoint(user, roomRect, scale);
    final target = _findTargetObject();
    if (target != null) {
      final targetPoint = _toCanvasPoint(
        Offset(_readDouble(target, 'PosX'), _readDouble(target, 'PosZ')),
        roomRect,
        scale,
      );
      _drawDashedLine(
        canvas,
        userPoint,
        targetPoint,
        Paint()
          ..color = const Color(0xFF2563EB).withOpacity(0.65)
          ..strokeWidth = 2,
      );
    }

    final headingRadians = userHeadingDegrees * math.pi / 180;
    final headingVector = Offset(math.sin(headingRadians), math.cos(headingRadians));
    final arrowEnd = userPoint + headingVector * 34;
    final userPaint = Paint()..color = const Color(0xFF2563EB);
    final glowPaint = Paint()..color = const Color(0xFF60A5FA).withOpacity(0.24);
    canvas.drawCircle(userPoint, 22, glowPaint);
    canvas.drawCircle(userPoint, 11, userPaint);
    canvas.drawCircle(
      userPoint,
      11,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      userPoint,
      arrowEnd,
      Paint()
        ..color = const Color(0xFF1D4ED8)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(arrowEnd, 4, Paint()..color = const Color(0xFF1D4ED8));
    _drawText(
      canvas,
      'Bạn',
      userPoint + const Offset(14, -28),
      color: const Color(0xFF1D4ED8),
      fontSize: 13,
      fontWeight: FontWeight.w900,
    );
  }

  void _drawLegend(Canvas canvas, Size size) {
    final legendTop = size.height - 38;
    final items = [
      (const Color(0xFF2563EB), 'Bạn'),
      (const Color(0xFF22C55E), 'Mục tiêu'),
      (const Color(0xFFF97316), 'Vật mốc'),
    ];
    double left = 16;
    for (final item in items) {
      canvas.drawCircle(Offset(left + 7, legendTop + 9), 6, Paint()..color = item.$1);
      _drawText(
        canvas,
        item.$2,
        Offset(left + 18, legendTop),
        color: const Color(0xFF334155),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      );
      left += 82;
    }
  }

  Map<String, dynamic>? _findTargetObject() {
    if (targetObject == null) return null;
    for (final object in objects) {
      if ((object['ClassName'] ?? '').toString() == targetObject) {
        return object;
      }
    }
    return null;
  }

  Offset _toCanvasPoint(Offset roomPoint, Rect roomRect, double scale) {
    return Offset(
      roomRect.center.dx + roomPoint.dx * scale,
      roomRect.center.dy + roomPoint.dy * scale,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;
    final direction = delta / distance;
    const dash = 10.0;
    const gap = 7.0;
    double current = 0;
    while (current < distance) {
      final segmentStart = start + direction * current;
      final segmentEnd = start + direction * math.min(current + dash, distance);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      current += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    textPainter.layout(maxWidth: 90);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant RoomNavigationMapPainter oldDelegate) => true;
}


