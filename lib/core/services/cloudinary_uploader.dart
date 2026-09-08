import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

/// Shared "upload a file, get back a URL" helper — the same unsigned-preset
/// Cloudinary flow report_repository.dart pioneered for evidence files, now
/// reused by resident ID/face verification photos (auth_repository.dart)
/// and admin-uploaded alarm sounds (admin_repository.dart) so this HTTP
/// multipart logic only exists in one place.
///
/// Takes raw bytes + a filename rather than a dart:io File — File-based
/// uploads (http.MultipartFile.fromPath) only work on native platforms;
/// Flutter Web has no real filesystem, so that path throws "Unsupported
/// operation: MultipartFile is only supported where dart:io is available"
/// the moment it's actually used, even though the code compiles fine.
/// Since the Barangay Admin dashboard is specifically meant to run in a
/// browser (see AdminHomeScreen's doc comment), this had to be fixed at
/// the root rather than only on native — file_picker's `withData: true`
/// already hands back bytes directly on every platform, so callers don't
/// need a File at all anymore.
class CloudinaryUploader {
  CloudinaryUploader._();

  static Future<String> uploadBytes(Uint8List bytes, {required String filename}) async {
    final request = http.MultipartRequest('POST', CloudinaryConfig.uploadUrl)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = body['secure_url'] as String?;
    if (url == null) {
      throw Exception('Cloudinary upload succeeded but no secure_url found in response.');
    }
    return url;
  }
}
