import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

class DetectionResult {
  final int classId;
  final String className;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  DetectionResult({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() {
    return 'DetectionResult(classId=$classId, className=$className, confidence=${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

class ObjectDetectionService {
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

  /// Get detection server URL (port 5000)
  static String get _detectServerUrl {
    // Parse baseUrl to get host and port
    // baseUrl format: http://192.168.1.3:3000/api
    try {
      final baseUrl = EnvConfig.baseUrl;
      final uri = Uri.parse(baseUrl);
      final host = uri.host;
      // Use port 5000 for detection server
      return 'http://$host:5000';
    } catch (e) {
      debugPrint('⚠️ Failed to parse baseUrl: $e');
      return 'http://localhost:5000';
    }
  }

  static const Duration requestTimeout = Duration(seconds: 60);
  static const double confidenceThreshold = 0.5;

  /// Initialize - không cần gì, backend tự handle
  static Future<bool> initialize() async {
    debugPrint('✓ ObjectDetectionService: Backend ready at $_detectServerUrl');
    return true;
  }

  /// Detect objects từ image bytes - gọi backend API
  /// POST /detect với image file
  static Future<List<DetectionResult>> detectFromImageBytes(
    Uint8List imageBytes,
  ) async {
    try {
      debugPrint('🔄 ObjectDetectionService: Gửi ảnh tới backend...');

      final uri = Uri.parse('$_detectServerUrl/detect');
      debugPrint('📤 Posting to: $uri');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'detection_image.jpg',
        ),
      );

      // Set timeout
      final streamedResponse = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('✓ Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final detections = _parseBackendResponse(data);

        debugPrint('✅ ObjectDetectionService: Phát hiện ${detections.length} vật');
        for (final det in detections) {
          debugPrint('  → $det');
        }

        return detections;
      } else {
        debugPrint('❌ Backend error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return [];
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ ObjectDetectionService - Connection error: $_detectServerUrl');
      debugPrint('Chi tiết: $e');
      debugPrint('⚠️ Backend không hoạt động. Kiểm tra:');
      debugPrint('   1. Backend Flask có chạy trên $_detectServerUrl?');
      debugPrint('   2. Endpoint POST /detect có tồn tại?');
      debugPrint('   3. Model file có tồn tại: model/best.pt?');
      return [];
    } catch (e) {
      debugPrint('❌ ObjectDetectionService: Lỗi detection: $e');
      return [];
    }
  }

  /// Parse backend response
  /// Expected format: {
  ///   "success": true,
  ///   "detections": [
  ///     {
  ///       "class_id": 0,
  ///       "class_name": "bed",
  ///       "confidence": 0.95,
  ///       "x": 100.5,
  ///       "y": 150.2,
  ///       "width": 300.0,
  ///       "height": 250.0
  ///     },
  ///     ...
  ///   ]
  /// }
  static List<DetectionResult> _parseBackendResponse(Map<String, dynamic> data) {
    List<DetectionResult> results = [];

    try {
      if (data['success'] != true) {
        debugPrint('⚠️ Backend returned success=false');
        return results;
      }

      final detections = (data['detections'] as List?) ?? [];

      for (final det in detections) {
        try {
          int classId = (det['class_id'] as num?)?.toInt() ?? 0;
          String className = (det['class_name'] as String?) ?? '';
          double confidence = (det['confidence'] as num?)?.toDouble() ?? 0.0;
          double x = (det['x'] as num?)?.toDouble() ?? 0.0;
          double y = (det['y'] as num?)?.toDouble() ?? 0.0;
          double width = (det['width'] as num?)?.toDouble() ?? 0.0;
          double height = (det['height'] as num?)?.toDouble() ?? 0.0;

          // Filter by confidence
          if (confidence < confidenceThreshold) continue;

          // Validate class
          if (classId < 0 || classId >= classNames.length) {
            debugPrint('⚠️ Invalid class_id: $classId');
            continue;
          }

          results.add(
            DetectionResult(
              classId: classId,
              className: className.isEmpty ? classNames[classId] : className,
              confidence: confidence,
              x: x,
              y: y,
              width: width,
              height: height,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ Error parsing detection: $e');
          continue;
        }
      }

      // Sort by confidence
      results.sort((a, b) => b.confidence.compareTo(a.confidence));

      return results;
    } catch (e) {
      debugPrint('❌ Error parsing backend response: $e');
      return results;
    }
  }

  /// Dispose - không cần
  static Future<void> dispose() async {
    debugPrint('🛑 ObjectDetectionService: Disposed');
  }
}
