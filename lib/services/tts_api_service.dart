import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service để gọi TTS API từ backend (gTTS)
/// Kết nối: http://192.168.1.11:3000/api/tts
class TTSApiService {
  static final TTSApiService _instance = TTSApiService._internal();
  late AudioPlayer _audioPlayer;
  late String _ttsUrl;

  factory TTSApiService() {
    return _instance;
  }

  TTSApiService._internal() {
    _audioPlayer = AudioPlayer();
    _ttsUrl = dotenv.get('ttsUrl', fallback: 'http://192.168.183.1:3000/api/tts');
  }

  /// Phát âm thanh từ API backend
  /// text: Văn bản cần đọc
  /// lang: Mã ngôn ngữ (mặc định: 'vi' - Tiếng Việt)
  Future<void> speak(String text, {String lang = 'vi'}) async {
    try {
      if (text.isEmpty) {
        print('❌ TTS API: Text trống');
        return;
      }

      print('🔊 TTS API: Đang gọi API với text: "$text" (lang: $lang)');

      // Gọi GET request với query parameters
      final url = Uri.parse('$_ttsUrl?text=${Uri.encodeComponent(text)}&lang=$lang');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('TTS API timeout sau 10 giây');
        },
      );

      if (response.statusCode == 200) {
        // Kiểm tra content-type
        final contentType = response.headers['content-type'] ?? '';
        
        if (contentType.contains('audio')) {
          // Stream audio bytes
          print('✅ TTS API: Nhận audio stream (${response.bodyBytes.length} bytes)');
          
          // Play audio từ bytes sử dụng BytesSource
          try {
            await _audioPlayer.play(BytesSource(response.bodyBytes), volume: 1.0);
            print('✅ TTS API: Đang phát âm thanh');
          } catch (playError) {
            print('❌ TTS API Play Error: $playError');
            rethrow;
          }
        } else {
          // Có thể là JSON (health check)
          print('⚠️ TTS API: Nhận response không phải audio: $contentType');
        }
      } else {
        print('❌ TTS API Error: Status ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ TTS API Exception: $e');
      rethrow;
    }
  }

  /// Dừng phát âm thanh
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      print('⏹️ TTS API: Dừng phát âm thanh');
    } catch (e) {
      print('❌ TTS API Stop Error: $e');
    }
  }

  /// Kiểm tra kết nối backend
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_ttsUrl/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ TTS API: Health check thành công');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ TTS API: Health check thất bại - $e');
      return false;
    }
  }

  /// Lấy URL của backend
  String get ttsUrl => _ttsUrl;

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
