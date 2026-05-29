/// Đại diện cho một chặn đường trong lộ trình
class NavigationWaypoint {
  final int index;                    // Thứ tự waypoint (0, 1, 2,...)
  final String instruction;           // Hướng dẫn: "Quay trái 30 độ"
  final double targetX;               // Tọa độ x đích của chặn này
  final double targetZ;               // Tọa độ z đích của chặn này
  final String targetObjectName;      // Tên vật ở chặn cuối: "Cái tủ", "Cái bàn"
  final double distance;              // Khoảng cách từ current → target (meter)
  final double angle;                 // Góc quay (độ, âm = trái, dương = phải)
  final bool isCheckpoint;            // Có cần chụp ảnh để kiểm tra?

  NavigationWaypoint({
    required this.index,
    required this.instruction,
    required this.targetX,
    required this.targetZ,
    required this.targetObjectName,
    required this.distance,
    required this.angle,
    required this.isCheckpoint,
  });
}

/// Đại diện cho tuyến đường từ vật A → vật B
class NavigationRoute {
  final String startObjectName;       // Vật bắt đầu: "Cái giường"
  final double startX;
  final double startZ;
  
  final String endObjectName;         // Vật đích: "Cái bàn"
  final double endX;
  final double endZ;
  
  final List<NavigationWaypoint> waypoints;  // Danh sách các chặn đường
  final double totalDistance;         // Tổng khoảng cách (meter)
  
  int currentWaypointIndex = 0;       // Chặn hiện tại đang xử lý

  NavigationRoute({
    required this.startObjectName,
    required this.startX,
    required this.startZ,
    required this.endObjectName,
    required this.endX,
    required this.endZ,
    required this.waypoints,
    required this.totalDistance,
  });

  /// Lấy waypoint hiện tại
  NavigationWaypoint? getCurrentWaypoint() {
    if (currentWaypointIndex < waypoints.length) {
      return waypoints[currentWaypointIndex];
    }
    return null;
  }

  /// Chuyển đến waypoint tiếp theo
  bool moveToNextWaypoint() {
    if (currentWaypointIndex < waypoints.length - 1) {
      currentWaypointIndex++;
      return true;
    }
    return false;  // Đã tới đích
  }

  /// Kiểm tra xem có còn waypoint không
  bool hasMoreWaypoints() {
    return currentWaypointIndex < waypoints.length;
  }

  /// Lấy tiến độ (%)
  double getProgress() {
    if (waypoints.isEmpty) return 0;
    return ((currentWaypointIndex + 1) / waypoints.length * 100).clamp(0, 100);
  }
}

/// Kết quả xác nhận chặn đường (sau khi chụp ảnh)
enum WaypointVerificationResult {
  reached,    // Đã tới đích chặn này
  notReached, // Chưa tới, cần tiếp tục
  error,      // Lỗi trong quá trình xác nhận
}
