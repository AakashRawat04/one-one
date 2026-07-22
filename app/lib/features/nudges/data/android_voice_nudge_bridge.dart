import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidVoiceNudgeBridge {
  static const MethodChannel _channel = MethodChannel('app.oneone/voice_nudge');
  static final StreamController<void> _actionSignals =
      StreamController<void>.broadcast();
  static final StreamController<void> _registrationSignals =
      StreamController<void>.broadcast();
  static bool _handlerInstalled = false;

  static Stream<void> get actionSignals {
    _installHandler();
    return _actionSignals.stream;
  }

  static Stream<void> get registrationSignals {
    _installHandler();
    return _registrationSignals.stream;
  }

  static void _installHandler() {
    if (_handlerInstalled || !Platform.isAndroid) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNudgeActionAvailable') {
        _actionSignals.add(null);
      } else if (call.method == 'onFcmRegistrationRenewed') {
        debugPrint('[OneOneFCM][DART-06] Native registration renewed');
        _registrationSignals.add(null);
      }
    });
  }

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

  Future<NudgeNotificationAction?> takePendingNudgeAction() async {
    if (!Platform.isAndroid) return null;
    _installHandler();
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'takePendingNudgeAction',
    );
    if (raw == null) return null;
    return NudgeNotificationAction.tryParse(raw);
  }
}

class NudgeNotificationAction {
  const NudgeNotificationAction({
    required this.action,
    required this.eventId,
    required this.groupId,
  });

  final String action;
  final String eventId;
  final String groupId;

  static NudgeNotificationAction? tryParse(Map<String, dynamic> raw) {
    final action = raw['action']?.toString().trim() ?? '';
    final eventId = raw['eventId']?.toString().trim() ?? '';
    final groupId = raw['groupId']?.toString().trim() ?? '';
    if (!const {'accept', 'connect'}.contains(action) ||
        eventId.isEmpty ||
        groupId.isEmpty) {
      return null;
    }
    return NudgeNotificationAction(
      action: action,
      eventId: eventId,
      groupId: groupId,
    );
  }
}

String _suffix(String value) =>
    value.length <= 6 ? value : value.substring(value.length - 6);
