import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get baseUrl {
    return dotenv.env['baseUrl'] ?? 'http://localhost:3000/api';
  }

  static String get ttsUrl {
    return dotenv.env['ttsUrl'] ?? 'http://localhost:3000/api/tts';
  }

  static String get openrouterApiKey {
    return dotenv.env['openrouterApiKey'] ?? '';
  }

  static String get openrouterApiUrl {
    return dotenv.env['openrouterApiUrl'] ??
        'https://openrouter.ai/api/v1/chat/completions';
  }

  static String get openrouterModel {
    return dotenv.env['openrouterModel'] ?? 'openai/gpt-3.5-turbo';
  }

  static String get geminiApiKey {
    return dotenv.env['geminiApiKey'] ?? '';
  }

  static String get geminiVisionModel {
    return dotenv.env['geminiVisionModel'] ?? 'gemini-3.5-flash';
  }

  static String get geminiApiUrl {
    return dotenv.env['geminiApiUrl'] ??
        'https://generativelanguage.googleapis.com/v1beta/interactions';
  }
}
