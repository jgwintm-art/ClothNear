// Default for local development (empty). GitHub Actions overwrites this file
// before `flutter build web` with the real key from repository secrets.
abstract class ApiSecrets {
  static const String geminiApiKey = '';
  static const String geminiModel = 'gemini-2.5-flash';
}
