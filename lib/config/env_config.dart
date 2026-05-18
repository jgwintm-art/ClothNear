import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central env access for ClothNear.
///
/// **Local:** `.env` loaded via [load] → [geminiApiKey] from dotenv.
/// **CI / production web:** `--dart-define=GEMINI_API_KEY=...` at `flutter build web`
/// (compiled into JS). Do not rely on runtime `.env` alone in production.
class EnvConfig {
  /// Set in CI: `--dart-define=GEMINI_KEY_COMPILED=true` to verify build pipeline.
  static const bool geminiKeyCompiledAtBuild = bool.fromEnvironment(
    'GEMINI_KEY_COMPILED',
    defaultValue: false,
  );

  /// Loads `.env` for local dev when [geminiApiKey] is not already set via dart-define.
  static Future<void> load() async {
    if (geminiApiKey.isNotEmpty) {
      return;
    }
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnvConfig: could not load .env ($e)');
      }
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

  static bool get isGeminiConfigured => geminiApiKey.isNotEmpty;

  /// User-facing hint when Gemini is invoked without a key.
  static String get geminiConfigurationHint {
    if (isGeminiConfigured) return '';
    if (kIsWeb && !geminiKeyCompiledAtBuild) {
      return 'Production web builds must pass '
          '--dart-define=GEMINI_API_KEY=... when running flutter build web '
          '(see .github/workflows/deploy.yml). '
          'A .env file alone is not served on Firebase Hosting.';
    }
    if (kIsWeb && geminiKeyCompiledAtBuild) {
      return 'Build flag GEMINI_KEY_COMPILED was set but GEMINI_API_KEY is empty. '
          'Check the GitHub Actions secret value.';
    }
    return 'Add GEMINI_API_KEY to a .env file in the project root for local development.';
  }
}
