import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static CloudinaryPublic get cloudinary => CloudinaryPublic(
    dotenv.env['CLOUDINARY_CLOUD_NAME']!,
    'clothnear_upload',
    cache: false,
  );

  // Upload from file path
  static Future<String> uploadFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found at path: $filePath');
      }

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          folder: 'clothnear',
          resourceType: CloudinaryResourceType.Auto,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload from bytes — primary method for Windows
  static Future<String> uploadBytes(List<int> bytes, String fileName) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('File bytes are empty');
      }

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: fileName,
          folder: 'clothnear',
          resourceType: CloudinaryResourceType.Auto,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }
}
