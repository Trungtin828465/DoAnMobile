import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

import '../models/layout_model.dart';
import '../services/layout_storage_service.dart';

// Simplified version without flutter_scene 3D rendering
class RoomDesignerController extends ChangeNotifier {
  RoomDesignerController({LayoutStorageService? storageService})
    : _storageService = storageService ?? LayoutStorageService();

  final LayoutStorageService _storageService;

  LayoutData? _layout;
  bool _isInitialized = false;
  String? _errorMessage;

  final Map<String, dynamic> _objectNodesById = <String, dynamic>{};
  final Map<String, bool> _fallbackUsedById = <String, bool>{};

  String? _selectedObjectId;

  double _yaw = 0;
  double _pitch = 0;
  double _moveSpeed = 1.5;
  Vector2 _moveInput = Vector2.zero();
  Vector3 _cameraPosition = Vector3.zero();

  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  LayoutData? get layout => _layout;
  double get moveSpeed => _moveSpeed;
  double get yaw => _yaw;
  double get pitch => _pitch;
  String? get selectedObjectId => _selectedObjectId;
  bool get hasSceneData => _layout != null;

  List<LayoutObject> get layoutObjects =>
      _layout?.objects ?? const <LayoutObject>[];

  LayoutObject? get selectedObject {
    final id = _selectedObjectId;
    if (id == null || _layout == null) {
      return null;
    }
    return _layout!.objects.where((entry) => entry.id == id).firstOrNull;
  }

  bool get isUsingFallbackForSelection {
    final id = _selectedObjectId;
    if (id == null) {
      return false;
    }
    return _fallbackUsedById[id] ?? false;
  }

  Future<void> initialize() async {
    try {
      _errorMessage = null;
      _layout = await _storageService.loadLayout();
      _initializeCamera();
      _isInitialized = true;
    } catch (error) {
      _errorMessage = 'Failed to initialize room designer: $error';
      debugPrint(_errorMessage);
    }
    notifyListeners();
  }

  void onFrame(double dtSeconds) {
    if (!_isInitialized || _layout == null) {
      return;
    }

    final forward = _computeForward();
    final right = forward.cross(Vector3(0, 1, 0)).normalized();

    Vector3 movement = (right * _moveInput.x) + (forward * _moveInput.y);
    movement.y = 0;

    if (movement.length2 > 0) {
      movement.normalize();
      _cameraPosition += movement * _moveSpeed * dtSeconds;
      _clampCameraToRoomBounds();
    }

    notifyListeners();
  }

  void setMoveInput(double x, double y) {
    _moveInput = Vector2(x.clamp(-1, 1), y.clamp(-1, 1));
  }

  void setMoveSpeed(double speed) {
    _moveSpeed = speed.clamp(0.5, 3.0);
    notifyListeners();
  }

  void applyLookDrag(double deltaDx, double deltaDy) {
    const sensitivity = 0.006;
    _yaw += deltaDx * sensitivity;
    _pitch += -deltaDy * sensitivity;
    _pitch = _pitch.clamp(-1.35, 1.35);
    notifyListeners();
  }

  void selectObject(String objectId) {
    _selectedObjectId = objectId;
    notifyListeners();
  }

  void rotateSelectedObjectY(double deltaDeg) {
    final object = selectedObject;
    if (object == null) {
      return;
    }

    final nextRotation = object.rotationEulerDeg.copyWith(
      y: object.rotationEulerDeg.y + deltaDeg,
    );
    _replaceObject(object.copyWith(rotationEulerDeg: nextRotation));
  }

  void moveSelectedObjectByDelta({
    required double deltaX,
    required double deltaZ,
  }) {
    final object = selectedObject;
    final layoutData = _layout;
    if (object == null || layoutData == null) {
      return;
    }

    final bounds = layoutData.room.bounds;
    final nextPosition = object.position.copyWith(
      x: (object.position.x + deltaX).clamp(bounds.minX, bounds.maxX),
      y: 0,
      z: (object.position.z + deltaZ).clamp(bounds.minZ, bounds.maxZ),
    );

    _replaceObject(object.copyWith(position: nextPosition));
  }

  Future<String?> saveLayout() async {
    final layoutData = _layout;
    if (layoutData == null) {
      return null;
    }

    final file = await _storageService.saveLayout(layoutData);
    debugPrint('Saved layout to: ${file.path}');
    debugPrint(layoutData.toPrettyJson());
    return file.path;
  }

  void render(ui.Canvas canvas, ui.Size size) {
    if (!_isInitialized || size.isEmpty) {
      return;
    }

    // Draw a simple placeholder for the 3D view
    final paint = ui.Paint()
      ..color = const ui.Color(0xFF9E9E9E)
      ..style = ui.PaintingStyle.fill;
    
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  Future<void> _buildSceneFromLayout() async {
    // Placeholder - 3D rendering requires flutter_scene with CMake
  }

  void _replaceObject(LayoutObject nextObject) {
    final layoutData = _layout;
    if (layoutData == null) {
      return;
    }

    final nextObjects = layoutData.objects
        .map((entry) => entry.id == nextObject.id ? nextObject : entry)
        .toList(growable: false);

    _layout = layoutData.copyWith(objects: nextObjects);
    notifyListeners();
  }

  void _initializeCamera() {
    final layoutData = _layout;
    if (layoutData == null) {
      return;
    }

    final bounds = layoutData.room.bounds;
    _cameraPosition = Vector3(0, layoutData.room.eyeHeight, bounds.maxZ - 0.25);
    _yaw = math.pi;
    _pitch = 0;
  }

  void _clampCameraToRoomBounds() {
    final layoutData = _layout;
    if (layoutData == null) {
      return;
    }

    final bounds = layoutData.room.bounds;
    _cameraPosition.x = _cameraPosition.x.clamp(bounds.minX, bounds.maxX);
    _cameraPosition.z = _cameraPosition.z.clamp(bounds.minZ, bounds.maxZ);
    _cameraPosition.y = layoutData.room.eyeHeight;
  }

  Vector3 _computeForward() {
    final cosPitch = math.cos(_pitch);
    return Vector3(
      math.sin(_yaw) * cosPitch,
      math.sin(_pitch),
      -math.cos(_yaw) * cosPitch,
    ).normalized();
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

