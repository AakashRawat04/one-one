import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../app/app_config.dart';

class ProfilePhotoStorageException implements Exception {
  const ProfilePhotoStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfilePhotoStorage {
  ProfilePhotoStorage({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> uploadProfilePhoto({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    final cloudName = AppConfig.cloudinaryCloudName.trim();
    final uploadPreset = AppConfig.cloudinaryUploadPreset.trim();

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw const ProfilePhotoStorageException(
        'Profile photo storage is not configured. Set ONE_ONE_CLOUDINARY_CLOUD_NAME '
        'and ONE_ONE_CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    );
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = AppConfig.cloudinaryProfileFolder;
    request.fields['public_id'] = userId;
    request.fields['overwrite'] = 'true';
    request.fields['unique_filename'] = 'false';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'profile.jpg',
      ),
    );

    final streamedResponse = await _httpClient.send(request);
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw ProfilePhotoStorageException(
        'Profile photo upload failed (${streamedResponse.statusCode}): '
        '$responseBody',
      );
    }

    final payload = jsonDecode(responseBody);
    if (payload is! Map<String, dynamic>) {
      throw const ProfilePhotoStorageException(
        'Profile photo upload returned an unexpected response.',
      );
    }

    final secureUrl = payload['secure_url']?.toString();
    if (secureUrl == null || secureUrl.isEmpty) {
      throw const ProfilePhotoStorageException(
        'Profile photo upload did not return a secure URL.',
      );
    }

    return secureUrl;
  }
}
