import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

/// Shared "upload a file, get back a URL" helper — the same unsigned-preset
/// Cloudinary flow report_repository.dart pioneered for evidence files, now
/// reused by resident ID/face verification photos (auth_repository.dart)
/// and admin-uploaded alarm sounds (admin_repository.dart) so this HTTP
/// multipart logic only exists in one place.
class CloudinaryUploader {
  CloudinaryUploader._();

  static Future<String> upload(File file) async {
    final request = http.MultipartRequest('POST', CloudinaryConfig.uploadUrl)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

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
