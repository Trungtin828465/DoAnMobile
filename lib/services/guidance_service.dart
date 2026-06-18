/// Service phân tích vị trí vật thể, khoảng cách và hướng dẫn di chuyển.

enum ScreenZone { left, center, right }

enum DistanceLevel { far, medium, near }

class GuidanceService {
  static const double reliableDetectionThreshold = 0.4;

  static const List<String> modelClasses = [
    'bed',
    'sofa',
    'chair',
    'table',
    'wardrobe',
    'refrigerator',
    'tv',
    'door',
    'window',
    'fan',
    'laptop',
    'washing_machine',
  ];

  static const List<String> obstacleClasses = [
    'bed',
    'sofa',
    'chair',
    'table',
    'wardrobe',
    'refrigerator',
    'door',
    'fan',
    'washing_machine',
  ];

  static const Map<String, String> vietnameseNames = {
    'bed': 'giường',
    'sofa': 'sofa',
    'chair': 'ghế',
    'table': 'bàn',
    'wardrobe': 'tủ',
    'refrigerator': 'tủ lạnh',
    'tv': 'tivi',
    'door': 'cửa',
    'window': 'cửa sổ',
    'fan': 'quạt',
    'laptop': 'laptop',
    'washing_machine': 'máy giặt',
  };

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

  static DistanceLevel estimateDistance(
    double boxWidth,
    double boxHeight,
    double screenWidth,
    double screenHeight,
  ) {
    final boxArea = boxWidth * boxHeight;
    final screenArea = screenWidth * screenHeight;
    final boxPercentage = (boxArea / screenArea) * 100;

    if (boxPercentage > 25) {
      return DistanceLevel.near;
    } else if (boxPercentage > 10) {
      return DistanceLevel.medium;
    } else {
      return DistanceLevel.far;
    }
  }

  static String getDirectionText(ScreenZone zone, String objectName) {
    switch (zone) {
      case ScreenZone.left:
        return '$objectName phía bên trái';
      case ScreenZone.right:
        return '$objectName phía bên phải';
      case ScreenZone.center:
        return '$objectName phía trước';
    }
  }

  static String getDistanceText(DistanceLevel level) {
    switch (level) {
      case DistanceLevel.near:
        return 'rất gần';
      case DistanceLevel.medium:
        return 'khoảng cách trung bình';
      case DistanceLevel.far:
        return 'khá xa';
    }
  }

  static String createMovementGuidance(
    String objectName,
    ScreenZone zone,
    DistanceLevel distance,
  ) {
    final directionText = getDirectionText(zone, objectName);
    final distanceText = getDistanceText(distance);

    final movementCommand = switch ((zone, distance)) {
      (ScreenZone.center, DistanceLevel.near) =>
        'Đi thẳng thật chậm. Vật đã gần, hãy đưa tay ra phía trước để dò.',
      (ScreenZone.center, DistanceLevel.medium) =>
        'Đi thẳng từng bước nhỏ để đến gần vật.',
      (ScreenZone.center, DistanceLevel.far) =>
        'Giữ hướng hiện tại và đi thẳng chậm.',
      (ScreenZone.left, DistanceLevel.near) =>
        'Xoay nhẹ sang trái. Vật đã gần, chưa bước nhanh.',
      (ScreenZone.left, _) => 'Xoay nhẹ sang trái để đưa vật vào giữa khung hình.',
      (ScreenZone.right, DistanceLevel.near) =>
        'Xoay nhẹ sang phải. Vật đã gần, chưa bước nhanh.',
      (ScreenZone.right, _) => 'Xoay nhẹ sang phải để đưa vật vào giữa khung hình.',
    };

    return '$directionText, $distanceText. $movementCommand';
  }

  static String? analyzeObstacles(
    List<DetectedObject> allObjects,
    String? targetObject,
    double screenWidth,
  ) {
    final obstacles = allObjects
        .where((obj) =>
            obstacleClasses.contains(obj.label) &&
            obj.label != targetObject &&
            obj.confidence > reliableDetectionThreshold)
        .toList();

    if (obstacles.isEmpty) {
      return null;
    }

    obstacles.sort((a, b) => b.confidence.compareTo(a.confidence));
    final primary = obstacles.first;
    final zone = analyzeHorizontalPosition(primary.centerX, screenWidth);
    final objectName = vietnameseNames[primary.label] ?? primary.label;

    switch (zone) {
      case ScreenZone.center:
        return 'Cảnh báo, phía trước có $objectName có thể cản đường. Hãy đi chậm và đưa tay ra phía trước để dò.';
      case ScreenZone.left:
        return 'Cảnh báo, bên trái có $objectName. Hãy giữ khoảng cách an toàn.';
      case ScreenZone.right:
        return 'Cảnh báo, bên phải có $objectName. Hãy giữ khoảng cách an toàn.';
    }
  }

  static ScreenZone? findSafeDirection(
    List<DetectedObject> allObjects,
    double screenWidth,
  ) {
    final obstacles = allObjects
        .where((obj) =>
            obstacleClasses.contains(obj.label) &&
            obj.confidence > reliableDetectionThreshold)
        .toList();

    if (obstacles.isEmpty) {
      return null;
    }

    final leftCount = obstacles
        .where((obj) =>
            analyzeHorizontalPosition(obj.centerX, screenWidth) ==
            ScreenZone.left)
        .length;
    final centerCount = obstacles
        .where((obj) =>
            analyzeHorizontalPosition(obj.centerX, screenWidth) ==
            ScreenZone.center)
        .length;
    final rightCount = obstacles
        .where((obj) =>
            analyzeHorizontalPosition(obj.centerX, screenWidth) ==
            ScreenZone.right)
        .length;

    if (leftCount <= centerCount && leftCount <= rightCount) {
      return ScreenZone.left;
    } else if (rightCount <= centerCount && rightCount <= leftCount) {
      return ScreenZone.right;
    } else {
      return ScreenZone.center;
    }
  }

  static String createAvoidanceGuidance(ScreenZone safeDirection) {
    switch (safeDirection) {
      case ScreenZone.left:
        return 'Lối bên trái đang ít vật cản hơn. Hãy nghiêng nhẹ sang trái và đi chậm.';
      case ScreenZone.right:
        return 'Lối bên phải đang ít vật cản hơn. Hãy nghiêng nhẹ sang phải và đi chậm.';
      case ScreenZone.center:
        return 'Phía trước đang ít vật cản hơn. Hãy đi thẳng thật chậm.';
    }
  }
}

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

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  double get area => width * height;
}
