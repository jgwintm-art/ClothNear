import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build-time (--dart-define) takes precedence; .env used for local dev.
class EnvConfig {
  /// Loads `.env` for local development. Safe to skip when using `--dart-define`.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Missing .env is OK when CI/production inject keys via --dart-define.
    }
  }

  static String get geminiApiKey {
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static String get geminiModel {
    const fromDefine = String.fromEnvironment('GEMINI_MODEL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
  }
}
