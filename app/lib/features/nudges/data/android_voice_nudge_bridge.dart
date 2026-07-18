import 'dart:io';

import 'package:flutter/services.dart';

class AndroidVoiceNudgeBridge {
  static const MethodChannel _channel = MethodChannel(
    'app.oneone/voice_nudge',
  );

  Future<String?> getFcmToken() async {
    if (!Platform.isAndroid) return null;
    final token = await _channel.invokeMethod<String>('getFcmToken');
    final cleanToken = token?.trim();
    return cleanToken == null || cleanToken.isEmpty ? null : cleanToken;
  }
}
