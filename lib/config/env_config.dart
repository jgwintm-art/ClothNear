import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_secrets.dart';

/// Central env access — priority order for every key:
///   1. [ApiSecrets] compile-time constant (CI-injected before build)
///   2. --dart-define at build time
///   3. .env file (local development)
class EnvConfig {
  static Future<void> load() async {
    // If any compile-time secret is already present, skip .env load.
    if (geminiApiKey.isNotEmpty) return;
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env is optional in CI — keys come from ApiSecrets or --dart-define.
    }
  }

  // ── Gemini ──────────────────────────────────────────────────────────────────

  static String get geminiApiKey {
    if (ApiSecrets.geminiApiKey.isNotEmpty) return ApiSecrets.geminiApiKey;
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static String get geminiModel {
    if (ApiSecrets.geminiModel.isNotEmpty) return ApiSecrets.geminiModel;
    const fromDefine = String.fromEnvironment('GEMINI_MODEL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
  }

  static String get geminiConfigurationHint {
    if (geminiApiKey.isNotEmpty) return '';
    return 'Add GEMINI_API_KEY to your .env file (local) or GitHub Secrets / --dart-define (CI).';
  }

  // ── PayMongo ─────────────────────────────────────────────────────────────────
  //
  // ARCHITECTURE CHANGE (CORS fix):
  //   PayMongo API calls now go through a Firebase Cloud Function proxy.
  //   The secret key is stored in Firebase Secret Manager (server-side only)
  //   and is NEVER embedded in the Flutter web bundle.
  //
  //   The Flutter app only needs to know:
  //     1. Whether PayMongo is enabled (isPayMongoConfigured)
  //     2. The base URL of the Firebase Functions (paymongoFunctionsBase)
  //
  //   isPayMongoConfigured is controlled by PAYMONGO_ENABLED in .env / CI.
  //   Set it to "true" when the secret key has been added to Firebase.
  //
  //   To set the secret key server-side (run once):
  //     firebase functions:secrets:set PAYMONGO_SECRET_KEY
  //
  //   For local development with the Functions emulator:
  //     Add to .env:  PAYMONGO_FUNCTIONS_BASE=http://localhost:5001/clothnear/us-central1
  //     Then run:     firebase emulators:start --only functions

  /// Whether online payment via PayMongo is enabled in this build.
  /// Controlled by PAYMONGO_ENABLED=true in .env or CI secrets.
  /// Defaults to true if the legacy PAYMONGO_SECRET_KEY is present (backwards compat).
  static bool get isPayMongoConfigured {
    // New flag: explicit opt-in/out
    final enabled = dotenv.env['PAYMONGO_ENABLED'] ??
        const String.fromEnvironment('PAYMONGO_ENABLED');
    if (enabled == 'true') return true;
    if (enabled == 'false') return false;

    // Legacy backwards-compat: if old secret key is present in env, treat as enabled.
    // This keeps local .env files working without changes.
    final legacyKey = ApiSecrets.paymongoSecretKey.isNotEmpty
        ? ApiSecrets.paymongoSecretKey
        : (dotenv.env['PAYMONGO_SECRET_KEY'] ??
            const String.fromEnvironment('PAYMONGO_SECRET_KEY'));
    return legacyKey.isNotEmpty;
  }

  /// Base URL for the Firebase Cloud Function proxy.
  /// Override in .env for local emulator or non-default regions.
  static String get paymongoFunctionsBase {
    const fromDefine = String.fromEnvironment('PAYMONGO_FUNCTIONS_BASE');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['PAYMONGO_FUNCTIONS_BASE'] ?? '';
  }

  static String get paymongoConfigHint {
    if (isPayMongoConfigured) return '';
    return 'Online payments are not configured. '
        'Set PAYMONGO_SECRET_KEY in Firebase Secret Manager and '
        'set PAYMONGO_ENABLED=true in your .env or CI secrets.';
  }
}
