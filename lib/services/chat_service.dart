import 'dart:convert';
import 'dart:math' as math;
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

  /// Độ dài tối đa một lần gọi TTS (tránh URL / BE quá tải)
  static const int ttsMaxChunkChars = 140;

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

  /// Tách theo ranh giới câu (.!?。 …), chunk thêm nếu câu quá dài.
  /// Mỗi đoạn = một request TTS để backend không nhận quá nhiều ký tự một lần.
  static List<String> splitTextForTTS(String text) {
    final t = text.trim();
    if (t.isEmpty) return [];

    final normalized =
        t.replaceAll(RegExp(r'\r\n?'), '\n').replaceAll(RegExp(r'\s*\n\s*'), '. ');

    var parts = normalized
        .split(RegExp(r'[.!?。]+(?:\s+|$)', multiLine: true))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      parts = [normalized];
    }

    final out = <String>[];
    for (final p in parts) {
      out.addAll(_chunkLongForTTS(p, ttsMaxChunkChars));
    }

    return out.isEmpty ? [t] : out;
  }

  /// Cắt đoạn dài tại chỗ thoáng (, ; : hoặc khoảng trắng) để không vượt [maxLen].
  static List<String> _chunkLongForTTS(String text, int maxLen) {
    final s = text.trim();
    if (s.isEmpty) return [];
    if (s.length <= maxLen) return [s];

    final chunks = <String>[];
    var start = 0;
    while (start < s.length) {
      final hardEnd = math.min(start + maxLen, s.length);
      if (hardEnd >= s.length) {
        chunks.add(s.substring(start).trim());
        break;
      }
      final slice = s.substring(start, hardEnd);
      var relBreak = slice.lastIndexOf(RegExp(r'[ ,;:，、]'));
      if (relBreak < slice.length ~/ 5) {
        relBreak = hardEnd - start - 1;
      }
      final cut = start + relBreak + 1;
      chunks.add(s.substring(start, cut).trim());
      start = cut;
    }
    return chunks.where((c) => c.isNotEmpty).toList();
  }
}
