import 'dart:math' as math;
import '../models/layout_model.dart';
import '../models/navigation_model.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();

  factory NavigationService() {
    return _instance;
  }

  NavigationService._internal();

  /// Furniture class names cho detection
  static const List<String> furnitureClasses = [
    'bed',           // 0
    'sofa',          // 1
    'chair',         // 2
    'table',         // 3
    'lamp',          // 4
    'tv',            // 5
    'laptop',        // 6
    'wardrobe',      // 7
    'window',        // 8
    'door',          // 9
    'potted plant',  // 10
    'photo frame',   // 11
  ];

  /// Tính khoảng cách 2D giữa 2 điểm (x, z)
  double _calculateDistance(double x1, double z1, double x2, double z2) {
    return math.sqrt(math.pow(x2 - x1, 2) + math.pow(z2 - z1, 2));
  }

  /// Tính góc quay từ điểm A → điểm B (theo độ)
  /// Dương = quay phải, âm = quay trái
  /// 0° = hướng bắc (+Z), 90° = hướng đông (+X), 180° = hướng nam (-Z), 270° = hướng tây (-X)
  double _calculateAngle(
    double fromX,
    double fromZ,
    double toX,
    double toZ,
  ) {
    double deltaX = toX - fromX;
    double deltaZ = toZ - fromZ;

    // Tính góc từ (+Z) counter-clockwise
    double angleRad = math.atan2(deltaX, deltaZ);
    double angleDeg = angleRad * 180 / math.pi;

    // Normalize về -180 → 180
    if (angleDeg > 180) {
      angleDeg -= 360;
    } else if (angleDeg < -180) {
      angleDeg += 360;
    }

    return angleDeg;
  }

  /// Tạo hướng dẫn text từ góc quay (unused - keep for reference)
  // String _createTurnInstruction(double angle, String nextObjectName) {
  //   String direction = '';
  //   double absAngle = angle.abs();

  //   if (absAngle < 10) {
  //     direction = 'Đi thẳng';
  //   } else if (angle > 0) {
  //     if (absAngle < 30) {
  //       direction = 'Quay phải ${absAngle.toStringAsFixed(0)}°';
  //     } else if (absAngle < 90) {
  //       direction = 'Quay phải ${absAngle.toStringAsFixed(0)}°';
  //     } else {
  //       direction = 'Quay phải (gần quay lại)';
  //     }
  //   } else {
  //     if (absAngle < 30) {
  //       direction = 'Quay trái ${absAngle.toStringAsFixed(0)}°';
  //     } else if (absAngle < 90) {
  //       direction = 'Quay trái ${absAngle.toStringAsFixed(0)}°';
  //     } else {
  //       direction = 'Quay trái (gần quay lại)';
  //     }
  //   }

  //   return '$direction rồi đi khoảng ${(_calculateDistance(0, 0, 0, 1) * 1).toStringAsFixed(1)}m đến $nextObjectName';
  // }

  /// Tính toán route từ vật A → vật B
  /// [currentObject]: LayoutObject hiện tại (được detect)
  /// [targetObject]: LayoutObject đích (user nhập)
  /// [allObjects]: Danh sách tất cả objects trong room
  Future<NavigationRoute> calculateRoute(
    LayoutObject currentObject,
    LayoutObject targetObject,
    List<LayoutObject> allObjects,
  ) async {
    // Tọa độ bắt đầu
    double startX = currentObject.position.x;
    double startZ = currentObject.position.z;

    // Tọa độ đích
    double endX = targetObject.position.x;
    double endZ = targetObject.position.z;

    // Khoảng cách tổng
    double totalDistance = _calculateDistance(startX, startZ, endX, endZ);

    // Nếu rất gần, không cần waypoint
    if (totalDistance < 0.5) {
      return NavigationRoute(
        startObjectName: currentObject.className,
        startX: startX,
        startZ: startZ,
        endObjectName: targetObject.className,
        endX: endX,
        endZ: endZ,
        waypoints: [
          NavigationWaypoint(
            index: 0,
            instruction: 'Bạn đã ở đích rồi!',
            targetX: endX,
            targetZ: endZ,
            targetObjectName: targetObject.className,
            distance: 0,
            angle: 0,
            isCheckpoint: true,
          ),
        ],
        totalDistance: totalDistance,
      );
    }

    // Tạo waypoints dựa trên khoảng cách
    List<NavigationWaypoint> waypoints = [];
    double distancePerWaypoint = 3.0; // Mỗi chặn ~3m
    int numWaypoints =
        (totalDistance / distancePerWaypoint).ceil().clamp(1, 10);

    // Tạo intermediate waypoints
    for (int i = 1; i <= numWaypoints; i++) {
      double progress = i / (numWaypoints + 1);
      double interpX = startX + (endX - startX) * progress;
      double interpZ = startZ + (endZ - startZ) * progress;

      // Góc quay từ current position
      double angle = i == 1
          ? _calculateAngle(startX, startZ, interpX, interpZ)
          : _calculateAngle(
              (i - 1 == 0 ? startX : startX + (endX - startX) * (i - 1) / (numWaypoints + 1)),
              (i - 1 == 0 ? startZ : startZ + (endZ - startZ) * (i - 1) / (numWaypoints + 1)),
              interpX,
              interpZ,
            );

      double distance = _calculateDistance(startX, startZ, interpX, interpZ);

      String instruction =
          'Chặn ${i}: Quay ${angle > 0 ? 'phải' : 'trái'} ${angle.abs().toStringAsFixed(0)}° rồi đi khoảng 3m';

      waypoints.add(
        NavigationWaypoint(
          index: i - 1,
          instruction: instruction,
          targetX: interpX,
          targetZ: interpZ,
          targetObjectName: i == numWaypoints
              ? targetObject.className
              : 'Chặn dừng ${i}',
          distance: distance,
          angle: angle,
          isCheckpoint: true,
        ),
      );
    }

    // Waypoint cuối cùng là đích
    double finalAngle = _calculateAngle(
      startX + (endX - startX) * (numWaypoints / (numWaypoints + 1)),
      startZ + (endZ - startZ) * (numWaypoints / (numWaypoints + 1)),
      endX,
      endZ,
    );

    waypoints.add(
      NavigationWaypoint(
        index: numWaypoints,
        instruction:
            'Chặn cuối: Quay ${finalAngle > 0 ? 'phải' : 'trái'} ${finalAngle.abs().toStringAsFixed(0)}° rồi đi ${((totalDistance * (1 / (numWaypoints + 1))).abs()).toStringAsFixed(1)}m đến ${targetObject.className}',
        targetX: endX,
        targetZ: endZ,
        targetObjectName: targetObject.className,
        distance: totalDistance,
        angle: finalAngle,
        isCheckpoint: true,
      ),
    );

    return NavigationRoute(
      startObjectName: currentObject.className,
      startX: startX,
      startZ: startZ,
      endObjectName: targetObject.className,
      endX: endX,
      endZ: endZ,
      waypoints: waypoints,
      totalDistance: totalDistance,
    );
  }

  /// Tìm object theo class name
  LayoutObject? findObjectByClassName(
    List<LayoutObject> objects,
    String className,
  ) {
    try {
      return objects.firstWhere(
        (obj) => obj.className.toLowerCase() == className.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Kiểm tra xem detected object có trong layout không
  /// Trả về list matching objects
  List<LayoutObject> findMatchingLayoutObjects(
    List<LayoutObject> layoutObjects,
    String detectedClassName,
  ) {
    return layoutObjects
        .where((obj) =>
            obj.className.toLowerCase() ==
            detectedClassName.toLowerCase())
        .toList();
  }

  /// Xác nhận waypoint (kiểm tra tại chỗ)
  /// Dùng detection để kiểm tra xem user đã tới waypoint target chưa
  bool verifyWaypoint(
    NavigationWaypoint waypoint,
    List<String> detectedObjects,
    double currentUserX,
    double currentUserZ,
  ) {
    // Kiểm tra xem có detected object matching target không
    bool foundTarget = detectedObjects.any(
      (detected) =>
          detected.toLowerCase() ==
          waypoint.targetObjectName.toLowerCase(),
    );

    // Kiểm tra xem user position có gần target không (tolerance: 0.5m)
    double distanceToWaypoint = _calculateDistance(
      currentUserX,
      currentUserZ,
      waypoint.targetX,
      waypoint.targetZ,
    );

    // Coi như tới nếu: found target OR gần vị trí theo tọa độ
    return foundTarget || distanceToWaypoint < 0.5;
  }
}
