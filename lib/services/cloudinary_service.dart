import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static final CloudinaryPublic cloudinary = CloudinaryPublic(
    dotenv.env['CLOUDINARY_CLOUD_NAME']!,
    'clothnear_uploads',
    cache: false,
  );

  // Upload from file path (desktop/mobile)
  static Future<String> uploadFile(String filePath) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(filePath, folder: 'clothnear'),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload from bytes (for web or when path is unavailable)
  static Future<String> uploadBytes(List<int> bytes, String fileName) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: fileName,
          folder: 'clothnear',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }
}
