import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_secrets.dart';

/// Central env access — priority order for every key:
///   1. [ApiSecrets] compile-time constant (CI-injected before build)
///   2. --dart-define at build time
///   3. .env file (local development)
class EnvConfig {
  static Future<void> load() async {
    // Only skip .env loading if a compile-time key is already baked in.
    // Do NOT read dotenv.env here — it isn't loaded yet and will throw
    // NotInitializedError.
    if (ApiSecrets.geminiApiKey.isNotEmpty) return;
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env is optional in CI — keys come from ApiSecrets or --dart-define.
    }
  }

  /// Safe dotenv accessor — returns empty string instead of throwing
  /// NotInitializedError when dotenv hasn't been loaded yet.
  static String _env(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  // ── Gemini ──────────────────────────────────────────────────────────────────

  static String get geminiApiKey {
    if (ApiSecrets.geminiApiKey.isNotEmpty) return ApiSecrets.geminiApiKey;
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return _env('GEMINI_API_KEY');
  }

  static String get geminiModel {
    if (ApiSecrets.geminiModel.isNotEmpty) return ApiSecrets.geminiModel;
    const fromDefine = String.fromEnvironment('GEMINI_MODEL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return _env('GEMINI_MODEL').isNotEmpty
        ? _env('GEMINI_MODEL')
        : 'gemini-2.5-flash';
  }

  static String get geminiConfigurationHint {
    if (geminiApiKey.isNotEmpty) return '';
    return 'Add GEMINI_API_KEY to your .env file (local) or GitHub Secrets / --dart-define (CI).';
  }

  // ── PayMongo ─────────────────────────────────────────────────────────────────
  //
  // PayMongo API calls are proxied through a Cloudflare Worker to bypass
  // browser CORS restrictions on Flutter Web.
  //
  // The Flutter app only needs:
  //   1. PAYMONGO_ENABLED=true  — shows the online payment option
  //   2. PAYMONGO_FUNCTIONS_BASE — the Cloudflare Worker URL
  //
  // The secret key lives inside the Cloudflare Worker (server-side only)
  // and is never embedded in the Flutter bundle.

  static bool get isPayMongoConfigured {
    const fromDefine = String.fromEnvironment('PAYMONGO_ENABLED');
    if (fromDefine == 'true') return true;
    if (fromDefine == 'false') return false;

    final fromEnv = _env('PAYMONGO_ENABLED');
    if (fromEnv == 'true') return true;
    if (fromEnv == 'false') return false;

    // Legacy backwards-compat: secret key present in env = enabled.
    if (ApiSecrets.paymongoSecretKey.isNotEmpty) return true;
    const legacyDefine = String.fromEnvironment('PAYMONGO_SECRET_KEY');
    if (legacyDefine.isNotEmpty) return true;
    if (_env('PAYMONGO_SECRET_KEY').isNotEmpty) return true;

    return false;
  }

  static String get paymongoFunctionsBase {
    const fromDefine = String.fromEnvironment('PAYMONGO_FUNCTIONS_BASE');
    if (fromDefine.isNotEmpty) return fromDefine;
    return _env('PAYMONGO_FUNCTIONS_BASE');
  }

  static String get paymongoConfigHint {
    if (isPayMongoConfigured) return '';
    return 'Online payments are not configured. '
        'Set PAYMONGO_ENABLED=true in your .env or CI secrets.';
  }
}
