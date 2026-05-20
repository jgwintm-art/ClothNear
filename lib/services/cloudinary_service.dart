import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'cloudinary_file_reader_stub.dart'
    if (dart.library.io) 'cloudinary_file_reader_io.dart';

/// Cloudinary unsigned upload service.
///
/// ── WHY cloudinary_public WAS REPLACED ───────────────────────────────────────
///
/// cloudinary_public 0.23.1 internally depends on dio ^5.3.4. On Flutter Web,
/// dio's BrowserHttpClientAdapter builds multipart bodies using dart:io types
/// (IOSink, File) that do not exist on the web platform. dart2js minifies the
/// resulting TypeError to "Instance of 'minified:X3'". The original catch (e)
/// block then wraps it as "Exception: Failed to upload file: Instance of
/// 'minified:X3'" — hiding the real cause entirely.
///
/// CloudinaryFile.fromFile(path) also calls File(path) from dart:io directly,
/// which throws UnsupportedError on web before any network request is made.
///
/// ── THIS IMPLEMENTATION ───────────────────────────────────────────────────────
///
/// Uses package:http (^1.2.0 — already a direct dependency) which ships a
/// correct BrowserClient for web and a standard IOClient for mobile/desktop.
/// Multipart bodies are always constructed from Uint8List bytes — no dart:io
/// dependency in the HTTP layer at all.
///
/// File reading on mobile/desktop is delegated to a conditional import stub
/// (cloudinary_file_reader_io.dart) that uses dart:io, so the web compiler
/// never sees dart:io symbols.
class CloudinaryService {
  static String get _cloudName {
    const fromDefine = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  }

  static const String _uploadPreset = 'clothnear_upload';
  static const String _folder = 'clothnear';

  // ── Primary method — bytes only, ALL platforms including web ──────────────

  /// Uploads raw [bytes] to Cloudinary and returns the secure CDN URL.
  ///
  /// This is the only upload path that works on Flutter Web.
  ///
  /// Throws [CloudinaryUploadException] with a human-readable message.
  static Future<String> uploadBytes(List<int> bytes, String fileName) async {
    _assertConfigured();

    if (bytes.isEmpty) {
      throw const CloudinaryUploadException(
        'uploadBytes: bytes list is empty — no file data to upload.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
    );

    debugPrint(
      '[Cloudinary] uploadBytes → file: $fileName  '
      '${bytes.length} bytes',
    );

    late http.StreamedResponse streamed;
    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = _folder
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            filename: fileName,
          ),
        );

      streamed = await request.send();
    } on http.ClientException catch (e) {
      debugPrint('[Cloudinary] Network error: $e');
      throw CloudinaryUploadException(
        'Network error during upload: ${e.message}',
      );
    } catch (e, stack) {
      debugPrint('[Cloudinary] Unexpected exception: $e');
      debugPrintStack(
        stackTrace: stack,
        label: 'CloudinaryService.uploadBytes',
      );
      throw CloudinaryUploadException(
        'Unexpected upload error (${e.runtimeType}): ${e.toString()}',
      );
    }

    final responseBody = await streamed.stream.bytesToString();
    debugPrint('[Cloudinary] HTTP status: ${streamed.statusCode}');

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final detail = _extractCloudinaryError(responseBody) ?? responseBody;
      throw CloudinaryUploadException(
        'Cloudinary returned HTTP ${streamed.statusCode}: $detail',
      );
    }

    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final url = json['secure_url'] as String?;

      if (url == null || url.isEmpty) {
        throw CloudinaryUploadException(
          'Cloudinary response missing secure_url.\n'
          'Full response: $responseBody',
        );
      }

      debugPrint('[Cloudinary] ✓ Upload success → $url');
      return url;
    } on CloudinaryUploadException {
      rethrow;
    } catch (e) {
      throw CloudinaryUploadException(
        'Failed to parse Cloudinary response (${e.runtimeType}): $e\n'
        'Response body: $responseBody',
      );
    }
  }

  // ── Mobile/desktop path convenience wrapper ───────────────────────────────

  /// Reads [filePath] to bytes via the platform file system, then uploads.
  ///
  /// Only valid on Android, iOS, macOS, Windows, Linux where file_picker
  /// returns a real path. On Flutter Web, [PlatformFile.path] is always
  /// null — use [uploadBytes] with [PlatformFile.bytes] instead.
  ///
  /// The conditional import ensures dart:io is never referenced on web.
  static Future<String> uploadFile(String filePath) async {
    _assertConfigured();

    debugPrint('[Cloudinary] uploadFile: reading $filePath');

    late Uint8List bytes;
    try {
      bytes = await readFileBytes(filePath); // from conditional import
    } catch (e, stack) {
      debugPrint('[Cloudinary] File read error: $e');
      debugPrintStack(stackTrace: stack, label: 'CloudinaryService.uploadFile');
      throw CloudinaryUploadException(
        'Could not read file at "$filePath" (${e.runtimeType}): $e',
      );
    }

    final fileName = filePath.replaceAll('\\', '/').split('/').last;
    return uploadBytes(bytes, fileName);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static void _assertConfigured() {
    if (_cloudName.isEmpty) {
      throw const CloudinaryUploadException(
        'CLOUDINARY_CLOUD_NAME is not set in .env — '
        'check your .env file and restart the app.',
      );
    }
  }

  static String? _extractCloudinaryError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['error'] as Map<String, dynamic>?)?['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Typed upload exception — surfaces actionable errors instead of
/// minified dart2js strings like "Instance of 'minified:X3'".
class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => 'CloudinaryUploadException: $message';
}
