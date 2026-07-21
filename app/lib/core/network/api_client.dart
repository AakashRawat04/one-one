import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';

class ApiClient {
  ApiClient({FirebaseAuth? auth, http.Client? httpClient, String? baseUrl})
    : _auth = auth ?? FirebaseAuth.instance,
      _httpClient = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
        RegExp(r'/$'),
        '',
      );

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String _baseUrl;

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final token = await _auth.currentUser?.getIdToken();

    if (token == null) {
      throw StateError('Cannot call backend before Firebase sign-in.');
    }

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final responseBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        code: responseBody['error']?.toString() ?? 'request_failed',
        message: responseBody['message']?.toString() ?? response.body,
      );
    }

    return responseBody;
  }

  Future<Map<String, dynamic>> postBytes(
    String path,
    List<int> bytes, {
    required String contentType,
    Map<String, String> headers = const {},
  }) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('Cannot call backend before Firebase sign-in.');
    }

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': contentType,
        ...headers,
      },
      body: bytes,
    );
    final responseBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        code: responseBody['error']?.toString() ?? 'request_failed',
        message: responseBody['message']?.toString() ?? response.body,
      );
    }
    return responseBody;
  }

  /// PUT bytes to an absolute URL (e.g. Cloud Storage signed write URL).
  /// Does not attach Firebase Auth — the signed URL is the credential.
  Future<void> putBytesToUrl(
    String absoluteUrl,
    List<int> bytes, {
    required Map<String, String> headers,
  }) async {
    final response = await _httpClient.put(
      Uri.parse(absoluteUrl),
      headers: headers,
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'storage_upload_failed',
        message: response.body.isEmpty
            ? 'Cloud Storage upload failed with HTTP ${response.statusCode}'
            : response.body,
      );
    }
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}
