// Default for local development (empty). GitHub Actions overwrites before release build.
abstract class ApiSecrets {
  static const String geminiApiKey = '';
  static const String geminiModel = 'gemini-2.5-flash';
  static const String ciBuildId = 'local';
}
