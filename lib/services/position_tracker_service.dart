import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import '../models/grid_layout_model.dart';

/// Service để track vị trí user trong phòng dùng IMU + GPS
class PositionTrackerService {
  static final PositionTrackerService _instance = PositionTrackerService._internal();
  
  factory PositionTrackerService() => _instance;
  PositionTrackerService._internal();

  // Current position
  late UserPosition _currentPosition;
  
  // IMU data
  double _velocityX = 0;
  double _velocityY = 0;
  DateTime? _lastIMUUpdate;
  
  // Calibration
  double _headingOffset = 0; // Offset từ compass
  bool _isCalibrated = false;
  
  // Tracking state
  bool _isTracking = false;
  
  get currentPosition => _currentPosition;
  get isTracking => _isTracking;

  /// Initialize position tracker
  void initialize({
    required double startX,
    required double startY,
    required double startHeading,
  }) {
    _currentPosition = UserPosition(
      x: startX,
      y: startY,
      heading: startHeading,
      timestamp: DateTime.now(),
      accuracy: 0.5, // 50cm initial accuracy
    );
    _isCalibrated = false;
    _headingOffset = 0;
  }

  /// Calibrate heading from compass (e.g., user points phone North)
  void calibrateHeading(double compassHeading) {
    _headingOffset = compassHeading - _currentPosition.heading;
    _isCalibrated = true;
    print('✓ Heading calibrated. Offset: $_headingOffset°');
  }

  /// Bắt đầu track position
  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _lastIMUUpdate = DateTime.now();
    
    // Listen accelerometer
    accelerometerEvents.listen((event) {
      _handleAccelerometerData(event);
    });
    
    // Listen gyroscope untuk heading
    gyroscopeEvents.listen((event) {
      _handleGyroscopeData(event);
    });
    
    print('▶️ Position tracking started');
  }

  /// Dừng track
  void stopTracking() {
    _isTracking = false;
    _velocityX = 0;
    _velocityY = 0;
    print('⏹️ Position tracking stopped');
  }

  /// Xử lý accelerometer data
  void _handleAccelerometerData(AccelerometerEvent event) {
    if (!_isTracking) return;
    
    final now = DateTime.now();
    final deltaTime = _lastIMUUpdate != null
        ? now.difference(_lastIMUUpdate!).inMilliseconds / 1000.0
        : 0.016; // ~60Hz default
    
    _lastIMUUpdate = now;

    // Gravity threshold
    const gravityThreshold = 0.5;
    
    // Extract acceleration (remove gravity)
    double ax = event.x;
    double ay = event.y;
    
    // Simple high-pass filter
    if (ax.abs() > gravityThreshold) {
      _velocityX += ax * deltaTime;
    } else {
      _velocityX *= 0.95; // Damping
    }
    
    if (ay.abs() > gravityThreshold) {
      _velocityY += ay * deltaTime;
    } else {
      _velocityY *= 0.95;
    }

    // Update position
    double newX = _currentPosition.x + _velocityX * deltaTime;
    double newY = _currentPosition.y + _velocityY * deltaTime;

    // Apply damping to reduce drift
    _velocityX *= 0.98;
    _velocityY *= 0.98;

    _updatePosition(newX, newY, _currentPosition.heading);
  }

  /// Xử lý gyroscope data (heading)
  void _handleGyroscopeData(GyroscopeEvent event) {
    if (!_isTracking || !_isCalibrated) return;

    // Gyroscope rad/s → deg/s
    const rad2deg = 180.0 / 3.14159265359;
    
    // Z-axis rotation (yaw)
    double headingChange = event.z * rad2deg * 0.016; // ~60Hz

    double newHeading = _currentPosition.heading + headingChange;
    
    // Normalize -180 → 180
    if (newHeading > 180) newHeading -= 360;
    if (newHeading < -180) newHeading += 360;

    _updatePosition(_currentPosition.x, _currentPosition.y, newHeading);
  }

  /// Cập nhật vị trí hiện tại
  void _updatePosition(double x, double y, double heading) {
    _currentPosition = UserPosition(
      x: x,
      y: y,
      heading: heading,
      timestamp: DateTime.now(),
      accuracy: _calculateAccuracy(),
    );
  }

  /// Tính độ chính xác (giảm theo thời gian do drift)
  double _calculateAccuracy() {
    final elapsed = DateTime.now().difference(_currentPosition.timestamp).inSeconds;
    // Accuracy degrades ~5% per second
    return math.max(0.2, (0.5 - elapsed * 0.05));
  }

  /// Reset position (sau khi verify bằng camera)
  void resetPosition(double x, double y, double heading) {
    initialize(startX: x, startY: y, startHeading: heading);
    _velocityX = 0;
    _velocityY = 0;
    print('✓ Position reset: ($x, $y) heading=$heading°');
  }

  /// Lấy vị trí hiện tại (dự báo)
  UserPosition getPredictedPosition() {
    return _currentPosition;
  }

  /// Kiểm tra xem user có ở gần vị trí expected không
  bool isNearPosition(
    double targetX,
    double targetY, {
    double tolerance = 0.5, // 50cm
  }) {
    final distance = math.sqrt(
      math.pow(_currentPosition.x - targetX, 2) +
          math.pow(_currentPosition.y - targetY, 2),
    );
    return distance < tolerance;
  }

  /// Lấy hướng hiệu chỉnh tới target
  double getHeadingToTarget(double targetX, double targetY) {
    double deltaX = targetX - _currentPosition.x;
    double deltaY = targetY - _currentPosition.y;
    
    // atan2 return radians
    double angle = math.atan2(deltaX, deltaY) * 180 / 3.14159265359;
    
    // Normalize
    if (angle < 0) angle += 360;
    return angle;
  }

  /// Tính góc quay từ heading hiện tại tới target
  double getTurnAngleToTarget(double targetX, double targetY) {
    double targetHeading = getHeadingToTarget(targetX, targetY);
    double turn = targetHeading - _currentPosition.heading;
    
    // Normalize -180 → 180
    if (turn > 180) turn -= 360;
    if (turn < -180) turn += 360;
    
    return turn;
  }

  /// Kiểm tra hướng user
  String getDirectionStatus(double targetX, double targetY) {
    double turn = getTurnAngleToTarget(targetX, targetY);
    double distance = math.sqrt(
      math.pow(_currentPosition.x - targetX, 2) +
          math.pow(_currentPosition.y - targetY, 2),
    );

    // Nếu gần thì không cần báo hướng
    if (distance < 0.3) {
      return '✓ Đã tới';
    }

    // Kiểm tra hướng
    double absTurn = turn.abs();
    
    if (absTurn < 15) {
      return '→ Đi thẳng';
    } else if (turn > 0) {
      return '→ Quay phải ${absTurn.toStringAsFixed(0)}°';
    } else {
      return '← Quay trái ${absTurn.toStringAsFixed(0)}°';
    }
  }

  /// Lấy thông tin debug
  Map<String, dynamic> getDebugInfo() {
    return {
      'position': {
        'x': _currentPosition.x.toStringAsFixed(2),
        'y': _currentPosition.y.toStringAsFixed(2),
        'heading': _currentPosition.heading.toStringAsFixed(0),
      },
      'velocity': {
        'vx': _velocityX.toStringAsFixed(2),
        'vy': _velocityY.toStringAsFixed(2),
      },
      'accuracy': _currentPosition.accuracy?.toStringAsFixed(2),
      'isCalibrated': _isCalibrated,
      'isTracking': _isTracking,
    };
  }
}
