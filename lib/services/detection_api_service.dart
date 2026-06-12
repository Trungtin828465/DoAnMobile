import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/env.dart';
import 'tflite_detection_service.dart';

class DetectionApiResult {
  final String savedImagePath;
  final List<TFLiteDetectionResult> detections;
  final String message;

  const DetectionApiResult({
    required this.savedImagePath,
    required this.detections,
    required this.message,
  });
}

class DetectionApiService {
  String get _detectUrl => '${EnvConfig.baseUrl}/detect';

  Future<DetectionApiResult> analyzeImage(
    File imageFile, {
    String? targetLabel,
  }) async {
    print('📷 Detection API: bắt đầu gửi ảnh ${imageFile.path}');
    print('🌐 Detection API: endpoint $_detectUrl');

    final request = http.MultipartRequest('POST', Uri.parse(_detectUrl));
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    if (targetLabel != null && targetLabel.isNotEmpty) {
      request.fields['target'] = targetLabel;
      print('🎯 Detection API: target = $targetLabel');
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Detection API timeout sau 30 giây');
      },
    );

    final response = await http.Response.fromStream(streamedResponse);
    print('📡 Detection API: status ${response.statusCode}');
    print('📦 Detection API: content-type ${response.headers['content-type']}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('❌ Detection API: lỗi body = ${response.body}');
      throw Exception('Detection API lỗi status ${response.statusCode}');
    }

    final savedImagePath = await _saveDetectionImage(
      response,
      fallbackImageBytes: await imageFile.readAsBytes(),
    );
    final detections = await _parseDetections(response);

    print('✅ Detection API: đã lưu ảnh phân tích tại $savedImagePath');
    print('✅ Detection API: số vật thể nhận được = ${detections.length}');

    return DetectionApiResult(
      savedImagePath: savedImagePath,
      detections: detections,
      message: 'Đã phân tích ảnh, lưu tại $savedImagePath',
    );
  }

  Future<String> _saveDetectionImage(
    http.Response response, {
    required Uint8List fallbackImageBytes,
  }) async {
    final outputDirectory = await _getDetectionDirectory();
    final fileName = 'detected_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputFile = File('${outputDirectory.path}${Platform.pathSeparator}$fileName');
    final contentType = response.headers['content-type'] ?? '';

    if (contentType.contains('image')) {
      await outputFile.writeAsBytes(response.bodyBytes);
      return outputFile.path;
    }

    if (contentType.contains('json')) {
      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final imageBytes = await _extractImageBytesFromJson(jsonBody);

      if (imageBytes != null) {
        await outputFile.writeAsBytes(imageBytes);
        return outputFile.path;
      }
    }

    print('⚠️ Detection API: response không có ảnh đã vẽ box, lưu ảnh gốc để kiểm tra');
    await outputFile.writeAsBytes(fallbackImageBytes);
    return outputFile.path;
  }

  Future<Uint8List?> _extractImageBytesFromJson(Map<String, dynamic> jsonBody) async {
    const imageKeys = [
      'annotatedImage',
      'annotated_image',
      'detectedImage',
      'detected_image',
      'resultImage',
      'result_image',
      'image',
      'output',
    ];

    for (final key in imageKeys) {
      final value = jsonBody[key];
      if (value is String && value.isNotEmpty) {
        if (value.startsWith('http')) {
          print('🌐 Detection API: tải ảnh phân tích từ URL trong field $key');
          final response = await http.get(Uri.parse(value));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          }
        }

        final base64Value = value.contains(',') ? value.split(',').last : value;
        try {
          return base64Decode(base64Value);
        } catch (_) {
          print('⚠️ Detection API: field $key không phải base64 hợp lệ');
        }
      }
    }

    return null;
  }

  Future<List<TFLiteDetectionResult>> _parseDetections(http.Response response) async {
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('json')) {
      return [];
    }

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    final rawDetections = jsonBody['detections'] ??
        jsonBody['objects'] ??
        jsonBody['result'] ??
        jsonBody['data'];

    if (rawDetections is! List) {
      return [];
    }

    return rawDetections
        .whereType<Map<String, dynamic>>()
        .map(_parseDetection)
        .whereType<TFLiteDetectionResult>()
        .toList();
  }

  TFLiteDetectionResult? _parseDetection(Map<String, dynamic> data) {
    final label = data['label'] ?? data['class'] ?? data['name'];
    if (label is! String || label.isEmpty) {
      return null;
    }

    final box = data['box'] ?? data['bbox'] ?? data['boundingBox'];
    final boxMap = box is Map<String, dynamic> ? box : data;

    return TFLiteDetectionResult(
      label: label,
      confidence: _readDouble(data['confidence'] ?? data['score'], fallback: 0),
      x: _readDouble(boxMap['x'] ?? boxMap['left'], fallback: 0),
      y: _readDouble(boxMap['y'] ?? boxMap['top'], fallback: 0),
      width: _readDouble(boxMap['width'] ?? boxMap['w'], fallback: 0),
      height: _readDouble(boxMap['height'] ?? boxMap['h'], fallback: 0),
    );
  }

  double _readDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<Directory> _getDetectionDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final detectionDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}detec',
    );

    if (!await detectionDirectory.exists()) {
      await detectionDirectory.create(recursive: true);
      print('📁 Detection API: đã tạo thư mục ${detectionDirectory.path}');
    }

    return detectionDirectory;
  }
}
