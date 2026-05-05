import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    required this.assetPath,
    required this.imageScale,
  });

  final String type;
  final String name;
  final int width;
  final int height;
  final IconData icon;
  final ui.Color color;
  final String assetPath;
  final double imageScale;
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
  });

  final String id;
  final String type;
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;

  PlacedItem copyWith({
    String? id,
    String? type,
    String? name,
    int? x,
    int? y,
    int? width,
    int? height,
  }) {
    return PlacedItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
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
    );
  }
}

class RoomDesignerController extends ChangeNotifier {
  RoomDesignerController({SessionStorage? sessionStorage})
      : _sessionStorage = sessionStorage ?? createSessionStorage();

  static const String sessionKey = 'room_layout_2d';
  static const double metersPerCell = 0.5;
  static const double minRoomMeters = 2.0;
  static const double maxRoomMeters = 20.0;

  final SessionStorage _sessionStorage;

  RoomDesignerStep _step = RoomDesignerStep.size;
  int _roomWidth = 8;
  int _roomHeight = 10;
  final List<PlacedItem> _items = <PlacedItem>[];
  String? _selectedId;
  String? _hoveredId;
  String? _errorMessage;
  final Map<String, ui.Image> _imageCache = <String, ui.Image>{};

  RoomDesignerStep get step => _step;
  int get roomWidth => _roomWidth;
  int get roomHeight => _roomHeight;
  double get roomWidthMeters => _roomWidth * metersPerCell;
  double get roomHeightMeters => _roomHeight * metersPerCell;
  List<PlacedItem> get items => List.unmodifiable(_items);
  String? get selectedId => _selectedId;
  String? get hoveredId => _hoveredId;
  String? get errorMessage => _errorMessage;

  List<FurnitureItem> get catalog => const <FurnitureItem>[
        FurnitureItem(
          type: 'door',
          name: 'Door',
          width: 2,
          height: 2,
          icon: Icons.door_front_door,
          color: ui.Color(0xFF8D6E63),
          assetPath: 'assets/anh/door.png',
          imageScale: 0.9,
        ),
        FurnitureItem(
          type: 'bed',
          name: 'Bed',
          width: 3,
          height: 3,
          icon: Icons.bed,
          color: ui.Color(0xFF5C6BC0),
          assetPath: 'assets/anh/bed.png',
          imageScale: 0.95,
        ),
        FurnitureItem(
          type: 'sofa',
          name: 'Sofa',
          width: 4,
          height: 2,
          icon: Icons.weekend,
          color: ui.Color(0xFF26A69A),
          assetPath: 'assets/anh/sofa.png',
          imageScale: 0.95,
        ),
        FurnitureItem(
          type: 'table',
          name: 'Table',
          width: 3,
          height: 2,
          icon: Icons.table_restaurant,
          color: ui.Color(0xFFEF6C00),
          assetPath: 'assets/anh/table.png',
          imageScale: 0.95,
        ),
        FurnitureItem(
          type: 'chair',
          name: 'Chair',
          width: 2,
          height: 2,
          icon: Icons.event_seat,
          color: ui.Color(0xFF7E57C2),
          assetPath: 'assets/anh/chair.png',
          imageScale: 0.9,
        ),
        FurnitureItem(
          type: 'cabinet',
          name: 'Cabinet',
          width: 2,
          height: 3,
          icon: Icons.kitchen,
          color: ui.Color(0xFF546E7A),
          assetPath: 'assets/anh/cabinet.png',
          imageScale: 0.9,
        ),
        FurnitureItem(
          type: 'lamp',
          name: 'Lamp',
          width: 1,
          height: 1,
          icon: Icons.lightbulb,
          color: ui.Color(0xFFF9A825),
          assetPath: 'assets/anh/lamp.png',
          imageScale: 0.85,
        ),
        FurnitureItem(
          type: 'plant',
          name: 'Plant',
          width: 1,
          height: 1,
          icon: Icons.local_florist,
          color: ui.Color(0xFF2E7D32),
          assetPath: 'assets/anh/plant.png',
          imageScale: 0.9,
        ),
        FurnitureItem(
          type: 'tv',
          name: 'TV',
          width: 2,
          height: 2,
          icon: Icons.tv,
          color: ui.Color(0xFF1565C0),
          assetPath: 'assets/anh/tv.png',
          imageScale: 0.85,
        ),
        FurnitureItem(
          type: 'laptop',
          name: 'Laptop',
          width: 2,
          height: 2,
          icon: Icons.laptop_mac,
          color: ui.Color(0xFF455A64),
          assetPath: 'assets/anh/laptop.png',
          imageScale: 0.85,
        ),
        FurnitureItem(
          type: 'frame',
          name: 'Frame',
          width: 1,
          height: 1,
          icon: Icons.photo,
          color: ui.Color(0xFF6D4C41),
          assetPath: 'assets/anh/frame.png',
          imageScale: 0.8,
        ),
        FurnitureItem(
          type: 'window',
          name: 'Window',
          width: 2,
          height: 1,
          icon: Icons.window,
          color: ui.Color(0xFF26C6DA),
          assetPath: 'assets/anh/windown.png',
          imageScale: 0.85,
        ),
      ];

  Future<void> initialize() async {
    try {
      _errorMessage = null;
      await _preloadImages();
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

  void setRoomSize({required double widthMeters, required double heightMeters}) {
    final safeWidth =
        widthMeters.clamp(minRoomMeters, maxRoomMeters).toDouble();
    final safeHeight =
        heightMeters.clamp(minRoomMeters, maxRoomMeters).toDouble();
    _roomWidth = _metersToCells(safeWidth);
    _roomHeight = _metersToCells(safeHeight);
    _items.clear();
    _selectedId = null;
    _step = RoomDesignerStep.design;
    debugPrint(
      'Da chon kich thuoc ${safeWidth.toStringAsFixed(1)}x'
      '${safeHeight.toStringAsFixed(1)}m '
      '(${_roomWidth}x${_roomHeight} o luoi).',
    );
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


  String? hitTest(ui.Offset position, ui.Size size) {
    final view = _buildViewTransform(size);
    if (view == null) {
      return null;
    }

    for (final item in _items.reversed) {
      final rect = view.itemRect(item, item.width, item.height);
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
    return view.itemRect(item, item.width, item.height);
  }

  bool addItemAtScreen(
    ui.Offset position,
    ui.Size size,
    FurnitureItem item,
  ) {
    final view = _buildViewTransform(size);
    if (view == null) {
      debugPrint('✗ View chưa sẵn sàng (size: $size)');
      return false;
    }

    debugPrint('🔍 Adding item: ${item.name}');
    debugPrint('  Position: $position');
    debugPrint('  Canvas size: $size');
    debugPrint('  Room rect: ${view.roomRect}');

    final grid = view.screenToGrid(position);
    if (grid == null) {
      debugPrint('✗ Thả ngoài vùng phòng (grid=null)');
      return false;
    }

    debugPrint('✓ Grid position: (${grid.x}, ${grid.y})');

    final clamped = _clampGrid(grid.x, grid.y, item.width, item.height);
    final placed = PlacedItem(
      id: _nextId(item.type),
      type: item.type,
      name: item.name,
      x: clamped.x,
      y: clamped.y,
      width: item.width,
      height: item.height,
    );
    _items.add(placed);
    _selectedId = placed.id;
    debugPrint('✓ Thêm ${item.name} tại (${placed.x}, ${placed.y}) kích thước ${placed.width}x${placed.height}');
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

    final clamped = _clampGrid(
      grid.x,
      grid.y,
      selected.width,
      selected.height,
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
    
    // Clean background - light blue tone
    final backgroundPaint = ui.Paint()
      ..color = const ui.Color(0xFFFAFBFC)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    if (view == null) {
      return;
    }

    // Room background - bright white
    final roomBg = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..style = ui.PaintingStyle.fill;
    canvas.drawRect(view.roomRect, roomBg);

    // Draw grid
    _drawGrid(canvas, view);

    // Room shadow - subtle but visible
    final shadowPaint = ui.Paint()
      ..color = const ui.Color(0xFF1E293B).withOpacity(0.08)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(view.roomRect, shadowPaint);

    // Main room border - bold blue
    final borderPaint = ui.Paint()
      ..color = const ui.Color(0xFF2563EB)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(view.roomRect, borderPaint);

    // Draw items with beautiful styling
    for (final item in _items) {
      final rect = view.itemRect(item, item.width, item.height);
      final isSelected = item.id == _selectedId;
      final isHovered = item.id == _hoveredId;
      final itemColor = _paletteColor(item.type);

      // Enhanced shadow for select/hover
      if (isSelected || isHovered) {
        final shadowPaint = ui.Paint()
          ..color = itemColor.withOpacity(0.3)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12);
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(rect.inflate(3), const ui.Radius.circular(12)),
          shadowPaint,
        );
      } else {
        // Normal shadow
        final shadowPaint = ui.Paint()
          ..color = const ui.Color(0xFF1E293B).withOpacity(0.1)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(rect.inflate(1), const ui.Radius.circular(12)),
          shadowPaint,
        );
      }

      // Item background with gradient feel
      final fill = ui.Paint()
        ..color = itemColor.withOpacity(0.95)
        ..style = ui.PaintingStyle.fill;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(12)),
        fill,
      );

      // Item border - white or colored
      final stroke = ui.Paint()
        ..color = isSelected
            ? const ui.Color(0xFFFFFFFF)
            : itemColor.withOpacity(0.4)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 2;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(12)),
        stroke,
      );

      _drawItemImage(canvas, rect, item);

      // Always show label at bottom
      _drawItemLabel(canvas, rect, item.name);

      if (isHovered) {
        _drawHoverLabel(canvas, rect, item.name);
      }
    }
  }

  void _drawItemLabel(ui.Canvas canvas, ui.Rect rect, String name) {
    final textSpan = TextSpan(
      text: name,
      style: const TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw semi-transparent background for text
    final textBgPaint = ui.Paint()
      ..color = const ui.Color(0xFF000000).withOpacity(0.4)
      ..style = ui.PaintingStyle.fill;
    
    final textBgRect = ui.Rect.fromLTWH(
      rect.left + (rect.width - textPainter.width) / 2 - 6,
      rect.bottom - 24,
      textPainter.width + 12,
      16,
    );
    
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(textBgRect, const ui.Radius.circular(4)),
      textBgPaint,
    );

    // Draw text
    textPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - textPainter.width) / 2,
        rect.bottom - 22,
      ),
    );
  }

  void _drawItemImage(ui.Canvas canvas, ui.Rect rect, PlacedItem item) {
    final image = _imageCache[item.type];
    if (image == null) {
      _drawFallbackColor(canvas, rect, item.type);
      return;
    }

    final src = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = _fitImageRect(rect, image, _imageScaleForType(item.type));
    canvas.drawImageRect(
      image,
      src,
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  void _drawFallbackColor(ui.Canvas canvas, ui.Rect rect, String type) {
    final color = _paletteColor(type).withOpacity(0.6);
    final bgPaint = ui.Paint()..color = color;
    canvas.drawRect(rect, bgPaint);
    _drawFallbackIcon(canvas, rect, _iconForType(type));
  }

  void _drawFallbackIcon(
    ui.Canvas canvas,
    ui.Rect rect,
    IconData? icon,
  ) {
    if (icon == null) {
      return;
    }
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


  void _replaceSelected(PlacedItem item) {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      return;
    }
    _items[index] = item;
    notifyListeners();
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

  int _metersToCells(double meters) {
    final cells = (meters / metersPerCell).round();
    return cells < 1 ? 1 : cells;
  }

  _GridPoint _clampGrid(int x, int y, int width, int height) {
    final maxX = math.max(0, _roomWidth - width);
    final maxY = math.max(0, _roomHeight - height);
    return _GridPoint(
      x: x.clamp(0, maxX),
      y: y.clamp(0, maxY),
    );
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

  double _imageScaleForType(String type) {
    for (final item in catalog) {
      if (item.type == type) {
        return item.imageScale;
      }
    }
    return 0.9;
  }

  ui.Rect _fitImageRect(ui.Rect rect, ui.Image image, double scale) {
    final targetWidth = rect.width * scale;
    final targetHeight = rect.height * scale;
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    if (imageWidth <= 0 || imageHeight <= 0) {
      return rect;
    }

    final imageAspect = imageWidth / imageHeight;
    final targetAspect = targetWidth / targetHeight;
    double drawWidth;
    double drawHeight;
    if (imageAspect >= targetAspect) {
      drawWidth = targetWidth;
      drawHeight = targetWidth / imageAspect;
    } else {
      drawHeight = targetHeight;
      drawWidth = targetHeight * imageAspect;
    }

    return ui.Rect.fromCenter(
      center: rect.center,
      width: drawWidth,
      height: drawHeight,
    );
  }

  Future<void> _preloadImages() async {
    for (final item in catalog) {
      if (_imageCache.containsKey(item.type)) {
        continue;
      }
      try {
        final data = await rootBundle.load(item.assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _imageCache[item.type] = frame.image;
        debugPrint('✓ Da tai ${item.assetPath}');
      } catch (error) {
        debugPrint('✗ Khong tai duoc ${item.assetPath}: $error - se dung icon fallback');
      }
    }
  }

  _ViewTransform? _buildViewTransform(ui.Size size) {
    if (_roomWidth <= 0 || _roomHeight <= 0 || size.isEmpty) {
      debugPrint('✗ Invalid view transform params: size=$size, room=${_roomWidth}x${_roomHeight}');
      return null;
    }

    const padding = 20.0;
    final availableWidth = math.max(1, size.width - padding * 3);
    final availableHeight = math.max(1, size.height - padding * 3);
    final cellSize = math.min(
      availableWidth / _roomWidth,
      availableHeight / _roomHeight,
    );
    final cellWidth = cellSize;
    final cellHeight = cellSize;
    final roomWidthPx = _roomWidth * cellWidth;
    final roomHeightPx = _roomHeight * cellHeight;
    final topLeft = ui.Offset(
      (size.width - roomWidthPx) / 2,
      (size.height - roomHeightPx) / 2,
    );

    debugPrint('📐 View transform:');
    debugPrint('  Canvas size: ${size.width}x${size.height}');
    debugPrint('  Room: ${_roomWidth}x${_roomHeight} cells');
    debugPrint('  Cell size: ${cellWidth.toStringAsFixed(2)}px');
    debugPrint('  Room in pixels: ${roomWidthPx.toStringAsFixed(0)}x${roomHeightPx.toStringAsFixed(0)}');
    debugPrint('  Top-left: (${topLeft.dx.toStringAsFixed(1)}, ${topLeft.dy.toStringAsFixed(1)})');

    return _ViewTransform(
      roomWidth: _roomWidth,
      roomHeight: _roomHeight,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      topLeft: topLeft,
    );
  }

  void _drawGrid(ui.Canvas canvas, _ViewTransform view) {
    // Draw subtle grid lines
    final gridPaint = ui.Paint()
      ..color = const ui.Color(0xFFE2E8F0)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1;

    // Vertical lines
    for (int x = 0; x <= view.roomWidth; x++) {
      final dx = view.topLeft.dx + x * view.cellWidth;
      canvas.drawLine(
        ui.Offset(dx, view.topLeft.dy),
        ui.Offset(dx, view.topLeft.dy + view.roomHeight * view.cellHeight),
        gridPaint,
      );
    }

    // Horizontal lines
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
    // Check with small tolerance for edge cases on mobile
    final expandedRect = roomRect.inflate(2.0); // Add 2px tolerance
    if (!expandedRect.contains(position)) {
      debugPrint('  ✗ Vị trí $position không nằm trong phòng (roomRect: $roomRect)');
      return null;
    }
    final localX = (position.dx - topLeft.dx) / cellWidth;
    final localY = (position.dy - topLeft.dy) / cellHeight;
    debugPrint('  ✓ Tính toán grid: localX=$localX, localY=$localY');
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

