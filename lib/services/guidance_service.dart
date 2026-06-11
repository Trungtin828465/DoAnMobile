/// Service phân tích vị trí vật thể, khoảng cách, và hướng dẫn di chuyển

/// Chia màn hình thành 3 vùng: LEFT, CENTER, RIGHT
enum ScreenZone { left, center, right }

/// Phân loại khoảng cách
enum DistanceLevel { far, medium, near }

class GuidanceService {

  /// Phân tích vị trí vật thể trên màn hình camera
  /// Input: centerX (0-screenWidth), screenWidth
  /// Output: ScreenZone
  static ScreenZone analyzeHorizontalPosition(
    double centerX,
    double screenWidth,
  ) {
    final oneThird = screenWidth / 3;

    if (centerX < oneThird) {
      return ScreenZone.left;
    } else if (centerX > oneThird * 2) {
      return ScreenZone.right;
    } else {
      return ScreenZone.center;
    }
  }

  /// Ước lượng khoảng cách dựa trên diện tích bounding box
  /// Nguyên lý: box càng lớn = vật càng gần
  static DistanceLevel estimateDistance(
    double boxWidth,
    double boxHeight,
    double screenWidth,
    double screenHeight,
  ) {
    final boxArea = boxWidth * boxHeight;
    final screenArea = screenWidth * screenHeight;
    final boxPercentage = (boxArea / screenArea) * 100;

    // Phân loại dựa trên % diện tích màn hình
    if (boxPercentage > 25) {
      return DistanceLevel.near;
    } else if (boxPercentage > 10) {
      return DistanceLevel.medium;
    } else {
      return DistanceLevel.far;
    }
  }

  /// Chuyển ScreenZone thành text hướng dẫn
  static String getDirectionText(ScreenZone zone, String objectName) {
    switch (zone) {
      case ScreenZone.left:
        return '$objectName phía bên trái';
      case ScreenZone.right:
        return '$objectName phía bên phải';
      case ScreenZone.center:
        return '$objectName phía trước';
      default:
        return '$objectName phía trước';
    }
  }

  /// Chuyển DistanceLevel thành text
  static String getDistanceText(DistanceLevel level) {
    switch (level) {
      case DistanceLevel.near:
        return 'rất gần';
      case DistanceLevel.medium:
        return 'khoảng cách trung bình';
      case DistanceLevel.far:
        return 'khá xa';
      default:
        return 'khoảng cách trung bình';
    }
  }

  /// Tạo hướng dẫn di chuyển hoàn chỉnh
  /// Ví dụ: "Bàn phía bên phải, rất gần. Rẽ nhẹ sang phải."
  static String createMovementGuidance(
    String objectName,
    ScreenZone zone,
    DistanceLevel distance,
  ) {
    final directionText = getDirectionText(zone, objectName);
    final distanceText = getDistanceText(distance);

    String movementCommand = '';

    if (zone == ScreenZone.center) {
      if (distance == DistanceLevel.near) {
        movementCommand = 'Đi thẳng. Đã gần đến ${objectName}.';
      } else if (distance == DistanceLevel.medium) {
        movementCommand = 'Đi thẳng để đến ${objectName}.';
      } else {
        movementCommand = 'Đi thẳng.';
      }
    } else if (zone == ScreenZone.left) {
      if (distance == DistanceLevel.near) {
        movementCommand = 'Quay trái và đi. Đã gần đến ${objectName}.';
      } else {
        movementCommand = 'Rẽ sang trái.';
      }
    } else if (zone == ScreenZone.right) {
      if (distance == DistanceLevel.near) {
        movementCommand = 'Quay phải và đi. Đã gần đến ${objectName}.';
      } else {
        movementCommand = 'Rẽ sang phải.';
      }
    }

    return '$directionText, $distanceText. $movementCommand';
  }

  /// Phân tích vật cản nguy hiểm
  /// Returns: list hướng dẫn tránh vật cản
  static String? analyzeObstacles(
    List<DetectedObject> allObjects,
    String? targetObject,
    double screenWidth,
  ) {
    // Lọc vật cản nguy hiểm (stairs, person)
    final dangers = allObjects
        .where((obj) => ['stairs', 'person'].contains(obj.label))
        .toList();

    if (dangers.isEmpty) {
      return null;
    }

    final primary = dangers.first;
    final zone = analyzeHorizontalPosition(primary.centerX, screenWidth);

    if (primary.label == 'stairs') {
      switch (zone) {
        case ScreenZone.center:
          return 'Cảnh báo! Cầu thang phía trước, rất nguy hiểm.';
        case ScreenZone.left:
          return 'Cảnh báo! Cầu thang bên trái.';
        case ScreenZone.right:
          return 'Cảnh báo! Cầu thang bên phải.';
      }
    } else if (primary.label == 'person') {
      switch (zone) {
        case ScreenZone.center:
          return 'Có người phía trước.';
        case ScreenZone.left:
          return 'Có người bên trái.';
        case ScreenZone.right:
          return 'Có người bên phải.';
      }
    }

    return null;
  }

  /// Tìm hướng an toàn để tránh vật cản
  static ScreenZone? findSafeDirection(
    List<DetectedObject> allObjects,
    double screenWidth,
  ) {
    // Kiểm tra 3 vùng, vùng nào không có vật cản nguy hiểm
    final dangers = allObjects
        .where((obj) =>
            ['stairs', 'person', 'chair', 'table'].contains(obj.label) &&
            obj.confidence > 0.7)
        .toList();

    if (dangers.isEmpty) {
      return null; // Không có vật cản
    }

    final leftCount = dangers
        .where((obj) => analyzeHorizontalPosition(obj.centerX, screenWidth) ==
            ScreenZone.left)
        .length;
    final centerCount = dangers
        .where((obj) => analyzeHorizontalPosition(obj.centerX, screenWidth) ==
            ScreenZone.center)
        .length;
    final rightCount = dangers
        .where((obj) => analyzeHorizontalPosition(obj.centerX, screenWidth) ==
            ScreenZone.right)
        .length;

    // Vùng nào có ít vật cản nhất
    if (leftCount <= centerCount && leftCount <= rightCount) {
      return ScreenZone.left;
    } else if (rightCount <= centerCount && rightCount <= leftCount) {
      return ScreenZone.right;
    } else {
      return ScreenZone.center;
    }
  }

  /// Tạo hướng dẫn tránh vật cản
  static String createAvoidanceGuidance(ScreenZone safeDirection) {
    switch (safeDirection) {
      case ScreenZone.left:
        return 'Rẽ sang trái để tránh vật cản.';
      case ScreenZone.right:
        return 'Rẽ sang phải để tránh vật cản.';
      case ScreenZone.center:
        return 'Đi thẳng, đường đã an toàn.';
      default:
        return 'Đi thẳng, đường đã an toàn.';
    }
  }
}

/// Model đại diện cho một vật thể được detect
class DetectedObject {
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Tính tâm
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  /// Tính diện tích
  double get area => width * height;
}
