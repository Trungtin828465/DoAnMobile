import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TTSApiService {
  static final TTSApiService _instance = TTSApiService._internal();

  late AudioPlayer _audioPlayer;
  late String _ttsUrl;
  bool _isPlayerDisposed = false;

  factory TTSApiService() {
    _instance._ensureAudioPlayer();
    return _instance;
  }

  TTSApiService._internal() {
    _audioPlayer = AudioPlayer();
    _ttsUrl = dotenv.get('ttsUrl', fallback: 'http://192.168.183.1:3000/api/tts');
  }

  void _ensureAudioPlayer() {
    if (!_isPlayerDisposed) return;
    _audioPlayer = AudioPlayer();
    _isPlayerDisposed = false;
    print('🔄 TTS API: Tạo lại AudioPlayer sau khi quay lại màn hình');
  }

  Future<void> speak(String text, {String lang = 'vi'}) async {
    _ensureAudioPlayer();

    try {
      if (text.trim().isEmpty) {
        print('❌ TTS API: Text trống');
        return;
      }

      print('🔊 TTS API: Đang gọi API với text: "$text" (lang: $lang)');

      final url = Uri.parse(
        '$_ttsUrl?text=${Uri.encodeComponent(text)}&lang=$lang',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('TTS API timeout sau 10 giây');
        },
      );

      if (response.statusCode != 200) {
        print('❌ TTS API Error: Status ${response.statusCode}');
        print('Response: ${response.body}');
        return;
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('audio')) {
        print('⚠️ TTS API: Nhận response không phải audio: $contentType');
        return;
      }

      print('✅ TTS API: Nhận audio stream (${response.bodyBytes.length} bytes)');

      final completer = Completer<void>();
      late StreamSubscription<void> subscription;
      subscription = _audioPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        subscription.cancel();
      });

      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(response.bodyBytes), volume: 1.0);
      print('✅ TTS API: Đang phát âm thanh');

      await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          subscription.cancel();
        },
      );

      await _audioPlayer.stop();
      print('✅ TTS API: Đã phát xong âm thanh');
    } catch (error) {
      print('❌ TTS API Exception: $error');
      rethrow;
    }
  }

  Future<void> stop() async {
    _ensureAudioPlayer();

    try {
      await _audioPlayer.stop();
      print('⏹️ TTS API: Dừng phát âm thanh');
    } catch (error) {
      print('❌ TTS API Stop Error: $error');
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_ttsUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ TTS API: Health check thành công');
        return true;
      }

      print('⚠️ TTS API: Health check status ${response.statusCode}');
      return false;
    } catch (error) {
      print('❌ TTS API: Health check thất bại - $error');
      return false;
    }
  }

  String get ttsUrl => _ttsUrl;

  void dispose() {
    if (_isPlayerDisposed) return;
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _isPlayerDisposed = true;
    print('🧹 TTS API: Đã giải phóng AudioPlayer');
  }
}
