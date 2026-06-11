/// Service xử lý object detection bằng YOLOv8 TFLite (local)
/// Dùng package tflite_flutter để load model và chạy inference

import 'dart:typed_data';
import 'package:image/image.dart' as img;

class TFLiteDetectionResult {
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  TFLiteDetectionResult({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Tính toán tâm bounding box
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  /// Tính toán diện tích
  double get area => width * height;

  @override
  String toString() {
    return '$label (${(confidence * 100).toStringAsFixed(1)}%) at ($x, $y) ${width}x$height';
  }
}

class TFLiteDetectionService {
  static final TFLiteDetectionService _instance = TFLiteDetectionService._internal();

  factory TFLiteDetectionService() {
    return _instance;
  }

  TFLiteDetectionService._internal();

  bool _isInitialized = false;
  List<TFLiteDetectionResult> _lastDetections = [];
  static const double confidenceThreshold = 0.5;

  /// YOLO class names (12 classes từ best.pt)
  static const List<String> classNames = [
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

  /// Khởi tạo model TFLite
  Future<void> initialize() async {
    try {
      // TODO: Tải model từ model/best.tflite
      // Hiện tại model/best.pt cần được convert sang .tflite format
      // Command để convert:
      // yolo export model=best.pt format=tflite int8
      
      // await Tflite.loadModel(
      //   model: 'assets/models/best.tflite',
      //   labels: 'assets/models/best_labels.txt',
      // );
      
      _isInitialized = true;
      print('[TFLiteDetectionService] ✓ Model initialized');
    } catch (e) {
      print('[TFLiteDetectionService] ✗ Init error: $e');
      rethrow;
    }
  }

  /// Detect objects từ image bytes
  Future<List<TFLiteDetectionResult>> detect(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw Exception('Model not initialized');
    }

    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return [];
      }

      // Resize ảnh xuống 416x416 (hoặc 320x320) để xử lý nhanh
      final resized = img.copyResize(
        image,
        width: 416,
        height: 416,
      );

      // TODO: Chạy TFLite inference
      // var recognitions = await Tflite.detectObjectOnImage(
      //   path: imagePath,
      //   model: "yolov8",
      //   imageMean: 0.0,
      //   imageStd: 255.0,
      //   threshold: confidenceThreshold,
      //   numResultsPerClass: 3,
      // );

      // Hiện tại dùng mock để test
      final detections = _mockDetect(resized);

      _lastDetections = detections;
      return detections;
    } catch (e) {
      print('[TFLiteDetectionService] Detect error: $e');
      return [];
    }
  }

  /// Mock detection - placeholder
  List<TFLiteDetectionResult> _mockDetect(img.Image image) {
    // Simulate detecting vài objects trong frame
    return [
      TFLiteDetectionResult(
        label: 'chair',
        confidence: 0.92,
        x: 50.0,
        y: 100.0,
        width: 150.0,
        height: 200.0,
      ),
      TFLiteDetectionResult(
        label: 'table',
        confidence: 0.85,
        x: 250.0,
        y: 120.0,
        width: 200.0,
        height: 150.0,
      ),
    ];
  }

  /// Lấy detection cuối cùng
  List<TFLiteDetectionResult> get lastDetections => _lastDetections;

  /// Lấy object có confidence cao nhất của một class
  TFLiteDetectionResult? getHighestConfidenceObject(String label) {
    try {
      final filtered = _lastDetections
          .where((d) => d.label == label)
          .where((d) => d.confidence >= confidenceThreshold)
          .toList();

      if (filtered.isEmpty) return null;
      return filtered.reduce((a, b) => a.confidence > b.confidence ? a : b);
    } catch (e) {
      return null;
    }
  }

  /// Lấy tất cả objects
  List<TFLiteDetectionResult> getObjectsByLabel(String label) {
    return _lastDetections
        .where((d) => d.label == label)
        .where((d) => d.confidence >= confidenceThreshold)
        .toList();
  }

  /// Sắp xếp objects theo khoảng cách (lớn = gần)
  List<TFLiteDetectionResult> sortByDistance() {
    final sorted = [..._lastDetections];
    sorted.sort((a, b) => b.area.compareTo(a.area));
    return sorted;
  }

  /// Dispose
  void dispose() {
    _isInitialized = false;
    _lastDetections = [];
  }
}
