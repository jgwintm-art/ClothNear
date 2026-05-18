import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build-time (--dart-define) takes precedence; .env used for local dev.
class EnvConfig {
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
