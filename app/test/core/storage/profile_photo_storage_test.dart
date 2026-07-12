import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:one_one_app/core/storage/profile_photo_storage.dart';

void main() {
  test('unsigned upload contains only supported Cloudinary fields', () async {
    final client = _RecordingClient();
    final storage = ProfilePhotoStorage(httpClient: client);

    final url = await storage.uploadProfilePhoto(
      userId: 'user-123',
      imageBytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(url, 'https://res.cloudinary.com/example/profile.jpg');
    final request = client.request;
    expect(request, isA<http.MultipartRequest>());

    final fields = (request! as http.MultipartRequest).fields;
    expect(fields['upload_preset'], 'one-one');
    expect(fields['folder'], 'one_one/profile_photos');
    expect(fields['context'], 'user_id=user-123');
    expect(fields, isNot(contains('overwrite')));
    expect(fields, isNot(contains('unique_filename')));
    expect(fields, isNot(contains('public_id')));
  });
}

class _RecordingClient extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    final body = jsonEncode({
      'secure_url': 'https://res.cloudinary.com/example/profile.jpg',
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
