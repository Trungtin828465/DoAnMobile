import '../models/grid_layout_model.dart';
import 'position_tracker_service.dart';
import 'dart:math' as math;

/// GPS-based navigation service
/// Thay vì detect object, track user position liên tục
class GPSNavigationService {
  final GridLayout layout;
  final PositionTrackerService positionTracker;

  GPSNavigationService({
    required this.layout,
    required this.positionTracker,
  });

  /// Tính route từ current position → target
  GPSNavigationRoute calculateRoute(
    double targetX,
    double targetY,
    List<Furniture3D>? avoidFurnitures,
  ) {
    final currentPos = positionTracker.currentPosition;
    
    // Tính khoảng cách thẳng
    final distance = math.sqrt(
      math.pow(targetX - currentPos.x, 2) +
          math.pow(targetY - currentPos.y, 2),
    );

    // Tạo waypoints cách nhau ~1 mét
    final waypoints = <GPSWaypoint>[];
    final numWaypoints = math.max(1, (distance / 1.0).ceil());

    for (int i = 1; i <= numWaypoints; i++) {
      final progress = i / (numWaypoints + 1);
      final waypointX = currentPos.x + (targetX - currentPos.x) * progress;
      final waypointY = currentPos.y + (targetY - currentPos.y) * progress;

      // Kiểm tra collision với furniture
      bool isValid = _isValidPosition(waypointX, waypointY, avoidFurnitures);

      final waypoint = GPSWaypoint(
        index: i - 1,
        x: waypointX,
        y: waypointY,
        instruction: _generateInstruction(
          currentPos,
          waypointX,
          waypointY,
          i,
          numWaypoints,
        ),
        distance: math.sqrt(
          math.pow(waypointX - currentPos.x, 2) +
              math.pow(waypointY - currentPos.y, 2),
        ),
        angle: positionTracker.getTurnAngleToTarget(waypointX, waypointY),
        isValid: isValid,
      );

      waypoints.add(waypoint);
    }

    // Final waypoint
    waypoints.add(
      GPSWaypoint(
        index: numWaypoints,
        x: targetX,
        y: targetY,
        instruction: 'Bạn đã tới đích!',
        distance: distance,
        angle: positionTracker.getTurnAngleToTarget(targetX, targetY),
        isValid: true,
      ),
    );

    return GPSNavigationRoute(
      startX: currentPos.x,
      startY: currentPos.y,
      targetX: targetX,
      targetY: targetY,
      waypoints: waypoints,
      totalDistance: distance,
      currentWaypointIndex: 0,
    );
  }

  /// Generate hướng dẫn theo tình hình hiện tại
  String _generateInstruction(
    UserPosition currentPos,
    double waypointX,
    double waypointY,
    int waypointIndex,
    int totalWaypoints,
  ) {
    final angle = positionTracker.getTurnAngleToTarget(waypointX, waypointY);
    final distance = math.sqrt(
      math.pow(waypointX - currentPos.x, 2) +
          math.pow(waypointY - currentPos.y, 2),
    );

    String direction;
    if (angle.abs() < 15) {
      direction = 'Đi thẳng';
    } else if (angle > 0) {
      direction = 'Quay phải ${angle.toStringAsFixed(0)}°';
    } else {
      direction = 'Quay trái ${angle.abs().toStringAsFixed(0)}°';
    }

    return '$direction rồi đi ${distance.toStringAsFixed(1)}m (chặn $waypointIndex/$totalWaypoints)';
  }

  /// Kiểm tra xem vị trí có hợp lệ không (không va furniture)
  bool _isValidPosition(
    double x,
    double y,
    List<Furniture3D>? furnitures,
  ) {
    if (furnitures == null) return true;

    const buffer = 0.3; // 30cm buffer
    for (final furniture in furnitures) {
      final bbox = furniture.getBoundingBox();
      if (bbox.contains(x, y) ||
          (x >= bbox.minX - buffer &&
              x <= bbox.maxX + buffer &&
              y >= bbox.minY - buffer &&
              y <= bbox.maxY + buffer)) {
        return false;
      }
    }
    return true;
  }

  /// Kiểm tra user có near waypoint không
  bool isNearWaypoint(
    GPSWaypoint waypoint, {
    double tolerance = 0.5,
  }) {
    final currentPos = positionTracker.currentPosition;
    final distance = math.sqrt(
      math.pow(waypoint.x - currentPos.x, 2) +
          math.pow(waypoint.y - currentPos.y, 2),
    );
    return distance < tolerance;
  }

  /// Lấy hướng dẫn realtime
  String getRealtimeGuidance(GPSWaypoint currentWaypoint) {
    return positionTracker.getDirectionStatus(
      currentWaypoint.x,
      currentWaypoint.y,
    );
  }

  /// Kiểm tra xem user có quay sai hướng không
  bool isUserHeadingWrong(
    GPSWaypoint waypoint, {
    double tolerance = 45, // degree
  }) {
    final angle = positionTracker.getTurnAngleToTarget(
      waypoint.x,
      waypoint.y,
    );
    return angle.abs() > tolerance;
  }
}

/// GPS Route
class GPSNavigationRoute {
  double startX, startY;
  double targetX, targetY;
  List<GPSWaypoint> waypoints;
  double totalDistance;
  int currentWaypointIndex;

  GPSNavigationRoute({
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.waypoints,
    required this.totalDistance,
    required this.currentWaypointIndex,
  });

  GPSWaypoint? getCurrentWaypoint() {
    if (currentWaypointIndex < 0 || currentWaypointIndex >= waypoints.length) {
      return null;
    }
    return waypoints[currentWaypointIndex];
  }

  bool moveToNextWaypoint() {
    currentWaypointIndex++;
    return currentWaypointIndex < waypoints.length;
  }

  bool hasMoreWaypoints() {
    return currentWaypointIndex < waypoints.length - 1;
  }

  double getProgress() {
    return ((currentWaypointIndex + 1) / waypoints.length) * 100;
  }

  String get startObjectName => 'Điểm bắt đầu';
  String get endObjectName => 'Đích';
}

/// GPS Waypoint
class GPSWaypoint {
  int index;
  double x, y;           // Grid position (meter)
  String instruction;
  double distance;       // Distance from start
  double angle;          // Angle to turn
  bool isValid;          // Pass through furniture?

  GPSWaypoint({
    required this.index,
    required this.x,
    required this.y,
    required this.instruction,
    required this.distance,
    required this.angle,
    this.isValid = true,
  });
}
