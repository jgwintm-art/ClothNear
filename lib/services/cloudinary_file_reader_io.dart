import 'dart:io';
import 'dart:typed_data';

/// Native (mobile/desktop) implementation of readFileBytes.
///
/// Selected by the Dart compiler when dart.library.io IS available —
/// i.e., Android, iOS, macOS, Windows, Linux.
///
/// Uses dart:io directly. This file is NEVER compiled for Flutter Web,
/// so the dart:io import does not affect web builds.
Future<Uint8List> readFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileSystemException('File not found', path);
  }
  return file.readAsBytes();
}
