import 'package:flutter/services.dart';

class TTSService {
  static const platform = MethodChannel('com.example.doan/tts');

  /// Phát tiếng nói tiếng Việt sử dụng Android TTS engine
  static Future<void> speak(String text) async {
    try {
      print('TTS: Speaking Vietnamese: "$text"');
      await platform.invokeMethod('speak', {
        'text': text,
        'language': 'vi',
        'country': 'VN',
        'pitch': 1.0,
        'speechRate': 0.8,
      });
      print('TTS speech completed');
    } catch (e) {
      print('TTS error: $e');
    }
  }

  /// Dừng phát tiếng nói
  static Future<void> stop() async {
    try {
      await platform.invokeMethod('stop');
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }
}


