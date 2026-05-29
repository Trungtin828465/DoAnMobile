import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/grid_layout_model.dart';

/// 3D Isometric Layout Visualizer
/// Vẽ phòng theo dạng isometric (3D giả)
class GridLayoutVisualizer extends StatelessWidget {
  final GridLayout layout;
  final UserPosition? userPosition;
  final double zoomLevel;
  final bool showGrid;
  final bool showFurniture;
  final Color? highlightColor;
  final Offset? highlightPosition; // Position to highlight
  
  const GridLayoutVisualizer({
    Key? key,
    required this.layout,
    this.userPosition,
    this.zoomLevel = 1.0,
    this.showGrid = true,
    this.showFurniture = true,
    this.highlightColor,
    this.highlightPosition,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(
        layout: layout,
        userPosition: userPosition,
        zoomLevel: zoomLevel,
        showGrid: showGrid,
        showFurniture: showFurniture,
        highlightColor: highlightColor,
        highlightPosition: highlightPosition,
      ),
      child: Container(
        color: Colors.white,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final GridLayout layout;
  final UserPosition? userPosition;
  final double zoomLevel;
  final bool showGrid;
  final bool showFurniture;
  final Color? highlightColor;
  final Offset? highlightPosition;

  _GridPainter({
    required this.layout,
    this.userPosition,
    required this.zoomLevel,
    required this.showGrid,
    required this.showFurniture,
    this.highlightColor,
    this.highlightPosition,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Setup isometric transformation
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final cellPixels = 50.0 * zoomLevel; // Size of one cell on screen

    // Draw room floor
    _drawFloor(canvas, center, cellPixels);

    // Draw walls
    _drawWalls(canvas, center, cellPixels);

    // Draw grid if enabled
    if (showGrid) {
      _drawGridLines(canvas, center, cellPixels);
    }

    // Draw furniture if enabled
    if (showFurniture) {
      _drawFurniture(canvas, center, cellPixels);
    }

    // Draw highlight area if specified
    if (highlightPosition != null && highlightColor != null) {
      _drawHighlight(canvas, center, cellPixels, highlightPosition!);
    }

    // Draw user position if available
    if (userPosition != null) {
      _drawUserPosition(canvas, center, cellPixels, userPosition!);
    }

    // Draw legend
    _drawLegend(canvas, canvasSize);
  }

  /// Vẽ sàn phòng (isometric floor)
  void _drawFloor(Canvas canvas, Offset center, double cellPixels) {
    final width = layout.gridWidth * cellPixels;
    final height = layout.gridHeight * cellPixels;

    // Isometric floor (parallelogram)
    final path = Path();
    
    // Top-left
    path.moveTo(center.dx - width / 2, center.dy - height / 2);
    // Top-right
    path.lineTo(center.dx + width / 2, center.dy - height / 2);
    // Bottom-right
    path.lineTo(center.dx + width / 2, center.dy + height / 2);
    // Bottom-left
    path.lineTo(center.dx - width / 2, center.dy + height / 2);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFAFAFA)
        ..style = PaintingStyle.fill,
    );

    // Floor border
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  /// Vẽ tường phòng (walls)
  void _drawWalls(Canvas canvas, Offset center, double cellPixels) {
    final width = layout.gridWidth * cellPixels;
    final height = layout.gridHeight * cellPixels;
    final wallHeight = 20.0; // Pixel height for 3D effect

    // Back wall (North)
    final backWallPath = Path();
    backWallPath.moveTo(center.dx - width / 2, center.dy - height / 2);
    backWallPath.lineTo(
        center.dx - width / 2, center.dy - height / 2 - wallHeight);
    backWallPath.lineTo(
        center.dx + width / 2, center.dy - height / 2 - wallHeight);
    backWallPath.lineTo(center.dx + width / 2, center.dy - height / 2);
    backWallPath.close();

    canvas.drawPath(
      backWallPath,
      Paint()
        ..color = const Color(0xFFE8E8E8)
        ..style = PaintingStyle.fill,
    );

    // Left wall (West)
    final leftWallPath = Path();
    leftWallPath.moveTo(center.dx - width / 2, center.dy - height / 2);
    leftWallPath.lineTo(
        center.dx - width / 2 - wallHeight, center.dy - height / 2);
    leftWallPath.lineTo(center.dx - width / 2 - wallHeight,
        center.dy + height / 2); // Sai logic, fix here
    leftWallPath.lineTo(center.dx - width / 2, center.dy + height / 2);
    leftWallPath.close();

    canvas.drawPath(
      leftWallPath,
      Paint()
        ..color = const Color(0xFFD0D0D0)
        ..style = PaintingStyle.fill,
    );
  }

  /// Vẽ grid lines
  void _drawGridLines(Canvas canvas, Offset center, double cellPixels) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Vertical lines
    for (int x = 0; x <= layout.gridWidth; x++) {
      final startX = center.dx - (layout.gridWidth * cellPixels) / 2 + x * cellPixels;
      final startY = center.dy - (layout.gridHeight * cellPixels) / 2;
      final endY = center.dy + (layout.gridHeight * cellPixels) / 2;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX, endY),
        paint,
      );
    }

    // Horizontal lines
    for (int y = 0; y <= layout.gridHeight; y++) {
      final startX = center.dx - (layout.gridWidth * cellPixels) / 2;
      final endX = center.dx + (layout.gridWidth * cellPixels) / 2;
      final startY = center.dy - (layout.gridHeight * cellPixels) / 2 + y * cellPixels;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, startY),
        paint,
      );
    }
  }

  /// Vẽ nội thất (furniture)
  void _drawFurniture(Canvas canvas, Offset center, double cellPixels) {
    for (final furniture in layout.furnitures) {
      _drawFurnitureItem(canvas, center, cellPixels, furniture);
    }
  }

  /// Vẽ một nội thất
  void _drawFurnitureItem(
    Canvas canvas,
    Offset center,
    double cellPixels,
    Furniture3D furniture,
  ) {
    // Chuyển đổi từ grid coordinates sang pixel coordinates
    final floorX = (furniture.x / layout.cellSize) * cellPixels;
    final floorY = (furniture.y / layout.cellSize) * cellPixels;

    final x = center.dx - (layout.gridWidth * cellPixels) / 2 + floorX;
    final y = center.dy - (layout.gridHeight * cellPixels) / 2 + floorY;

    final rectWidth = (furniture.width / layout.cellSize) * cellPixels;
    final rectHeight = (furniture.depth / layout.cellSize) * cellPixels;

    // Draw 3D box (isometric)
    final topLeftX = x;
    final topLeftY = y - (furniture.height / 2); // Height effect

    // Front face
    final frontPath = Path();
    frontPath.moveTo(topLeftX, topLeftY);
    frontPath.lineTo(topLeftX + rectWidth, topLeftY);
    frontPath.lineTo(topLeftX + rectWidth, topLeftY + rectHeight);
    frontPath.lineTo(topLeftX, topLeftY + rectHeight);
    frontPath.close();

    // Parse color
    final color = _parseColor(furniture.color);

    // Fill
    canvas.drawPath(
      frontPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawPath(
      frontPath,
      Paint()
        ..color = color.withOpacity(0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Draw label
    final textPainter = TextPainter(
      text: TextSpan(
        text: furniture.className,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        topLeftX + (rectWidth - textPainter.width) / 2,
        topLeftY + (rectHeight - textPainter.height) / 2,
      ),
    );
  }

  /// Vẽ vị trí user
  void _drawUserPosition(
    Canvas canvas,
    Offset center,
    double cellPixels,
    UserPosition userPos,
  ) {
    // Chuyển đổi sang pixel
    final pixelX = (userPos.x / layout.cellSize) * cellPixels;
    final pixelY = (userPos.y / layout.cellSize) * cellPixels;

    final x = center.dx - (layout.gridWidth * cellPixels) / 2 + pixelX;
    final y = center.dy - (layout.gridHeight * cellPixels) / 2 + pixelY;

    // Vẽ user icon (circle)
    canvas.drawCircle(
      Offset(x, y),
      8,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill,
    );

    // Vẽ heading direction (arrow)
    final headingRad = userPos.heading * 3.14159 / 180;
    final arrowLength = 15.0;
    final endX = x + arrowLength * math.sin(headingRad);
    final endY = y - arrowLength * math.cos(headingRad);

    canvas.drawLine(
      Offset(x, y),
      Offset(endX, endY),
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 2,
    );

    // Draw accuracy circle
    if (userPos.accuracy != null) {
      canvas.drawCircle(
        Offset(x, y),
        (userPos.accuracy! / layout.cellSize) * cellPixels,
        Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  /// Vẽ highlight area
  void _drawHighlight(
    Canvas canvas,
    Offset center,
    double cellPixels,
    Offset highlightPos,
  ) {
    final pixelX = (highlightPos.dx / layout.cellSize) * cellPixels;
    final pixelY = (highlightPos.dy / layout.cellSize) * cellPixels;

    final x = center.dx - (layout.gridWidth * cellPixels) / 2 + pixelX;
    final y = center.dy - (layout.gridHeight * cellPixels) / 2 + pixelY;

    canvas.drawCircle(
      Offset(x, y),
      12,
      Paint()
        ..color = highlightColor!
        ..style = PaintingStyle.fill,
    );
  }

  /// Vẽ legend
  void _drawLegend(Canvas canvas, Size canvasSize) {
    const legendX = 10.0;
    const legendY = 10.0;
    const itemHeight = 20.0;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(legendX, legendY, 150, 100),
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawRect(
      Rect.fromLTWH(legendX, legendY, 150, 100),
      Paint()
        ..color = Colors.grey
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Items
    const items = [
      ('🔵 User', Colors.blue),
      ('📦 Nội thất', Color(0xFFFF6B6B)),
    ];

    for (int i = 0; i < items.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: items[i].$1,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(legendX + 10, legendY + 10 + i * itemHeight),
      );
    }
  }

  Color _parseColor(String hexColor) {
    if (!hexColor.startsWith('#')) {
      return Colors.grey;
    }
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.userPosition != userPosition ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.layout != layout;
  }
}
