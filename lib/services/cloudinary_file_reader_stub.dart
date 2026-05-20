import 'dart:typed_data';

/// Web stub — file path reading is not supported on Flutter Web.
///
/// This file is selected by the Dart compiler when dart.library.io is NOT
/// available (i.e., Flutter Web). It throws immediately with a clear message
/// rather than a minified runtime error.
///
/// The web calling path should never reach here because file_picker on web
/// returns null for PlatformFile.path, and all web-side callers use
/// uploadBytes(file.bytes!, fileName) instead.
Future<Uint8List> readFileBytes(String path) async {
  throw UnsupportedError(
    'readFileBytes is not supported on Flutter Web. '
    'Use CloudinaryService.uploadBytes(file.bytes!, fileName) instead.',
  );
}
