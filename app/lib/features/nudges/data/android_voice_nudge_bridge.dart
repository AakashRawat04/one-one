import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidVoiceNudgeBridge {
  static const MethodChannel _channel = MethodChannel('app.oneone/voice_nudge');

  Future<String?> getFcmToken() async {
    if (!Platform.isAndroid) return null;
    debugPrint('[OneOneFCM][DART-01] Requesting Android FCM registration');
    try {
      final token = await _channel.invokeMethod<String>('getFcmToken');
      final cleanToken = token?.trim();
      if (cleanToken == null || cleanToken.isEmpty) {
        debugPrint(
          '[OneOneFCM][DART-E1] Native registration returned no identifier',
        );
        return null;
      }
      debugPrint(
        '[OneOneFCM][DART-02] Registration identifier received '
        'length=${cleanToken.length} suffix=${_suffix(cleanToken)}',
      );
      return cleanToken;
    } on PlatformException catch (error) {
      debugPrint(
        '[OneOneFCM][DART-E2] Native registration failed '
        'code=${error.code} message=${error.message}',
      );
      rethrow;
    } catch (error) {
      debugPrint(
        '[OneOneFCM][DART-E3] Registration bridge failed '
        '${error.runtimeType}: $error',
      );
      rethrow;
    }
  }
}

String _suffix(String value) =>
    value.length <= 6 ? value : value.substring(value.length - 6);
