import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/env.dart';

class DetectionResult {
  final bool success;
  final List<Detection> detections;
  final int count;
  final String? message;

  DetectionResult({
    required this.success,
    required this.detections,
    required this.count,
    this.message,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final detectionsList = (json['detections'] as List<dynamic>?)
        ?.map((item) => Detection.fromJson(item as Map<String, dynamic>))
        .toList() ??
        [];

    return DetectionResult(
      success: json['success'] ?? false,
      detections: detectionsList,
      count: json['count'] ?? 0,
      message: json['message'],
    );
  }
}

class Detection {
  final int classId;
  final String className;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  Detection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      classId: json['class_id'] ?? 0,
      className: json['class_name'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      width: (json['width'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 0.0).toDouble(),
    );
  }
}

class DetectionService {
  static final DetectionService _instance = DetectionService._internal();

  factory DetectionService() {
    return _instance;
  }

  DetectionService._internal();

  String get _baseUrl => EnvConfig.baseUrl;

  /// Detect objects from image file
  /// 
  /// Returns [DetectionResult] with detected objects
  /// Throws [Exception] if detection fails
  Future<DetectionResult> detectFromImage(File imageFile) async {
    try {
      final uri = Uri.parse('$_baseUrl/detect');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      
      // Detect mime type từ file extension
      final mimeType = _getMimeType(imageFile.path);
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: http.MediaType.parse(mimeType),
        ),
      );

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Detection request timeout');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return DetectionResult.fromJson(jsonResponse);
      } else {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          errorJson['message'] ?? 'Detection failed with status ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Determine MIME type từ file extension
  String _getMimeType(String filePath) {
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    } else if (lowerPath.endsWith('.png')) {
      return 'image/png';
    } else if (lowerPath.endsWith('.gif')) {
      return 'image/gif';
    } else if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }
    // Default to jpeg nếu không recognize
    return 'image/jpeg';
  }

  /// Check if detection service is available
  Future<bool> isHealthy() async {
    try {
      final uri = Uri.parse('$_baseUrl/detect/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
