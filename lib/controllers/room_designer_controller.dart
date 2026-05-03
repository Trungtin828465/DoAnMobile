import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/session_storage.dart';

enum RoomDesignerStep { size, design }

enum SaveStatus { ok, missingDoor, empty }

class FurnitureItem {
  const FurnitureItem({
    required this.type,
    required this.name,
    required this.width,
    required this.height,
    required this.icon,
    required this.color,
  });

  final String type;
  final String name;
  final int width;
  final int height;
  final IconData icon;
  final ui.Color color;
}

class PlacedItem {
  const PlacedItem({
    required this.id,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotationQuarter,
  });

  final String id;
  final String type;
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;
  final int rotationQuarter;

  PlacedItem copyWith({
    String? id,
    String? type,
    String? name,
    int? x,
    int? y,
    int? width,
    int? height,
    int? rotationQuarter,
  }) {
    return PlacedItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotationQuarter: rotationQuarter ?? this.rotationQuarter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotationQuarter': rotationQuarter,
    };
  }

  factory PlacedItem.fromJson(Map<String, dynamic> json) {
    return PlacedItem(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 1,
      height: (json['height'] as num?)?.toInt() ?? 1,
      rotationQuarter: (json['rotationQuarter'] as num?)?.toInt() ?? 0,
    );
  }
}

class RoomDesignerController extends ChangeNotifier {
  RoomDesignerController({SessionStorage? sessionStorage})
      : _sessionStorage = sessionStorage ?? createSessionStorage();

  static const String sessionKey = 'room_layout_2d';

  final SessionStorage _sessionStorage;

  RoomDesignerStep _step = RoomDesignerStep.size;
  int _roomWidth = 12;
  int _roomHeight = 8;
  final List<PlacedItem> _items = <PlacedItem>[];
  String? _selectedId;
  String? _hoveredId;
  String? _errorMessage;

  RoomDesignerStep get step => _step;
  int get roomWidth => _roomWidth;
  int get roomHeight => _roomHeight;
  List<PlacedItem> get items => List.unmodifiable(_items);
  String? get selectedId => _selectedId;
  String? get hoveredId => _hoveredId;
  String? get errorMessage => _errorMessage;

  List<FurnitureItem> get catalog => const <FurnitureItem>[
        FurnitureItem(
          type: 'door',
          name: 'Door',
          width: 2,
          height: 3,
          icon: Icons.door_front_door,
          color: ui.Color(0xFF8D6E63),
        ),
        FurnitureItem(
          type: 'bed',
          name: 'Bed',
          width: 4,
          height: 3,
          icon: Icons.bed,
          color: ui.Color(0xFF5C6BC0),
        ),
        FurnitureItem(
          type: 'sofa',
          name: 'Sofa',
          width: 4,
          height: 2,
          icon: Icons.weekend,
          color: ui.Color(0xFF26A69A),
        ),
        FurnitureItem(
          type: 'table',
          name: 'Table',
          width: 3,
          height: 2,
          icon: Icons.table_restaurant,
          color: ui.Color(0xFFEF6C00),
        ),
        FurnitureItem(
          type: 'chair',
          name: 'Chair',
          width: 1,
          height: 1,
          icon: Icons.event_seat,
          color: ui.Color(0xFF7E57C2),
        ),
        FurnitureItem(
          type: 'cabinet',
          name: 'Cabinet',
          width: 3,
          height: 1,
          icon: Icons.kitchen,
          color: ui.Color(0xFF546E7A),
        ),
        FurnitureItem(
          type: 'lamp',
          name: 'Lamp',
          width: 1,
          height: 1,
          icon: Icons.lightbulb,
          color: ui.Color(0xFFF9A825),
        ),
        FurnitureItem(
          type: 'plant',
          name: 'Plant',
          width: 1,
          height: 1,
          icon: Icons.local_florist,
          color: ui.Color(0xFF2E7D32),
        ),
        FurnitureItem(
          type: 'tv',
          name: 'TV',
          width: 3,
          height: 1,
          icon: Icons.tv,
          color: ui.Color(0xFF1565C0),
        ),
        FurnitureItem(
          type: 'wardrobe',
          name: 'Wardrobe',
          width: 3,
          height: 4,
          icon: Icons.checkroom,
          color: ui.Color(0xFF6D4C41),
        ),
      ];

  Future<void> initialize() async {
    try {
      _errorMessage = null;
      final raw = _sessionStorage.read(sessionKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final room = (decoded['room'] as Map?)?.cast<String, dynamic>();
        if (room != null) {
          _roomWidth = (room['width'] as num?)?.toInt() ?? _roomWidth;
          _roomHeight = (room['height'] as num?)?.toInt() ?? _roomHeight;
          _step = RoomDesignerStep.design;
        }
        final items = (decoded['items'] as List?) ?? <dynamic>[];
        _items
          ..clear()
          ..addAll(
            items
                .map((entry) => PlacedItem.fromJson(
                      (entry as Map).cast<String, dynamic>(),
                    ))
                .toList(growable: false),
          );
      }
    } catch (error) {
      _errorMessage = 'Failed to load session data: $error';
      debugPrint(_errorMessage);
    }
    notifyListeners();
  }

  void setRoomSize({required int width, required int height}) {
    _roomWidth = width.clamp(4, 80);
    _roomHeight = height.clamp(4, 80);
    _items.clear();
    _selectedId = null;
    _step = RoomDesignerStep.design;
    debugPrint('Da chon kich thuoc ${_roomWidth}x${_roomHeight} (o luoi).');
    notifyListeners();
  }

  void backToSizeStep() {
    _step = RoomDesignerStep.size;
    notifyListeners();
  }

  bool get hasDoor => _items.any((item) => item.type == 'door');

  void selectItem(String? id) {
    _selectedId = id;
    notifyListeners();
  }

  void updateHoverAtScreen(ui.Offset position, ui.Size size) {
    final next = hitTest(position, size);
    if (next == _hoveredId) {
      return;
    }
    _hoveredId = next;
    notifyListeners();
  }

  void clearHover() {
    if (_hoveredId == null) {
      return;
    }
    _hoveredId = null;
    notifyListeners();
  }

  bool isRotatable(String id) {
    final item = _findItemById(id);
    if (item == null) {
      return false;
    }
    return item.width != item.height;
  }

  void rotateItem(String id) {
    final item = _findItemById(id);
    if (item == null || item.width == item.height) {
      return;
    }
    final nextRotation = (item.rotationQuarter + 1) % 4;
    final rotated = item.copyWith(rotationQuarter: nextRotation);
    final clamped = _clampItemToRoom(rotated);
    _replaceSelected(clamped);
    _selectedId = id;
    debugPrint('Da xoay ${item.name} (rotation=${clamped.rotationQuarter}).');
  }

  String? hitTest(ui.Offset position, ui.Size size) {
    final view = _buildViewTransform(size);
    if (view == null) {
      return null;
    }

    for (final item in _items.reversed) {
      final rect = _itemRect(view, item);
      if (rect.contains(position)) {
        return item.id;
      }
    }

    return null;
  }

  ui.Rect? itemScreenRect(String id, ui.Size size) {
    final view = _buildViewTransform(size);
    if (view == null) {
      return null;
    }

    final item = _findItemById(id);
    if (item == null) {
      return null;
    }
    return _itemRect(view, item);
  }

  bool addItemAtScreen(
    ui.Offset position,
    ui.Size size,
    FurnitureItem item,
  ) {
    final view = _buildViewTransform(size);
    if (view == null) {
      debugPrint('Khong the them do vat: view chua san sang.');
      return false;
    }

    final grid = view.screenToGrid(position);
    if (grid == null) {
      debugPrint('Khong the them do vat: keo ngoai vung phong.');
      return false;
    }

    final clamped = _clampGrid(grid.x, grid.y, item.width, item.height);
    final placed = PlacedItem(
      id: _nextId(item.type),
      type: item.type,
      name: item.name,
      x: clamped.x,
      y: clamped.y,
      width: item.width,
      height: item.height,
      rotationQuarter: 0,
    );
    _items.add(placed);
    _selectedId = placed.id;
    debugPrint(
      'Da them ${item.name} tai (${placed.x}, ${placed.y}) kich thuoc ${placed.width}x${placed.height}.',
    );
    notifyListeners();
    return true;
  }

  void moveSelectedToScreenTopLeft(ui.Offset topLeft, ui.Size size) {
    final selected = _selectedId == null ? null : _findItemById(_selectedId!);
    if (selected == null) {
      return;
    }

    final view = _buildViewTransform(size);
    if (view == null) {
      return;
    }

    final grid = view.screenToGridTopLeft(topLeft);
    if (grid == null) {
      return;
    }

    final footprint = _footprintForItem(selected);
    final clamped = _clampGrid(
      grid.x,
      grid.y,
      footprint.width,
      footprint.height,
    );
    _replaceSelected(selected.copyWith(x: clamped.x, y: clamped.y));
  }

  SaveStatus saveToSession() {
    if (_items.isEmpty) {
      debugPrint('Khong the luu: chua co do vat nao.');
      return SaveStatus.empty;
    }
    if (!hasDoor) {
      debugPrint('Khong the luu: chua co cua (door).');
      return SaveStatus.missingDoor;
    }

    final payload = <String, dynamic>{
      'room': {'width': _roomWidth, 'height': _roomHeight},
      'items': _items.map((entry) => entry.toJson()).toList(growable: false),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _sessionStorage.write(sessionKey, jsonEncode(payload));
    debugPrint('Da luu layout vao session.');
    return SaveStatus.ok;
  }

  void clearSession() {
    _sessionStorage.remove(sessionKey);
  }

  void render(ui.Canvas canvas, ui.Size size) {
    final view = _buildViewTransform(size);
    final backgroundPaint = ui.Paint()
      ..color = const ui.Color(0xFFF7F4F0)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    if (view == null) {
      return;
    }

    final roomPaint = ui.Paint()
      ..color = const ui.Color(0xFFFAF7F2)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(view.roomRect, roomPaint);

    _drawGrid(canvas, view);

    final borderPaint = ui.Paint()
      ..color = const ui.Color(0xFF1E293B)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(view.roomRect, borderPaint);

    for (final item in _items) {
      final rect = _itemRect(view, item);
      final isSelected = item.id == _selectedId;
      final isHovered = item.id == _hoveredId;
      final fill = ui.Paint()
        ..color = _paletteColor(item.type).withOpacity(0.85)
        ..style = ui.PaintingStyle.fill;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(8)),
        fill,
      );

      final stroke = ui.Paint()
        ..color = isSelected ? const ui.Color(0xFF0F172A) : const ui.Color(0xFF334155)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(8)),
        stroke,
      );

      _drawItemLabel(canvas, rect, _iconForType(item.type));

      if (isHovered) {
        _drawHoverLabel(canvas, rect, item.name);
        if (item.width != item.height) {
          _drawRotateHandle(canvas, rect);
        }
      }
    }
  }

  void _drawItemLabel(
    ui.Canvas canvas,
    ui.Rect rect,
    IconData? icon,
  ) {
    if (icon != null) {
      final iconText = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 18,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: ui.Color(0xFF0F172A),
        ),
      );
      final iconPainter = TextPainter(
        text: iconText,
        maxLines: 1,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout(maxWidth: rect.width - 8);
      iconPainter.paint(
        canvas,
        ui.Offset(
          rect.center.dx - iconPainter.width / 2,
          rect.center.dy - iconPainter.height / 2,
        ),
      );
    }
  }

  void _drawHoverLabel(ui.Canvas canvas, ui.Rect rect, String label) {
    final text = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    final painter = TextPainter(
      text: text,
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: 140);
    final padding = 6.0;
    final bubble = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(
        rect.center.dx - painter.width / 2 - padding,
        rect.top - painter.height - padding * 2 - 6,
        painter.width + padding * 2,
        painter.height + padding * 2,
      ),
      const ui.Radius.circular(8),
    );
    final bubblePaint = ui.Paint()
      ..color = const ui.Color(0xFF0F172A).withOpacity(0.9);
    canvas.drawRRect(bubble, bubblePaint);
    painter.paint(
      canvas,
      ui.Offset(
        bubble.left + padding,
        bubble.top + padding,
      ),
    );
  }

  void _drawRotateHandle(ui.Canvas canvas, ui.Rect rect) {
    const radius = 12.0;
    final center = rect.center;
    final paint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    final stroke = ui.Paint()
      ..color = const ui.Color(0xFF0F172A)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, stroke);

    final iconText = TextSpan(
      text: String.fromCharCode(Icons.rotate_right.codePoint),
      style: TextStyle(
        fontSize: 14,
        fontFamily: Icons.rotate_right.fontFamily,
        package: Icons.rotate_right.fontPackage,
        color: const ui.Color(0xFF0F172A),
      ),
    );
    final painter = TextPainter(
      text: iconText,
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(
      canvas,
      ui.Offset(
        center.dx - painter.width / 2,
        center.dy - painter.height / 2,
      ),
    );
  }

  void _replaceSelected(PlacedItem item) {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      return;
    }
    _items[index] = item;
    notifyListeners();
  }

  PlacedItem _clampItemToRoom(PlacedItem item) {
    final footprint = _footprintForItem(item);
    final clamped = _clampGrid(item.x, item.y, footprint.width, footprint.height);
    return item.copyWith(x: clamped.x, y: clamped.y);
  }

  PlacedItem? _findItemById(String id) {
    for (final item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  String _nextId(String prefix) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$stamp-${_items.length + 1}';
  }

  _GridPoint _clampGrid(int x, int y, int width, int height) {
    final maxX = math.max(0, _roomWidth - width);
    final maxY = math.max(0, _roomHeight - height);
    return _GridPoint(
      x: x.clamp(0, maxX),
      y: y.clamp(0, maxY),
    );
  }

  _ItemFootprint _footprintForItem(PlacedItem item) {
    final rotated = item.rotationQuarter % 2 == 1;
    return _ItemFootprint(
      width: rotated ? item.height : item.width,
      height: rotated ? item.width : item.height,
    );
  }

  ui.Rect _itemRect(_ViewTransform view, PlacedItem item) {
    final footprint = _footprintForItem(item);
    return view.itemRect(item, footprint.width, footprint.height);
  }

  ui.Color _paletteColor(String type) {
    final match = catalog.firstWhere(
      (entry) => entry.type == type,
      orElse: () => catalog.first,
    );
    return match.color;
  }

  IconData? _iconForType(String type) {
    for (final item in catalog) {
      if (item.type == type) {
        return item.icon;
      }
    }
    return null;
  }

  _ViewTransform? _buildViewTransform(ui.Size size) {
    if (_roomWidth <= 0 || _roomHeight <= 0 || size.isEmpty) {
      return null;
    }

    const padding = 20.0;
    final availableWidth = math.max(1, size.width - padding * 2);
    final availableHeight = math.max(1, size.height - padding * 2);
    const cellAspect = 2.0;
    final cellHeight = math.min(
      availableWidth / (_roomWidth * cellAspect),
      availableHeight / _roomHeight,
    );
    final cellWidth = cellHeight * cellAspect;
    final roomWidthPx = _roomWidth * cellWidth;
    final roomHeightPx = _roomHeight * cellHeight;
    final topLeft = ui.Offset(
      (size.width - roomWidthPx) / 2,
      (size.height - roomHeightPx) / 2,
    );

    return _ViewTransform(
      roomWidth: _roomWidth,
      roomHeight: _roomHeight,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      topLeft: topLeft,
    );
  }

  void _drawGrid(ui.Canvas canvas, _ViewTransform view) {
    final gridPaint = ui.Paint()
      ..color = const ui.Color(0xFFD0D7DE)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int x = 0; x <= view.roomWidth; x++) {
      final dx = view.topLeft.dx + x * view.cellWidth;
      canvas.drawLine(
        ui.Offset(dx, view.topLeft.dy),
        ui.Offset(dx, view.topLeft.dy + view.roomHeight * view.cellHeight),
        gridPaint,
      );
    }

    for (int y = 0; y <= view.roomHeight; y++) {
      final dy = view.topLeft.dy + y * view.cellHeight;
      canvas.drawLine(
        ui.Offset(view.topLeft.dx, dy),
        ui.Offset(view.topLeft.dx + view.roomWidth * view.cellWidth, dy),
        gridPaint,
      );
    }
  }
}

class _ViewTransform {
  const _ViewTransform({
    required this.roomWidth,
    required this.roomHeight,
    required this.cellWidth,
    required this.cellHeight,
    required this.topLeft,
  });

  final int roomWidth;
  final int roomHeight;
  final double cellWidth;
  final double cellHeight;
  final ui.Offset topLeft;

  ui.Rect get roomRect => ui.Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        roomWidth * cellWidth,
        roomHeight * cellHeight,
      );

  ui.Rect itemRect(PlacedItem item, int width, int height) {
    return ui.Rect.fromLTWH(
      topLeft.dx + item.x * cellWidth,
      topLeft.dy + item.y * cellHeight,
      width * cellWidth,
      height * cellHeight,
    );
  }

  _GridPoint? screenToGrid(ui.Offset position) {
    if (!roomRect.contains(position)) {
      return null;
    }
    final localX = (position.dx - topLeft.dx) / cellWidth;
    final localY = (position.dy - topLeft.dy) / cellHeight;
    return _GridPoint(x: localX.floor(), y: localY.floor());
  }

  _GridPoint? screenToGridTopLeft(ui.Offset topLeftPosition) {
    final localX = (topLeftPosition.dx - topLeft.dx) / cellWidth;
    final localY = (topLeftPosition.dy - topLeft.dy) / cellHeight;
    if (localX.isNaN || localY.isNaN) {
      return null;
    }
    return _GridPoint(x: localX.round(), y: localY.round());
  }
}

class _GridPoint {
  const _GridPoint({required this.x, required this.y});

  final int x;
  final int y;
}

class _ItemFootprint {
  const _ItemFootprint({required this.width, required this.height});

  final int width;
  final int height;
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

