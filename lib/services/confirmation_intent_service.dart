import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'tflite_detection_service.dart';

class ConfirmationIntentService {
  Future<String?> classifyTargetObject(String text) async {
    final classes = detectionClasses.join(', ');
    final answer = await _askOpenRouter(
      systemPrompt:
          'Bạn là bộ phân loại đồ vật người dùng muốn tìm. '
          'Chỉ trả lời đúng một nhãn trong danh sách sau, hoặc NONE nếu không rõ: $classes. '
          'Không giải thích. Không dịch sang tiếng Việt. '
          'Ví dụ: laptop, máy tính, vi tính, pc đều là laptop nếu phù hợp.',
      userText: text,
      purpose: 'phân loại đồ vật cần tìm',
    );

    if (answer == null) return null;

    final normalized = answer.trim().toLowerCase();
    if (normalized == 'none') return null;

    for (final className in detectionClasses) {
      if (normalized == className.toLowerCase()) {
        return className;
      }
    }

    print('OpenRouter: nhãn object không hợp lệ: $answer');
    return null;
  }

  Future<bool> isMovementCompleted(String text) async {
    final answer = await _askOpenRouter(
      systemPrompt:
          'You classify Vietnamese user intent for a blind-navigation app. '
          'Answer only YES or NO. '
          'YES if the user means they have completed the previous movement instruction, '
          'for example: "đã xong", "xong rồi", "tôi đi xong rồi", "oke rồi", '
          '"tôi đã xoay xong", "hoàn thành rồi". '
          'NO if the user is asking a question, saying they have not completed it, wants to stop, '
          'or the meaning is unclear.',
      userText: text,
      purpose: 'phân loại xác nhận hoàn thành chặng',
    );

    final normalizedAnswer = answer?.trim().toUpperCase() ?? '';
    if (normalizedAnswer.startsWith('YES')) {
      return true;
    }

    if (normalizedAnswer.startsWith('NO')) {
      return false;
    }

    final fallbackResult = _localMovementConfirmationFallback(text);
    print('OpenRouter: câu trả lời xác nhận không rõ, fallback local = $fallbackResult');
    return fallbackResult;
  }

  bool _localMovementConfirmationFallback(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.contains('chưa') ||
        normalized.contains('không') ||
        normalized.contains('dừng') ||
        normalized.contains('thoát')) {
      return false;
    }

    return normalized.contains('xong') ||
        normalized.contains('hoàn thành') ||
        normalized.contains('hoàn tất') ||
        normalized.contains('đã đi') ||
        normalized.contains('đã xoay') ||
        normalized.contains('được rồi') ||
        normalized == 'ok' ||
        normalized == 'oke' ||
        normalized.contains('ok rồi') ||
        normalized.contains('oke rồi');
  }

  Future<String?> _askOpenRouter({
    required String systemPrompt,
    required String userText,
    required String purpose,
  }) async {
    final apiKey = EnvConfig.openrouterApiKey;
    if (apiKey.isEmpty) {
      print('OpenRouter: thiếu openrouterApiKey trong .env');
      return null;
    }

    try {
      print('OpenRouter: đang $purpose: "$userText"');
      final response = await http
          .post(
            Uri.parse(EnvConfig.openrouterApiUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': EnvConfig.openrouterModel,
              'temperature': 0,
              'max_tokens': 12,
              'messages': [
                {
                  'role': 'system',
                  'content': systemPrompt,
                },
                {
                  'role': 'user',
                  'content': userText,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        print('OpenRouter: lỗi status ${response.statusCode}');
        print('OpenRouter: body ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        print('OpenRouter: response không có choices');
        return null;
      }

      final message = choices.first['message'];
      final content = message is Map<String, dynamic> ? message['content'] : null;
      final answer = content?.toString().trim();

      print('OpenRouter: kết quả $purpose = $answer');
      return answer;
    } catch (e) {
      print('OpenRouter: lỗi khi $purpose: $e');
      return null;
    }
  }
}


