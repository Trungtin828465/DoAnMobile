/// 3D Grid Layout cho căn phòng
class GridLayout {
  String name;           // "Phòng khách", "Phòng ngủ"
  int gridWidth;         // 5 (ô)
  int gridHeight;        // 3 (ô)
  double cellSize;       // 1.0 meter per cell
  double roomHeight;     // 2.8 meter (height thực)
  List<GridCell> cells;
  List<Furniture3D> furnitures; // List furniture với 3D position
  
  GridLayout({
    required this.name,
    required this.gridWidth,
    required this.gridHeight,
    required this.cellSize,
    required this.roomHeight,
    required this.cells,
    required this.furnitures,
  });

  // Tính kích thước phòng thực (meter)
  double get actualWidth => gridWidth * cellSize;
  double get actualHeight => gridHeight * cellSize;
  
  // Parse từ JSON
  factory GridLayout.fromJson(Map<String, dynamic> json) {
    return GridLayout(
      name: json['name'] ?? 'Phòng',
      gridWidth: json['gridWidth'] ?? 5,
      gridHeight: json['gridHeight'] ?? 3,
      cellSize: (json['cellSize'] ?? 1.0).toDouble(),
      roomHeight: (json['roomHeight'] ?? 2.8).toDouble(),
      cells: (json['cells'] as List?)
              ?.map((c) => GridCell.fromJson(c))
              .toList() ??
          [],
      furnitures: (json['furnitures'] as List?)
              ?.map((f) => Furniture3D.fromJson(f))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gridWidth': gridWidth,
      'gridHeight': gridHeight,
      'cellSize': cellSize,
      'roomHeight': roomHeight,
      'cells': cells.map((c) => c.toJson()).toList(),
      'furnitures': furnitures.map((f) => f.toJson()).toList(),
    };
  }
}

/// Một ô trong grid
class GridCell {
  int x, y;              // Vị trí (0-based)
  CellType type;         // empty, wall, door, window
  bool isBlocked;        // Có thể đi qua không?
  
  GridCell({
    required this.x,
    required this.y,
    required this.type,
    this.isBlocked = false,
  });

  factory GridCell.fromJson(Map<String, dynamic> json) {
    return GridCell(
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
      type: CellType.values[json['type'] ?? 0],
      isBlocked: json['isBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'type': type.index,
      'isBlocked': isBlocked,
    };
  }
}

enum CellType { empty, wall, door, window }

/// Nội thất 3D trong phòng
class Furniture3D {
  String id;             // Unique ID
  String className;      // 'bed', 'sofa', 'table', ...
  double x, y, z;        // 3D position (meter) - z = height
  double width;          // chiều rộng (meter)
  double depth;          // chiều sâu (meter)
  double height;         // chiều cao (meter)
  double rotation;       // Góc quay (degree) - 0,90,180,270
  String color;          // HEX color
  String? icon;          // Icon name (nếu có)
  
  Furniture3D({
    required this.id,
    required this.className,
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.depth,
    required this.height,
    this.rotation = 0,
    this.color = '#FF6B6B',
    this.icon,
  });

  // Lấy bounding box 2D trên mặt đất
  BoundingBox2D getBoundingBox() {
    return BoundingBox2D(
      minX: x,
      maxX: x + width,
      minY: y,
      maxY: y + depth,
    );
  }

  factory Furniture3D.fromJson(Map<String, dynamic> json) {
    return Furniture3D(
      id: json['id'] ?? '',
      className: json['className'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      z: (json['z'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 1.0).toDouble(),
      depth: (json['depth'] ?? 1.0).toDouble(),
      height: (json['height'] ?? 1.0).toDouble(),
      rotation: (json['rotation'] ?? 0).toDouble(),
      color: json['color'] ?? '#FF6B6B',
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'className': className,
      'x': x,
      'y': y,
      'z': z,
      'width': width,
      'depth': depth,
      'height': height,
      'rotation': rotation,
      'color': color,
      'icon': icon,
    };
  }
}

/// Bounding box 2D trên mặt đất
class BoundingBox2D {
  double minX, maxX, minY, maxY;
  
  BoundingBox2D({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  bool contains(double x, double y) {
    return x >= minX && x <= maxX && y >= minY && y <= maxY;
  }

  bool intersects(BoundingBox2D other) {
    return !(maxX < other.minX ||
        minX > other.maxX ||
        maxY < other.minY ||
        minY > other.maxY);
  }
}

/// User position trong phòng
class UserPosition {
  double x, y;           // Grid position (meter)
  double heading;        // Hướng quay (degree): 0=North, 90=East, 180=South, 270=West
  DateTime timestamp;
  double? accuracy;      // Độ chính xác (meter)
  
  UserPosition({
    required this.x,
    required this.y,
    required this.heading,
    required this.timestamp,
    this.accuracy,
  });

  // Tính toán vị trí target dựa heading
  (double, double) getTargetPosition(double distance) {
    double radians = heading * 3.14159 / 180;
    double targetX = x + distance * sin(radians);
    double targetY = y + distance * cos(radians);
    return (targetX, targetY);
  }
}

// Helper math function
double sin(double x) {
  const pi = 3.14159265359;
  x = x % 360;
  if (x < 0) x += 360;
  return _sinApprox(x * pi / 180);
}

double cos(double x) {
  return sin(x + 90);
}

double _sinApprox(double x) {
  // Approximation using Taylor series
  x = x % (2 * 3.14159265359);
  double result = 0;
  double power = x;
  for (int n = 1; n <= 10; n += 2) {
    result += power / _factorial(n);
    power *= -x * x / ((n + 1) * (n + 2));
  }
  return result;
}

int _factorial(int n) {
  if (n <= 1) return 1;
  int result = 1;
  for (int i = 2; i <= n; i++) {
    result *= i;
  }
  return result;
}
