import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

const List<String> detectionClasses = [
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

class TFLiteDetectionResult {
  final int classId;
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  TFLiteDetectionResult({
    required this.classId,
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

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'class_name': label,
      'confidence': confidence,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() {
    return '$label (${(confidence * 100).toStringAsFixed(1)}%) at ($x, $y) ${width}x$height';
  }
}

class TFLiteDetectionResponse {
  final bool success;
  final List<TFLiteDetectionResult> detections;
  final int count;
  final String annotatedImagePath;
  final int imageWidth;
  final int imageHeight;

  const TFLiteDetectionResponse({
    required this.success,
    required this.detections,
    required this.count,
    required this.annotatedImagePath,
    required this.imageWidth,
    required this.imageHeight,
  });

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'detections': detections.map((detection) => detection.toJson()).toList(),
      'count': count,
    };
  }
}

class TFLiteDetectionService {
  static final TFLiteDetectionService _instance =
      TFLiteDetectionService._internal();

  factory TFLiteDetectionService() {
    return _instance;
  }

  TFLiteDetectionService._internal();

  static const String modelAssetPath = 'assets/models/best.tflite';
  static const double confidenceThreshold = 0.1;
  static const double iouThreshold = 0.45;
  static const int maxInputDimension = 1280;
  static const List<String> classNames = detectionClasses;

  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<TFLiteDetectionResult> _lastDetections = [];
  int _inputWidth = 640;
  int _inputHeight = 640;
  String _inputTypeName = 'float32';

  bool get isInitialized => _isInitialized;
  List<TFLiteDetectionResult> get lastDetections => _lastDetections;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🤖 TFLite: đang load model $modelAssetPath');
      _interpreter = await Interpreter.fromAsset(modelAssetPath);

      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;
      _inputTypeName = inputTensor.type.toString().toLowerCase();

      if (inputShape.length == 4) {
        _inputHeight = inputShape[1];
        _inputWidth = inputShape[2];
      }

      _isInitialized = true;
      print('✅ TFLite: load model thành công');
      print('ℹ️ TFLite: input shape=$inputShape, type=$_inputTypeName');
      print('ℹ️ TFLite: output shape=${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      _interpreter?.close();
      _interpreter = null;
      _isInitialized = false;
      print('❌ TFLite: không load được model best.tflite');
      print('💡 TFLite: hãy đặt file tại assets/models/best.tflite');
      print('❌ TFLite: lỗi chi tiết: $e');
      rethrow;
    }
  }

  Future<TFLiteDetectionResponse> detectImageFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return detectImageBytes(bytes);
  }

  Future<TFLiteDetectionResponse> detectImageBytes(Uint8List bytes) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('TFLite chưa sẵn sàng, cần assets/models/best.tflite');
    }

    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Không decode được ảnh đầu vào');
    }

    final sourceImage = _resizeForDemo(original);
    final modelImage = img.copyResize(
      sourceImage,
      width: _inputWidth,
      height: _inputHeight,
    );
    final input = _buildInput(modelImage);
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final output = _createNestedList(outputShape);

    print('🔎 TFLite: bắt đầu detect ảnh ${sourceImage.width}x${sourceImage.height}');
    _interpreter!.run(input, output);

    final rawDetections = _parseOutput(
      output,
      outputShape,
      imageWidth: sourceImage.width,
      imageHeight: sourceImage.height,
    );
    final detections = _applyNms(rawDetections);
    final annotatedPath = await _saveAnnotatedImage(sourceImage, detections);

    _lastDetections = detections;
    print('✅ TFLite: detect xong, count=${detections.length}');
    print('📁 TFLite: ảnh đã vẽ box: $annotatedPath');

    return TFLiteDetectionResponse(
      success: true,
      detections: detections,
      count: detections.length,
      annotatedImagePath: annotatedPath,
      imageWidth: sourceImage.width,
      imageHeight: sourceImage.height,
    );
  }

  Object _buildInput(img.Image image) {
    return [
      List.generate(_inputHeight, (y) {
        return List.generate(_inputWidth, (x) {
          final pixel = image.getPixel(x, y);
          if (_inputTypeName.contains('uint8')) {
            return [
              pixel.r.toInt(),
              pixel.g.toInt(),
              pixel.b.toInt(),
            ];
          }

          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        });
      }),
    ];
  }

  Object _createNestedList(List<int> shape) {
    if (shape.length == 1) {
      return List<double>.filled(shape.first, 0);
    }

    return List.generate(
      shape.first,
      (_) => _createNestedList(shape.sublist(1)),
    );
  }

  List<TFLiteDetectionResult> _parseOutput(
    Object output,
    List<int> shape, {
    required int imageWidth,
    required int imageHeight,
  }) {
    final flat = <double>[];
    _flattenOutput(output, flat);

    if (shape.length < 3 || flat.isEmpty) {
      print('⚠️ TFLite: output shape chưa hỗ trợ: $shape');
      return [];
    }

    final dim1 = shape[1];
    final dim2 = shape[2];
    final yoloChannelsWithoutObjectness = detectionClasses.length + 4;
    final yoloChannelsWithObjectness = detectionClasses.length + 5;

    if (dim1 == yoloChannelsWithoutObjectness ||
        dim1 == yoloChannelsWithObjectness) {
      return _parseYoloChannelFirst(
        flat,
        channels: dim1,
        boxes: dim2,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    if (dim2 == yoloChannelsWithoutObjectness ||
        dim2 == yoloChannelsWithObjectness) {
      return _parseYoloChannelLast(
        flat,
        boxes: dim1,
        channels: dim2,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    if (dim2 == 6 || dim2 == 7) {
      return _parseAlreadyNmsOutput(
        flat,
        boxes: dim1,
        channels: dim2,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    print('⚠️ TFLite: chưa nhận dạng được output shape $shape');
    return [];
  }

  List<TFLiteDetectionResult> _parseYoloChannelFirst(
    List<double> flat, {
    required int channels,
    required int boxes,
    required int imageWidth,
    required int imageHeight,
  }) {
    final detections = <TFLiteDetectionResult>[];
    final hasObjectness = channels == detectionClasses.length + 5;
    final classOffset = hasObjectness ? 5 : 4;

    for (var boxIndex = 0; boxIndex < boxes; boxIndex++) {
      final cx = flat[boxIndex];
      final cy = flat[boxes + boxIndex];
      final width = flat[boxes * 2 + boxIndex];
      final height = flat[boxes * 3 + boxIndex];
      final objectness = hasObjectness ? flat[boxes * 4 + boxIndex] : 1.0;

      var bestClassId = -1;
      var bestScore = 0.0;
      for (var classId = 0; classId < detectionClasses.length; classId++) {
        final classScore = flat[boxes * (classOffset + classId) + boxIndex];
        final score = classScore * objectness;
        if (score > bestScore) {
          bestScore = score;
          bestClassId = classId;
        }
      }

      _addYoloDetection(
        detections,
        classId: bestClassId,
        score: bestScore,
        cx: cx,
        cy: cy,
        width: width,
        height: height,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    return detections;
  }

  List<TFLiteDetectionResult> _parseYoloChannelLast(
    List<double> flat, {
    required int boxes,
    required int channels,
    required int imageWidth,
    required int imageHeight,
  }) {
    final detections = <TFLiteDetectionResult>[];
    final hasObjectness = channels == detectionClasses.length + 5;
    final classOffset = hasObjectness ? 5 : 4;

    for (var boxIndex = 0; boxIndex < boxes; boxIndex++) {
      final offset = boxIndex * channels;
      final cx = flat[offset];
      final cy = flat[offset + 1];
      final width = flat[offset + 2];
      final height = flat[offset + 3];
      final objectness = hasObjectness ? flat[offset + 4] : 1.0;

      var bestClassId = -1;
      var bestScore = 0.0;
      for (var classId = 0; classId < detectionClasses.length; classId++) {
        final classScore = flat[offset + classOffset + classId];
        final score = classScore * objectness;
        if (score > bestScore) {
          bestScore = score;
          bestClassId = classId;
        }
      }

      _addYoloDetection(
        detections,
        classId: bestClassId,
        score: bestScore,
        cx: cx,
        cy: cy,
        width: width,
        height: height,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
    }

    return detections;
  }

  List<TFLiteDetectionResult> _parseAlreadyNmsOutput(
    List<double> flat, {
    required int boxes,
    required int channels,
    required int imageWidth,
    required int imageHeight,
  }) {
    final detections = <TFLiteDetectionResult>[];

    for (var boxIndex = 0; boxIndex < boxes; boxIndex++) {
      final offset = boxIndex * channels;
      final x1 = flat[offset];
      final y1 = flat[offset + 1];
      final x2OrWidth = flat[offset + 2];
      final y2OrHeight = flat[offset + 3];
      final score = flat[offset + 4];
      final classId = flat[offset + 5].round();

      if (score < confidenceThreshold ||
          classId < 0 ||
          classId >= detectionClasses.length) {
        continue;
      }

      final isNormalized = [x1, y1, x2OrWidth, y2OrHeight].every(
        (value) => value >= 0 && value <= 1.5,
      );
      final scaleX = isNormalized ? imageWidth.toDouble() : imageWidth / _inputWidth;
      final scaleY =
          isNormalized ? imageHeight.toDouble() : imageHeight / _inputHeight;
      final left = x1 * scaleX;
      final top = y1 * scaleY;
      final width = (x2OrWidth > x1 ? x2OrWidth - x1 : x2OrWidth) * scaleX;
      final height = (y2OrHeight > y1 ? y2OrHeight - y1 : y2OrHeight) * scaleY;

      detections.add(
        TFLiteDetectionResult(
          classId: classId,
          label: detectionClasses[classId],
          confidence: score,
          x: left.clamp(0, imageWidth.toDouble()).toDouble(),
          y: top.clamp(0, imageHeight.toDouble()).toDouble(),
          width: width.clamp(0, imageWidth.toDouble()).toDouble(),
          height: height.clamp(0, imageHeight.toDouble()).toDouble(),
        ),
      );
    }

    return detections;
  }

  void _addYoloDetection(
    List<TFLiteDetectionResult> detections, {
    required int classId,
    required double score,
    required double cx,
    required double cy,
    required double width,
    required double height,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (classId < 0 ||
        classId >= detectionClasses.length ||
        score < confidenceThreshold) {
      return;
    }

    final isNormalized = [cx, cy, width, height].every(
      (value) => value >= 0 && value <= 1.5,
    );
    final scaleX = isNormalized ? imageWidth.toDouble() : imageWidth / _inputWidth;
    final scaleY =
        isNormalized ? imageHeight.toDouble() : imageHeight / _inputHeight;
    final left = (cx - width / 2) * scaleX;
    final top = (cy - height / 2) * scaleY;

    detections.add(
      TFLiteDetectionResult(
        classId: classId,
        label: detectionClasses[classId],
        confidence: score,
        x: left.clamp(0, imageWidth.toDouble()).toDouble(),
        y: top.clamp(0, imageHeight.toDouble()).toDouble(),
        width: (width * scaleX).clamp(0, imageWidth.toDouble()).toDouble(),
        height: (height * scaleY).clamp(0, imageHeight.toDouble()).toDouble(),
      ),
    );
  }

  void _flattenOutput(Object? value, List<double> output) {
    if (value is List) {
      for (final item in value) {
        _flattenOutput(item, output);
      }
      return;
    }

    if (value is num) {
      output.add(value.toDouble());
    }
  }

  List<TFLiteDetectionResult> _applyNms(List<TFLiteDetectionResult> detections) {
    final sorted = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <TFLiteDetectionResult>[];

    for (final candidate in sorted) {
      final keep = selected.every(
        (existing) =>
            existing.classId != candidate.classId ||
            _calculateIou(existing, candidate) < iouThreshold,
      );

      if (keep) {
        selected.add(candidate);
      }
    }

    return selected;
  }

  double _calculateIou(TFLiteDetectionResult a, TFLiteDetectionResult b) {
    final left = math.max(a.x, b.x);
    final top = math.max(a.y, b.y);
    final right = math.min(a.x + a.width, b.x + b.width);
    final bottom = math.min(a.y + a.height, b.y + b.height);
    final intersectionWidth = math.max(0.0, right - left);
    final intersectionHeight = math.max(0.0, bottom - top);
    final intersection = intersectionWidth * intersectionHeight;
    final union = a.area + b.area - intersection;

    if (union <= 0) return 0;
    return intersection / union;
  }

  img.Image _resizeForDemo(img.Image image) {
    final maxSide = math.max(image.width, image.height);
    if (maxSide <= maxInputDimension) {
      return image;
    }

    final scale = maxInputDimension / maxSide;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  Future<String> _saveAnnotatedImage(
    img.Image image,
    List<TFLiteDetectionResult> detections,
  ) async {
    final annotated = img.Image.from(image);
    final color = img.ColorRgb8(0, 255, 0);

    for (final detection in detections) {
      final x1 = detection.x.round();
      final y1 = detection.y.round();
      final x2 = (detection.x + detection.width).round();
      final y2 = (detection.y + detection.height).round();

      img.drawRect(
        annotated,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: color,
        thickness: 4,
      );
      img.drawString(
        annotated,
        '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
        font: img.arial14,
        x: x1,
        y: math.max(0, y1 - 18),
        color: color,
      );
    }

    final directory = await _getDetectionDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}detected_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(img.encodeJpg(annotated, quality: 92));
    return file.path;
  }

  Future<Directory> _getDetectionDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final detectionDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}detec',
    );

    if (!await detectionDirectory.exists()) {
      await detectionDirectory.create(recursive: true);
      print('📁 TFLite: đã tạo thư mục ${detectionDirectory.path}');
    }

    return detectionDirectory;
  }

  TFLiteDetectionResult? getHighestConfidenceObject(String label) {
    final filtered = _lastDetections
        .where((detection) => detection.label == label)
        .where((detection) => detection.confidence >= confidenceThreshold)
        .toList();

    if (filtered.isEmpty) return null;
    return filtered.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }

  List<TFLiteDetectionResult> getObjectsByLabel(String label) {
    return _lastDetections
        .where((detection) => detection.label == label)
        .where((detection) => detection.confidence >= confidenceThreshold)
        .toList();
  }

  List<TFLiteDetectionResult> sortByDistance() {
    final sorted = [..._lastDetections];
    sorted.sort((a, b) => b.area.compareTo(a.area));
    return sorted;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _lastDetections = [];
  }
}
