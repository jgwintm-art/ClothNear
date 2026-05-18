import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api_secrets.dart';

/// Central env access: [ApiSecrets] (CI) → dart-define → `.env` (local dev).
class EnvConfig {
  static Future<void> load() async {
    if (geminiApiKey.isNotEmpty) return;
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env is optional when using --dart-define or CI-injected [ApiSecrets].
    }
  }

  static String get geminiApiKey {
    if (ApiSecrets.geminiApiKey.isNotEmpty) {
      return ApiSecrets.geminiApiKey;
    }
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static String get geminiModel {
    if (ApiSecrets.geminiModel.isNotEmpty) {
      return ApiSecrets.geminiModel;
    }
    const fromDefine = String.fromEnvironment('GEMINI_MODEL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
  }

  static String get geminiConfigurationHint {
    if (geminiApiKey.isNotEmpty) return '';
    return 'Configure GEMINI_API_KEY in .env for local runs, or in GitHub Actions secrets for deployment.';
  }
}
