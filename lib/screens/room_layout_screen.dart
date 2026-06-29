import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/user_model.dart';
import '../services/room_api_service.dart';

const Color _primaryColor = Color(0xFF58CFC6);
const Color _accentColor = Color(0xFF4EAFC0);
const Color _backgroundColor = Color(0xFFF5FBFA);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF111827);
const Color _textSecondary = Color(0xFF6B7280);

class RoomLayoutScreen extends StatefulWidget {
  const RoomLayoutScreen({
    super.key,
    required this.user,
    this.initialRoom,
  });

  final User user;
  final Map<String, dynamic>? initialRoom;

  @override
  State<RoomLayoutScreen> createState() => _RoomLayoutScreenState();
}

class _RoomLayoutScreenState extends State<RoomLayoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RoomApiService _roomApiService = RoomApiService();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _widthController =
      TextEditingController(text: '5000');
  final TextEditingController _depthController =
      TextEditingController(text: '3000');
  final TextEditingController _heightController =
      TextEditingController(text: '2700');

  bool _roomCreated = false;
  bool _loadingScene = false;
  bool _savingLayout = false;
  String? _savedRoomId;
  WebViewController? _sceneController;

  static const List<_RoomObjectDefinition> _objects = [
    _RoomObjectDefinition('bed', 'Giường', 'assets/model/bed.glb', Icons.bed),
    _RoomObjectDefinition('sofa', 'Sofa', 'assets/model/sofa.glb', Icons.weekend),
    _RoomObjectDefinition('chair', 'Ghế', 'assets/model/chair.glb', Icons.event_seat),
    _RoomObjectDefinition('table', 'Bàn', 'assets/model/table.glb', Icons.table_bar),
    _RoomObjectDefinition(
      'wardrobe',
      'Tủ',
      'assets/model/wardrobe.glb',
      Icons.inventory_2,
    ),
    _RoomObjectDefinition(
      'refrigerator',
      'Tủ lạnh',
      'assets/model/refrigerator.glb',
      Icons.kitchen,
    ),
    _RoomObjectDefinition('tv', 'TV', 'assets/model/tv.glb', Icons.tv),
    _RoomObjectDefinition(
      'door',
      'Cửa',
      'assets/model/door.glb',
      Icons.door_front_door,
    ),
    _RoomObjectDefinition(
      'window',
      'Cửa sổ',
      'assets/model/window.glb',
      Icons.crop_landscape,
    ),
    _RoomObjectDefinition('fan', 'Quạt', 'assets/model/fan.glb', Icons.toys),
    _RoomObjectDefinition('laptop', 'Laptop', 'assets/model/laptop.glb', Icons.laptop),
    _RoomObjectDefinition(
      'washing_machine',
      'Máy giặt',
      'assets/model/washing_machine.glb',
      Icons.local_laundry_service,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final room = widget.initialRoom;
    if (room != null) {
      _savedRoomId = (room['_id'] ?? '').toString();
      _roomNameController.text = (room['RoomName'] ?? 'Phòng 3D').toString();
      _widthController.text =
          ((double.tryParse('${room['Width']}') ?? 5) * 1000).round().toString();
      _depthController.text =
          ((double.tryParse('${room['Depth']}') ?? 3) * 1000).round().toString();
      _heightController.text =
          ((double.tryParse('${room['Height']}') ?? 2.7) * 1000).round().toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _createRoom(roomData: room, keepSavedRoomId: true);
      });
    }
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double _parseDimension(String value, double fallback) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
  }

  String? _validateDimension(String? value) {
    final double? parsed =
        double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Nhập số hợp lệ';
    }
    if (parsed < 500) {
      return 'Tối thiểu 500 mm';
    }
    if (parsed > 50000) {
      return 'Tối đa 50000 mm';
    }
    return null;
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Không được để trống';
    }
    return null;
  }

  Future<void> _createRoom({
    Map<String, dynamic>? roomData,
    bool keepSavedRoomId = false,
  }) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loadingScene = true;
      _roomCreated = true;
      if (!keepSavedRoomId) {
        _savedRoomId = null;
      }
    });

    final double widthM = _parseDimension(_widthController.text, 5000) / 1000;
    final double depthM = _parseDimension(_depthController.text, 3000) / 1000;
    final double heightM = _parseDimension(_heightController.text, 2700) / 1000;
    final Map<String, String> modelSources = await _loadModelSources();

    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFD7D7D7));

    await controller.loadHtmlString(
      _buildSceneHtml(
        widthM: widthM,
        depthM: depthM,
        heightM: heightM,
        modelSources: modelSources,
        savedObjects: roomData?['Objects'] is List
            ? List<Map<String, dynamic>>.from(
                (roomData!['Objects'] as List).whereType<Map>().map(
                      (object) => Map<String, dynamic>.from(object),
                    ),
              )
            : const [],
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _sceneController = controller;
      _loadingScene = false;
    });
  }

  Future<Map<String, String>> _loadModelSources() async {
    final Map<String, String> sources = {};
    for (final _RoomObjectDefinition object in _objects) {
      final ByteData data = await rootBundle.load(object.assetPath);
      sources[object.id] =
          'data:model/gltf-binary;base64,${base64Encode(data.buffer.asUint8List())}';
    }
    return sources;
  }

  Future<void> _runSceneCommand(String command) async {
    await _sceneController?.runJavaScript(command);
  }

  Future<String?> _askRoomName() async {
    String draftName = _roomNameController.text.trim();

    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt tên phòng'),
        content: TextFormField(
          initialValue: draftName,
          autofocus: true,
          onChanged: (value) => draftName = value.trim(),
          decoration: const InputDecoration(
            labelText: 'Tên phòng',
            hintText: 'Ví dụ: Phòng ngủ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final value = draftName.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      _roomNameController.text = name;
    }
    return name;
  }

  Future<void> _saveRoomLayout() async {
    if (_sceneController == null || _savingLayout) {
      return;
    }
    if (widget.user.id.isEmpty) {
      _showMessage('Thiếu thông tin người dùng');
      return;
    }

    final bool isCreatingRoom = _savedRoomId == null;
    final String? roomName = isCreatingRoom
        ? await _askRoomName()
        : _roomNameController.text.trim();
    if (roomName == null || roomName.isEmpty) {
      return;
    }

    setState(() => _savingLayout = true);

    try {
      final Object? rawResult = await _sceneController!.runJavaScriptReturningResult(
        'JSON.stringify(exportRoomLayout());',
      );
      final String encoded = rawResult.toString();
      final String jsonText = encoded.startsWith('"')
          ? jsonDecode(encoded) as String
          : encoded;
      final Map<String, dynamic> sceneData =
          jsonDecode(jsonText) as Map<String, dynamic>;

      final Map<String, dynamic> payload = {
        'RoomName': roomName,
        'Width': sceneData['Width'],
        'Depth': sceneData['Depth'],
        'Height': sceneData['Height'],
        'RoomType': 'custom_3d',
        'Unit': 'm',
        'Objects': sceneData['Objects'] ?? [],
      };
      final Map<String, dynamic> response = isCreatingRoom
          ? await _roomApiService.createRoom(userId: widget.user.id, payload: payload)
          : await _roomApiService.updateRoom(
              roomId: _savedRoomId!,
              payload: payload,
            );

      final dynamic data = response['data'];
      if (data is Map && data['_id'] != null) {
        _savedRoomId = data['_id'].toString();
      }

      _showMessage(isCreatingRoom
          ? 'Đã lưu phòng thành công'
          : 'Đã cập nhật phòng thành công');
    } catch (error) {
      _showMessage('Lỗi lưu phòng: $error');
    } finally {
      if (mounted) {
        setState(() => _savingLayout = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetRoom() {
    setState(() {
      _roomCreated = false;
      _loadingScene = false;
      _savingLayout = false;
      _savedRoomId = null;
      _sceneController = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _roomCreated ? const Color(0xFFD7D7D7) : _primaryColor,
      appBar: AppBar(
        title: Text(_roomCreated ? 'Phòng 3D' : 'Tạo phòng'),
        backgroundColor: _roomCreated ? Colors.white : _primaryColor,
        foregroundColor: _roomCreated ? _textPrimary : Colors.white,
        elevation: 0,
        actions: [
          if (_roomCreated)
            Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                tooltip: 'Lưu phòng',
                onPressed: _savingLayout ? null : _saveRoomLayout,
                icon: _savingLayout
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
              ),
            ),
        ],
      ),
      body: _roomCreated ? _buildSceneView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return Stack(
      children: [
        const _RoomSetupBackground(),
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Thiết lập phòng 3D',
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Nhập kích thước phòng, sau đó thêm vật vào layout 3D để lưu vị trí.',
                                    style: TextStyle(
                                      color: _textSecondary.withOpacity(0.92),
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Icon(
                                Icons.view_in_ar_rounded,
                                color: _accentColor,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _DimensionField(
                          controller: _widthController,
                          label: 'Chiều dài (W), mm',
                          icon: Icons.swap_horiz_rounded,
                          validator: _validateDimension,
                        ),
                        const SizedBox(height: 16),
                        _DimensionField(
                          controller: _depthController,
                          label: 'Chiều rộng (D), mm',
                          icon: Icons.open_in_full_rounded,
                          validator: _validateDimension,
                        ),
                        const SizedBox(height: 16),
                        _DimensionField(
                          controller: _heightController,
                          label: 'Chiều cao (H), mm',
                          icon: Icons.height_rounded,
                          validator: _validateDimension,
                        ),
                        const SizedBox(height: 26),
                        ElevatedButton(
                          onPressed: _loadingScene ? null : _createRoom,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: _accentColor,
                            disabledBackgroundColor: _accentColor.withOpacity(0.45),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(58),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _loadingScene
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Text(
                                  'Tạo phòng',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            _widthController.text = '5000';
                            _depthController.text = '3000';
                            _heightController.text = '2700';
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textPrimary,
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Đặt lại kích thước mặc định',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _RoomSetupTip(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildSceneView() {
    return Stack(
      children: [
        Positioned.fill(
          child: _sceneController == null
              ? const ColoredBox(color: Color(0xFFD7D7D7))
              : WebViewWidget(controller: _sceneController!),
        ),
        if (_loadingScene)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x99D7D7D7),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              _SceneButton(
                icon: Icons.remove,
                label: 'Thu nhỏ vật',
                onTap: () => _runSceneCommand('scaleSelected(0.9);'),
              ),
              const SizedBox(height: 8),
              _SceneButton(
                icon: Icons.add,
                label: 'Phóng to vật',
                onTap: () => _runSceneCommand('scaleSelected(1.1);'),
              ),
              const SizedBox(height: 8),
              _SceneButton(
                icon: Icons.rotate_90_degrees_cw,
                label: 'Xoay phải 90°',
                onTap: () => _runSceneCommand('rotateSelected(90);'),
              ),
              const SizedBox(height: 8),
              _SceneButton(
                icon: Icons.delete_outline,
                label: 'Xóa vật',
                danger: true,
                onTap: () => _runSceneCommand('deleteSelected();'),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _ObjectLibrary(
            objects: _objects,
            onAdd: (object) => _runSceneCommand('addModel("${object.id}");'),
          ),
        ),
      ],
    );
  }

  String _buildSceneHtml({
    required double widthM,
    required double depthM,
    required double heightM,
    required Map<String, String> modelSources,
    List<Map<String, dynamic>> savedObjects = const [],
  }) {
    final String sourceJson = jsonEncode(modelSources);
    final String savedObjectsJson = jsonEncode(savedObjects);
    final String labelJson = jsonEncode({
      for (final _RoomObjectDefinition object in _objects) object.id: object.label,
    });
    final String assetPathJson = jsonEncode({
      for (final _RoomObjectDefinition object in _objects)
        object.id: object.assetPath,
    });
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #d7d7d7; }
    canvas { touch-action: none; }
</style>
</head>
<body>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/build/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/TransformControls.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script>
const ROOM = { width: $widthM, depth: $depthM, height: $heightM };
const MODEL_SOURCES = $sourceJson;
const SAVED_OBJECTS = $savedObjectsJson;
const OBJECT_LABELS = $labelJson;
const OBJECT_ASSET_PATHS = $assetPathJson;
const OBJECT_SIZE = {
  bed: 1.55, sofa: 1.25, chair: .7, table: 1.0, wardrobe: 1.15,
  refrigerator: 1.2, tv: .9, door: 1.9, window: 1.1, fan: .8,
  laptop: .45, washing_machine: .85
};
const VERTICAL_TYPES = new Set(['window', 'tv', 'laptop']);
const WALL_TYPES = new Set(['door', 'window']);

let scene, camera, renderer, orbitControls, transformControls, loader;
let selected = null;
const objects = [];

init();
animate();

function init() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0xd7d7d7);

  camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.01, 100);
  camera.position.set(ROOM.width * .55, ROOM.height * .85, ROOM.depth * 1.15);

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(window.devicePixelRatio || 1);
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.outputEncoding = THREE.sRGBEncoding;
  document.body.appendChild(renderer.domElement);

  orbitControls = new THREE.OrbitControls(camera, renderer.domElement);
  orbitControls.target.set(0, ROOM.height * .38, 0);
  orbitControls.enableDamping = true;
  orbitControls.dampingFactor = .08;
  orbitControls.minDistance = Math.max(ROOM.width, ROOM.depth) * .45;
  orbitControls.maxDistance = Math.max(ROOM.width, ROOM.depth) * 2.8;

  transformControls = new THREE.TransformControls(camera, renderer.domElement);
  transformControls.setSize(.78);
  transformControls.showY = false;
  transformControls.addEventListener('dragging-changed', event => {
    orbitControls.enabled = !event.value;
  });
  transformControls.addEventListener('objectChange', keepSelectedInsideRoom);
  scene.add(transformControls);

  loader = new THREE.GLTFLoader();
  addLights();
  addRoom();
  resetCamera();
  loadSavedObjects();

  renderer.domElement.addEventListener('pointerdown', onPointerDown, false);
  renderer.domElement.addEventListener('pointermove', onPointerMove, false);
  renderer.domElement.addEventListener('pointerup', onPointerUp, false);
  renderer.domElement.addEventListener('pointercancel', onPointerUp, false);
  window.addEventListener('resize', onResize);
}

function addLights() {
  scene.add(new THREE.HemisphereLight(0xffffff, 0xb8b8b8, 1.2));
  const light = new THREE.DirectionalLight(0xffffff, 1.0);
  light.position.set(3, 5, 4);
  scene.add(light);
}

function addRoom() {
  const floorTexture = createWoodTexture();
  floorTexture.wrapS = THREE.RepeatWrapping;
  floorTexture.wrapT = THREE.RepeatWrapping;
  floorTexture.repeat.set(Math.max(2, ROOM.width), Math.max(2, ROOM.depth));

  const floor = new THREE.Mesh(
    new THREE.PlaneGeometry(ROOM.width, ROOM.depth),
    new THREE.MeshStandardMaterial({ map: floorTexture, roughness: .85 })
  );
  floor.rotation.x = -Math.PI / 2;
  floor.name = 'floor';
  scene.add(floor);

  const wallMaterial = new THREE.MeshStandardMaterial({
    color: 0xdde7ea,
    roughness: .9,
    transparent: true,
    opacity: .28,
    side: THREE.DoubleSide
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

  const edgeGeometry = new THREE.EdgesGeometry(new THREE.BoxGeometry(ROOM.width, ROOM.height, ROOM.depth));
  const edges = new THREE.LineSegments(
    edgeGeometry,
    new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: .82 })
  );
  edges.position.y = ROOM.height / 2;
  scene.add(edges);
}

function createWoodTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#8b5a2b';
  ctx.fillRect(0, 0, 512, 512);
  ctx.strokeStyle = 'rgba(48,29,12,.55)';
  ctx.lineWidth = 3;
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
  ctx.strokeStyle = 'rgba(215,170,95,.34)';
  for (let y = 15; y < 512; y += 38) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.bezierCurveTo(150, y + 22, 330, y - 22, 512, y + 8);
    ctx.stroke();
  }
  return new THREE.CanvasTexture(canvas);
}

function addModel(type, saved = null) {
  const source = MODEL_SOURCES[type];
  if (!source) return;

  loader.load(source, gltf => {
    const model = gltf.scene;
    model.userData.type = type;
    model.traverse(child => {
      if (child.isMesh) {
        child.castShadow = true;
        child.receiveShadow = true;
        child.material.side = THREE.DoubleSide;
      }
    });

    normalizeModel(model, OBJECT_SIZE[type] || 1);
    centerModelGeometry(model);

    const root = new THREE.Group();
    root.userData.type = type;
    root.userData.objectId = saved && saved.ObjectId ? saved.ObjectId : null;
    root.add(model);
    if (saved) {
      root.position.set(Number(saved.PosX || 0), Number(saved.PosY || 0), Number(saved.PosZ || 0));
      root.rotation.set(Number(saved.RotationX || 0), Number(saved.RotationY || 0), Number(saved.RotationZ || 0));
      const savedScale = Number(saved.Scale || 1);
      root.scale.set(savedScale, savedScale, savedScale);
      keepObjectInsideRoom(root);
    } else {
      root.position.set(0, 0, 0);
      keepOnFloor(root);
      keepObjectInsideRoom(root);
    }

    objects.push(root);
    scene.add(root);
    selectObject(root);
  });
}

function loadSavedObjects() {
  if (!Array.isArray(SAVED_OBJECTS) || !SAVED_OBJECTS.length) return;
  SAVED_OBJECTS.forEach(saved => {
    const type = saved.ClassName || saved.ObjectName;
    if (type) addModel(type, saved);
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

function keepOnFloor(model) {
  const box = new THREE.Box3().setFromObject(model);
  model.position.y -= box.min.y;
}

function keepSelectedInsideRoom() {
  if (!selected) return;
  keepObjectInsideRoom(selected);
}

function keepObjectInsideRoom(object) {
  if (!object) return;
  const halfW = ROOM.width / 2;
  const halfD = ROOM.depth / 2;
  const box = new THREE.Box3().setFromObject(object);
  if (box.min.x < -halfW) {
    object.position.x += -halfW - box.min.x;
  }
  if (box.max.x > halfW) {
    object.position.x -= box.max.x - halfW;
  }
  if (box.min.z < -halfD) {
    object.position.z += -halfD - box.min.z;
  }
  if (box.max.z > halfD) {
    object.position.z -= box.max.z - halfD;
  }
  if (!canMoveVertical(object)) {
    keepOnFloor(object);
  } else {
    clampVertical(object);
  }
  if (mustAttachToWall(object)) {
    attachObjectToNearestWall(object);
  }
}

function mustAttachToWall(object) {
  return object && WALL_TYPES.has(object.userData.type);
}

function attachObjectToNearestWall(object) {
  const halfW = ROOM.width / 2;
  const halfD = ROOM.depth / 2;
  const distances = [
    { wall: 'left', value: Math.abs(object.position.x + halfW) },
    { wall: 'right', value: Math.abs(halfW - object.position.x) },
    { wall: 'back', value: Math.abs(object.position.z + halfD) },
    { wall: 'front', value: Math.abs(halfD - object.position.z) },
  ].sort((a, b) => a.value - b.value);

  const wall = distances[0].wall;
  const boxBefore = new THREE.Box3().setFromObject(object);

  if (wall === 'left') {
    object.rotation.y = Math.PI / 2;
    object.position.x += -halfW - boxBefore.min.x;
  } else if (wall === 'right') {
    object.rotation.y = -Math.PI / 2;
    object.position.x -= boxBefore.max.x - halfW;
  } else if (wall === 'back') {
    object.rotation.y = 0;
    object.position.z += -halfD - boxBefore.min.z;
  } else {
    object.rotation.y = Math.PI;
    object.position.z -= boxBefore.max.z - halfD;
  }

  const boxAfter = new THREE.Box3().setFromObject(object);
  const objectHalfW = Math.max(.02, (boxAfter.max.x - boxAfter.min.x) / 2);
  const objectHalfD = Math.max(.02, (boxAfter.max.z - boxAfter.min.z) / 2);
  object.position.x = THREE.MathUtils.clamp(
    object.position.x,
    -halfW + objectHalfW,
    halfW - objectHalfW
  );
  object.position.z = THREE.MathUtils.clamp(
    object.position.z,
    -halfD + objectHalfD,
    halfD - objectHalfD
  );

  if (object.userData.type === 'door') {
    keepOnFloor(object);
  } else {
    clampVertical(object);
  }
}

function onPointerDown(event) {
  if (transformControls.dragging) return;
  const picked = pickObject(event);
  if (!picked) return;
  event.preventDefault();
  event.stopPropagation();
  selectObject(picked);
}

function onPointerMove(event) {
}

function onPointerUp(event) {
}

function pickObject(event) {
  const rect = renderer.domElement.getBoundingClientRect();
  const mouse = new THREE.Vector2(
    ((event.clientX - rect.left) / rect.width) * 2 - 1,
    -((event.clientY - rect.top) / rect.height) * 2 + 1
  );
  const raycaster = new THREE.Raycaster();
  raycaster.setFromCamera(mouse, camera);
  const intersections = raycaster.intersectObjects(objects, true);
  if (!intersections.length) return;

  let root = intersections[0].object;
  while (root.parent && !objects.includes(root)) {
    root = root.parent;
  }
  if (objects.includes(root)) {
    return root;
  }
  return null;
}

function screenToFloor(event) {
  const rect = renderer.domElement.getBoundingClientRect();
  const mouse = new THREE.Vector2(
    ((event.clientX - rect.left) / rect.width) * 2 - 1,
    -((event.clientY - rect.top) / rect.height) * 2 + 1
  );
  const raycaster = new THREE.Raycaster();
  raycaster.setFromCamera(mouse, camera);
  const floorPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  const point = new THREE.Vector3();
  return raycaster.ray.intersectPlane(floorPlane, point);
}

function selectObject(object) {
  selected = object;
  transformControls.showX = true;
  transformControls.showY = canMoveVertical(object);
  transformControls.showZ = true;
  transformControls.setMode('translate');
  transformControls.attach(object);
}

function setTransformMode(mode) {
  transformControls.setMode(mode);
}

function rotateSelected(degrees) {
  if (!selected) return;
  transformControls.detach();
  selected.rotation.y += THREE.MathUtils.degToRad(degrees);
  keepObjectInsideRoom(selected);
  transformControls.attach(selected);
}

function scaleSelected(factor) {
  if (!selected) return;
  transformControls.detach();
  const nextScale = selected.scale.x * factor;
  if (nextScale < .25 || nextScale > 4) {
    transformControls.attach(selected);
    return;
  }
  selected.scale.multiplyScalar(factor);
  if (!canMoveVertical(selected)) {
    keepOnFloor(selected);
  } else {
    clampVertical(selected);
  }
  keepObjectInsideRoom(selected);
  transformControls.attach(selected);
}

function canMoveVertical(object) {
  return object && VERTICAL_TYPES.has(object.userData.type);
}

function exportRoomLayout() {
  objects.forEach(object => keepObjectInsideRoom(object));
  return {
    Width: ROOM.width,
    Depth: ROOM.depth,
    Height: ROOM.height,
    Objects: objects.map((object, index) => {
      const type = object.userData.type || 'object';
      const box = new THREE.Box3().setFromObject(object);
      const size = new THREE.Vector3();
      box.getSize(size);

      return {
        ObjectId: object.userData.objectId || (type + '_' + (index + 1)),
        ObjectName: OBJECT_LABELS[type] || type,
        ClassName: type,
        AssetPath: OBJECT_ASSET_PATHS[type] || '',
        PosX: Number(object.position.x.toFixed(4)),
        PosY: Number(object.position.y.toFixed(4)),
        PosZ: Number(object.position.z.toFixed(4)),
        Width: Number(size.x.toFixed(4)),
        Depth: Number(size.z.toFixed(4)),
        Height: Number(size.y.toFixed(4)),
        Scale: Number(object.scale.x.toFixed(4)),
        RotationX: Number(object.rotation.x.toFixed(4)),
        RotationY: Number(object.rotation.y.toFixed(4)),
        RotationZ: Number(object.rotation.z.toFixed(4)),
        IsFixed: true
      };
    })
  };
}

function clampVertical(object) {
  const box = new THREE.Box3().setFromObject(object);
  if (box.min.y < 0) {
    object.position.y -= box.min.y;
  }
  const refreshed = new THREE.Box3().setFromObject(object);
  if (refreshed.max.y > ROOM.height) {
    object.position.y -= refreshed.max.y - ROOM.height;
  }
}

function deleteSelected() {
  if (!selected) return;
  transformControls.detach();
  scene.remove(selected);
  const index = objects.indexOf(selected);
  if (index >= 0) objects.splice(index, 1);
  selected = null;
}

function resetCamera() {
  camera.position.set(ROOM.width * .55, ROOM.height * .85, ROOM.depth * 1.15);
  orbitControls.target.set(0, ROOM.height * .38, 0);
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
</script>
</body>
</html>
''';
  }
}

class _RoomSetupBackground extends StatelessWidget {
  const _RoomSetupBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -70,
            child: _RoomDecorCircle(size: 210, opacity: 0.16),
          ),
          Positioned(
            bottom: -90,
            left: -84,
            child: _RoomDecorCircle(size: 230, opacity: 0.13),
          ),
          const Positioned(
            top: 110,
            right: -18,
            child: _RoomDecorStripes(),
          ),
        ],
      ),
    );
  }
}

class _RoomSetupTip extends StatelessWidget {
  const _RoomSetupTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lightbulb_outline, color: _accentColor),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sau khi tạo phòng, bạn có thể thêm giường, bàn, tủ, laptop và lưu layout để dùng cho chỉ đường.',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomDecorCircle extends StatelessWidget {
  const _RoomDecorCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RoomDecorStripes extends StatelessWidget {
  const _RoomDecorStripes();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.55,
      child: Row(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(right: 12),
            width: 13,
            height: 118,
            color: Colors.white.withOpacity(0.30),
          ),
        ),
      ),
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _accentColor,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(icon, color: _accentColor),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _accentColor, width: 1.6),
        ),
      ),
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
class _PlainTextField extends StatelessWidget {
  const _PlainTextField({
    required this.controller,
    required this.label,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accentColor, width: 1.5),
        ),
      ),
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ObjectLibrary extends StatelessWidget {
  const _ObjectLibrary({
    required this.objects,
    required this.onAdd,
  });

  final List<_RoomObjectDefinition> objects;
  final ValueChanged<_RoomObjectDefinition> onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: _accentColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Thư viện vật thể',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Bấm để thêm',
                style: TextStyle(
                  color: _accentColor.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: objects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final _RoomObjectDefinition object = objects[index];
                return InkWell(
                  onTap: () => onAdd(object),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 82,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(object.icon, color: _accentColor, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          object.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneButton extends StatelessWidget {
  const _SceneButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? const Color(0xFFDC2626) : _textPrimary;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _RoomObjectDefinition {
  const _RoomObjectDefinition(this.id, this.label, this.assetPath, this.icon);

  final String id;
  final String label;
  final String assetPath;
  final IconData icon;
}


