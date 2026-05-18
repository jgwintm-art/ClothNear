import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api_secrets.dart';

/// Central env access for ClothNear.
///
/// Priority: [ApiSecrets] (CI-generated) → dart-define → `.env` (local dev).
class EnvConfig {
  static const bool geminiKeyCompiledAtBuild = bool.fromEnvironment(
    'GEMINI_KEY_COMPILED',
    defaultValue: false,
  );

  static Future<void> load() async {
    if (isGeminiConfigured) return;
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnvConfig: could not load .env ($e)');
      }
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

  static bool get isGeminiConfigured => geminiApiKey.isNotEmpty;

  /// Shown in UI/errors to confirm which build is running (no secret exposed).
  static String get deploymentDiagnostics {
    final keySource = ApiSecrets.geminiApiKey.isNotEmpty
        ? 'api_secrets'
        : const String.fromEnvironment('GEMINI_API_KEY').isNotEmpty
            ? 'dart-define'
            : (dotenv.env['GEMINI_API_KEY'] ?? '').isNotEmpty
                ? 'dotenv'
                : 'none';
    return 'keySource=$keySource, compiledFlag=$geminiKeyCompiledAtBuild, '
        'configured=$isGeminiConfigured';
  }

  static String get geminiConfigurationHint {
    if (isGeminiConfigured) return '';
    if (kIsWeb) {
      return 'Live site has no API key in this build ($deploymentDiagnostics). '
          'Push to main so GitHub Actions rebuilds with GEMINI_API_KEY secret, '
          'or run: flutter build web --dart-define=GEMINI_API_KEY=YOUR_KEY';
    }
    return 'Add GEMINI_API_KEY to .env in the project root (see env.example).';
  }
}
