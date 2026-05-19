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
  // The secret key is used exclusively to call the PayMongo Links API (POST
  // /v1/links) which creates a hosted checkout URL. The customer's payment
  // is taken on PayMongo's own servers — the key never touches card data.
  //
  // Security posture for Flutter Web (no backend):
  //   • Key is embedded in the compiled JS bundle (same as Stripe.js on web).
  //   • Restrict your PayMongo key in the dashboard: whitelist your Firebase
  //     Hosting domain and enable IP rate-limiting.
  //   • For production with real transactions, move link creation to a
  //     Firebase Cloud Function to keep the key fully server-side.

  static String get paymongoSecretKey {
    if (ApiSecrets.paymongoSecretKey.isNotEmpty) {
      return ApiSecrets.paymongoSecretKey;
    }
    const fromDefine = String.fromEnvironment('PAYMONGO_SECRET_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['PAYMONGO_SECRET_KEY'] ?? '';
  }

  static bool get isPayMongoConfigured => paymongoSecretKey.isNotEmpty;

  static String get paymongoConfigHint {
    if (isPayMongoConfigured) return '';
    return 'Add PAYMONGO_SECRET_KEY to your .env file (local) or GitHub Secrets (CI).';
  }
}
