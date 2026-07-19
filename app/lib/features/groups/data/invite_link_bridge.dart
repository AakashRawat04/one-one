import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class InviteLinkBridge {
  static const MethodChannel _channel = MethodChannel(
    'app.oneone/invite_links',
  );
  static final StreamController<void> _linkSignals =
      StreamController<void>.broadcast();
  static bool _handlerInstalled = false;

  static Stream<void> get linkSignals {
    _installHandler();
    return _linkSignals.stream;
  }

  static void _installHandler() {
    if (_handlerInstalled || !Platform.isAndroid) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onInviteLinkAvailable') {
        _linkSignals.add(null);
      }
    });
  }

  Future<String?> peekPendingInviteCode() async {
    if (!Platform.isAndroid) return null;
    _installHandler();
    final code = await _channel.invokeMethod<String>('peekPendingInviteCode');
    return code?.trim().takeIfNotEmpty();
  }

  Future<void> clearPendingInviteCode(String code) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('clearPendingInviteCode', code);
  }

  Future<void> shareInviteLink(String inviteUrl) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Native invite sharing is Android-only.');
    }
    await _channel.invokeMethod<void>('shareInviteLink', inviteUrl);
  }
}

extension on String {
  String? takeIfNotEmpty() => isEmpty ? null : this;
}
