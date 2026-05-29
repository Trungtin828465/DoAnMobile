import 'package:flutter/material.dart';
import '../models/grid_layout_model.dart';
import '../services/gps_navigation_service.dart';
import '../services/position_tracker_service.dart';
import '../widgets/grid_layout_visualizer.dart';

/// Screen hiển thị GPS-based navigation realtime
class GPSNavigationScreen extends StatefulWidget {
  final GridLayout layout;
  final double targetX;
  final double targetY;

  const GPSNavigationScreen({
    Key? key,
    required this.layout,
    required this.targetX,
    required this.targetY,
  }) : super(key: key);

  @override
  State<GPSNavigationScreen> createState() => _GPSNavigationScreenState();
}

class _GPSNavigationScreenState extends State<GPSNavigationScreen> {
  late PositionTrackerService _positionTracker;
  late GPSNavigationService _navigationService;
  late GPSNavigationRoute _route;
  int _currentWaypointIndex = 0;
  bool _isHeadingWrong = false;

  @override
  void initState() {
    super.initState();
    _positionTracker = PositionTrackerService();
    _navigationService = GPSNavigationService(
      layout: widget.layout,
      positionTracker: _positionTracker,
    );

    // Initialize position
    _positionTracker.initialize(startX: 1.0, startY: 1.0, startHeading: 0);
    
    // Calculate route
    _route = _navigationService.calculateRoute(
      widget.targetX,
      widget.targetY,
      widget.layout.furnitures,
    );

    // Start tracking
    _positionTracker.startTracking();
    
    // Show calibration dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCalibrationDialog();
    });
  }

  void _showCalibrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Hiệu chuẩn hướng'),
        content: const Text(
          'Hãy chỉ điều hướng của điện thoại về phía bắc (0°) và bấm OK',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _positionTracker.calibrateHeading(0);
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionTracker.stopTracking();
    super.dispose();
  }

  void _updateWaypoint() {
    final currentWaypoint = _route.getCurrentWaypoint();
    if (currentWaypoint == null) {
      // Navigation complete
      _navigationComplete();
      return;
    }

    // Check if near current waypoint
    if (_navigationService.isNearWaypoint(currentWaypoint)) {
      if (_route.moveToNextWaypoint()) {
        setState(() {
          _currentWaypointIndex = _route.currentWaypointIndex;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Chặn ${_currentWaypointIndex + 1} đã tới!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // Check heading
    final isHeadingWrong = _navigationService.isUserHeadingWrong(
      currentWaypoint,
      tolerance: 45,
    );
    
    if (isHeadingWrong != _isHeadingWrong) {
      setState(() => _isHeadingWrong = isHeadingWrong);
      
      if (isHeadingWrong) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Bạn quay sai hướng! Hãy điều chỉnh'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _navigationComplete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 Hoàn thành!'),
        content: const Text('Bạn đã tới đích!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWaypoint = _route.getCurrentWaypoint();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Hướng Dẫn'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 3D Layout with user position
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: StreamBuilder<void>(
                stream: Stream.periodic(const Duration(milliseconds: 500)),
                builder: (ctx, snapshot) {
                  _updateWaypoint();
                  
                  return GridLayoutVisualizer(
                    layout: widget.layout,
                    userPosition: _positionTracker.currentPosition,
                    zoomLevel: 1.2,
                    showGrid: true,
                    showFurniture: true,
                    highlightColor: currentWaypoint != null
                        ? (_isHeadingWrong
                            ? Colors.orange
                            : Colors.green)
                        : null,
                    highlightPosition: currentWaypoint != null
                        ? Offset(currentWaypoint.x, currentWaypoint.y)
                        : null,
                  );
                },
              ),
            ),
          ),

          // Navigation info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current waypoint info
                if (currentWaypoint != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chặn ${_route.currentWaypointIndex + 1}/${_route.waypoints.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentWaypoint.instruction,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isHeadingWrong ? Colors.orange : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Khoảng cách: ${currentWaypoint.distance.toStringAsFixed(1)}m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Góc: ${currentWaypoint.angle.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Real-time guidance
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<void>(
                stream: Stream.periodic(const Duration(milliseconds: 500)),
                builder: (ctx, snapshot) {
                  if (currentWaypoint == null) {
                    return const Center(
                      child: Text(
                        '✓ Hoàn thành!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    );
                  }

                  final guidance = _navigationService.getRealtimeGuidance(
                    currentWaypoint,
                  );
                  
                  final debugInfo = _positionTracker.getDebugInfo();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Guidance
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isHeadingWrong
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hướng dẫn thời gian thực:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guidance,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isHeadingWrong
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Debug info
                      Text(
                        'Vị trí: (${(debugInfo['position']['x'] as String).padRight(5)}, ${(debugInfo['position']['y'] as String).padRight(5)}) m',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        'Hướng: ${debugInfo['position']['heading']}° | Độ chính xác: ${debugInfo['accuracy']} m',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Reset position (after verify)
                      _positionTracker.resetPosition(1.0, 1.0, 0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Xác nhận vị trí'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
