import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class ChatService {
  static String get openrouterApiKey {
    return EnvConfig.openrouterApiKey;
  }

  static String get openrouterApiUrl {
    return EnvConfig.openrouterApiUrl;
  }

  static String get model {
    return EnvConfig.openrouterModel;
  }

  static String get ttsServerUrl {
    return EnvConfig.ttsUrl;
  }

  static const Duration requestTimeout = Duration(seconds: 30);

  /// Gửi tin nhắn tới OpenRouter API
  static Future<String> sendMessage(String userMessage) async {
    try {
      debugPrint('📤 Sending to OpenRouter: $userMessage');

      final payload = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': userMessage,
          }
        ],
        'temperature': 0.7,
        'max_tokens': 500,
      };

      final response = await http.post(
        Uri.parse(openrouterApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openrouterApiKey',
          'HTTP-Referer': 'http://localhost:3000',
          'X-Title': '3D Room Designer',
        },
        body: jsonEncode(payload),
      ).timeout(requestTimeout);

      debugPrint('✓ Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message =
            data['choices'][0]['message']['content'] ?? 'Không có phản hồi';
        debugPrint('✅ AI Response: $message');
        return message;
      } else {
        final error = jsonDecode(response.body);
        final errorMsg = error['error']?['message'] ?? 'Lỗi không xác định';
        debugPrint('❌ Lỗi: $errorMsg');
        return 'Lỗi: $errorMsg';
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ Lỗi kết nối: $openrouterApiUrl');
      debugPrint('Chi tiết: $e');
      return 'Lỗi kết nối tới AI';
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return 'Lỗi: ${e.toString()}';
    }
  }

  /// Lấy URL stream audio từ TTS server
  /// URL có thể dùng trực tiếp với AudioPlayer.play(UrlSource(url))
  static String getTTSUrlForText(String text) {
    final encodedText = Uri.encodeComponent(text);
    return '$ttsServerUrl?text=$encodedText&lang=vi';
  }

  /// Tách text dài thành các câu (cách bằng dấu chấm)
  /// Mỗi câu sẽ được phát riêng để tránh URL quá dài
  static List<String> splitTextForTTS(String text) {
    // Tách theo dấu chấm (.), sau đó trim whitespace
    final sentences = text
        .split('.')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.isEmpty) {
      return [text];
    }

    return sentences;
  }
}
