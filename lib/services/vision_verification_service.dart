import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/env.dart';
import 'object_mapping_service.dart';
import 'tflite_detection_service.dart';

class VisionVerificationResult {
  const VisionVerificationResult({
    required this.isCorrect,
    required this.confidence,
    required this.reason,
  });

  final bool isCorrect;
  final double confidence;
  final String reason;
}

class VisionVerificationService {
  String? lastError;

  Future<VisionVerificationResult?> verifyDetection({
    required File imageFile,
    required TFLiteDetectionResult detection,
    required String expectedLabel,
  }) async {
    lastError = null;
    final apiKey = EnvConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      lastError = 'Thi\u1ebfu geminiApiKey trong .env';
      print('Gemini Vision: $lastError');
      return null;
    }

    try {
      final cropBase64 = await _cropDetectionToBase64(
        imageFile: imageFile,
        detection: detection,
      );
      if (cropBase64 == null) {
        lastError = 'Kh\u00f4ng crop \u0111\u01b0\u1ee3c v\u00f9ng box \u0111\u1ec3 x\u00e1c minh';
        print('Gemini Vision: $lastError');
        return null;
      }

      final objectName = ObjectMappingService.getVietnameseName(expectedLabel);
      final confidencePercent = (detection.confidence * 100).toStringAsFixed(0);
      print(
        'Gemini Vision: x\u00e1c minh crop-box $objectName t\u1eeb TFLite $confidencePercent%',
      );

      final useInteractionsApi =
          Uri.parse(EnvConfig.geminiApiUrl).path.endsWith('/interactions');
      final uri = useInteractionsApi
          ? Uri.parse(EnvConfig.geminiApiUrl)
          : Uri.parse(EnvConfig.geminiApiUrl).replace(
              queryParameters: {
                ...Uri.parse(EnvConfig.geminiApiUrl).queryParameters,
                'key': apiKey,
              },
            );
      final prompt = _buildPrompt(
        expectedLabel: expectedLabel,
        objectName: objectName,
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (useInteractionsApi) 'x-goog-api-key': apiKey,
            },
            body: jsonEncode(
              useInteractionsApi
                  ? _buildInteractionsBody(
                      prompt: prompt,
                      cropBase64: cropBase64,
                    )
                  : _buildGenerateContentBody(
                      prompt: prompt,
                      cropBase64: cropBase64,
                    ),
            ),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastError =
            'L\u1ed7i API status ${response.statusCode}: ${_shortText(response.body)}';
        print('Gemini Vision: l\u1ed7i status ${response.statusCode}');
        print('Gemini Vision: body ${response.body}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final text = _extractResponseText(body);
      if (text == null || text.trim().isEmpty) {
        lastError = 'Response kh\u00f4ng c\u00f3 text: ${_shortText(response.body)}';
        print('Gemini Vision: $lastError');
        return null;
      }

      final jsonText = _extractJsonObject(text);
      if (jsonText == null) {
        lastError = 'Gemini tr\u1ea3 text nh\u01b0ng kh\u00f4ng ph\u1ea3i JSON: ${_shortText(text)}';
        print('Gemini Vision: $lastError');
        return null;
      }
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      final isCorrect = parsed['is_correct'] == true;
      final confidence = _readDouble(parsed['confidence']);
      final reason = parsed['reason']?.toString() ?? '';

      print(
        'Gemini Vision: is_correct=$isCorrect, confidence=${confidence.toStringAsFixed(2)}, reason=$reason',
      );

      return VisionVerificationResult(
        isCorrect: isCorrect,
        confidence: confidence,
        reason: reason,
      );
    } on TimeoutException {
      lastError =
          'Gemini ph\u1ea3n h\u1ed3i qu\u00e1 ch\u1eadm sau 30 gi\u00e2y. H\u00e3y th\u1eed ch\u1ee5p l\u1ea1i \u1ea3nh r\u00f5 h\u01a1n ho\u1eb7c ki\u1ec3m tra m\u1ea1ng.';
      print('Gemini Vision: $lastError');
      return null;
    } catch (error) {
      lastError = 'L\u1ed7i x\u00e1c minh \u1ea3nh: $error';
      print('Gemini Vision: $lastError');
      return null;
    }
  }

  String _buildPrompt({
    required String expectedLabel,
    required String objectName,
  }) {
    return 'You are a crop-box verifier for an assistive navigation app. '
        'The image is ONLY the cropped region inside one bounding box drawn by a TFLite detector. '
        'Do not analyze the full original image. Do not guess from context outside this crop. '
        'Allowed classes: ${detectionClasses.join(", ")}. '
        'Check whether this crop is the expected class "$expectedLabel" ($objectName). '
        'Return ONLY valid compact JSON, no markdown, no explanation outside JSON. '
        'Schema: {"is_correct":true,"class_name":"$expectedLabel","confidence":0.85,"reason":"short reason"}. '
        'If the crop is not one of the allowed classes, use class_name="unknown". '
        'confidence must be a number from 0 to 1.';
  }

  Map<String, dynamic> _buildInteractionsBody({
    required String prompt,
    required String cropBase64,
  }) {
    return {
      'model': EnvConfig.geminiVisionModel,
      'input': [
        {
          'type': 'text',
          'text': prompt,
        },
        {
          'type': 'image',
          'data': cropBase64,
          'mime_type': 'image/jpeg',
        },
      ],
    };
  }

  Map<String, dynamic> _buildGenerateContentBody({
    required String prompt,
    required String cropBase64,
  }) {
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': cropBase64,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'maxOutputTokens': 120,
        'responseMimeType': 'application/json',
      },
    };
  }

  String? _extractResponseText(Map<String, dynamic> body) {
    final outputText = body['output_text']?.toString();
    if (outputText != null && outputText.trim().isNotEmpty) {
      return outputText;
    }

    final output = body['output'];
    final outputValue = _findResponseText(output);
    if (outputValue != null) {
      return outputValue;
    }

    final steps = body['steps'];
    final stepsValue = _findResponseText(steps);
    if (stepsValue != null) {
      return stepsValue;
    }

    final response = body['response'];
    final responseValue = _findResponseText(response);
    if (responseValue != null) {
      return responseValue;
    }

    final result = body['result'];
    final resultValue = _findResponseText(result);
    if (resultValue != null) {
      return resultValue;
    }

    final candidates = body['candidates'];
    final candidateValue = _findResponseText(candidates);
    if (candidateValue != null) {
      return candidateValue;
    }

    return _findResponseText(body);
  }

  String? _findResponseText(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return trimmed;
    }

    if (value is List) {
      for (final item in value) {
        final text = _findResponseText(item);
        if (text != null) return text;
      }
      return null;
    }

    if (value is Map) {
      for (final key in const ['output_text', 'text', 'value']) {
        final raw = value[key];
        if (raw is String && raw.trim().isNotEmpty) {
          return raw.trim();
        }
      }

      for (final key in const [
        'content',
        'parts',
        'message',
        'messages',
        'items',
        'data',
      ]) {
        final text = _findResponseText(value[key]);
        if (text != null) return text;
      }
    }

    return null;
  }

  String? _extractJsonObject(String text) {
    final trimmed = _stripJsonFence(text);
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }

    return null;
  }

  Future<String?> _cropDetectionToBase64({
    required File imageFile,
    required TFLiteDetectionResult detection,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final source = img.decodeImage(bytes);
    if (source == null) return null;

    final marginX = detection.width * 0.18;
    final marginY = detection.height * 0.18;
    final left = math.max(0, (detection.x - marginX).floor());
    final top = math.max(0, (detection.y - marginY).floor());
    final right = math.min(
      source.width,
      (detection.x + detection.width + marginX).ceil(),
    );
    final bottom = math.min(
      source.height,
      (detection.y + detection.height + marginY).ceil(),
    );
    final cropWidth = math.max(1, right - left);
    final cropHeight = math.max(1, bottom - top);

    final crop = img.copyCrop(
      source,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );
    final optimizedCrop = _resizeCropForGemini(crop);
    final jpg = img.encodeJpg(optimizedCrop, quality: 70);
    return base64Encode(jpg);
  }

  img.Image _resizeCropForGemini(img.Image crop) {
    const maxSide = 384;
    final longestSide = math.max(crop.width, crop.height);
    if (longestSide <= maxSide) return crop;

    final scale = maxSide / longestSide;
    return img.copyResize(
      crop,
      width: math.max(1, (crop.width * scale).round()),
      height: math.max(1, (crop.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble().clamp(0, 1).toDouble();
    return double.tryParse(value?.toString() ?? '')?.clamp(0, 1).toDouble() ??
        0;
  }

  String _stripJsonFence(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    return trimmed
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }

  String _shortText(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 240) return compact;
    return '${compact.substring(0, 240)}...';
  }
}
