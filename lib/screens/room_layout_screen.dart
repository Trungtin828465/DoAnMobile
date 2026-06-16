import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF3B82F6);
const Color _backgroundColor = Color(0xFFF4F6F8);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF111827);
const Color _textSecondary = Color(0xFF6B7280);

class RoomLayoutScreen extends StatefulWidget {
  const RoomLayoutScreen({super.key});

  @override
  State<RoomLayoutScreen> createState() => _RoomLayoutScreenState();
}

class _RoomLayoutScreenState extends State<RoomLayoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _widthController =
      TextEditingController(text: '5000');
  final TextEditingController _depthController =
      TextEditingController(text: '3000');
  final TextEditingController _heightController =
      TextEditingController(text: '2700');

  bool _roomCreated = false;
  bool _loadingScene = false;
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
  void dispose() {
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

  Future<void> _createRoom() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loadingScene = true;
      _roomCreated = true;
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

  void _resetRoom() {
    setState(() {
      _roomCreated = false;
      _loadingScene = false;
      _sceneController = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(_roomCreated ? 'Phòng 3D' : 'Phòng'),
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0.6,
      ),
      body: _roomCreated ? _buildSceneView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kích thước phòng',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nhập kích thước để tạo một phòng 3D thật. Sau đó bạn có thể xoay 360 độ, thêm vật và chỉnh vị trí trực tiếp trong phòng.',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DimensionField(
                    controller: _widthController,
                    label: 'Chiều dài (W), mm',
                    validator: _validateDimension,
                  ),
                  const SizedBox(height: 14),
                  _DimensionField(
                    controller: _depthController,
                    label: 'Chiều rộng (D), mm',
                    validator: _validateDimension,
                  ),
                  const SizedBox(height: 14),
                  _DimensionField(
                    controller: _heightController,
                    label: 'Chiều cao (H), mm',
                    validator: _validateDimension,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loadingScene ? null : _createRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tạo phòng',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _widthController.text = '5000';
                      _depthController.text = '3000';
                      _heightController.text = '2700';
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textPrimary,
                      backgroundColor: const Color(0xFFEFEFEF),
                      side: BorderSide.none,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Xóa',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
  }) {
    final String sourceJson = jsonEncode(modelSources);
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
const OBJECT_SIZE = {
  bed: 1.55, sofa: 1.25, chair: .7, table: 1.0, wardrobe: 1.15,
  refrigerator: 1.2, tv: .9, door: 1.9, window: 1.1, fan: .8,
  laptop: .45, washing_machine: .85
};
const VERTICAL_TYPES = new Set(['window', 'tv', 'laptop']);

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

function addModel(type) {
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
    root.add(model);
    root.position.set(0, 0, 0);
    keepOnFloor(root);
    keepObjectInsideRoom(root);

    objects.push(root);
    scene.add(root);
    selectObject(root);
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

class _DimensionField extends StatelessWidget {
  const _DimensionField({
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
        fontSize: 18,
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
