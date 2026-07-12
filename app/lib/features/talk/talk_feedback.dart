import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Short start/stop tones and haptics for push-to-talk / hand-raise.
class TalkFeedback {
  TalkFeedback._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _configured = false;

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.lowLatency);
    _configured = true;
  }

  static Future<void> talkStarted({required bool hapticsEnabled}) async {
    if (hapticsEnabled) {
      await _hapticStart();
    }
    await _playAsset('sounds/talk_start.wav');
  }

  static Future<void> talkStopped({required bool hapticsEnabled}) async {
    if (hapticsEnabled) {
      await _hapticStop();
    }
    await _playAsset('sounds/talk_stop.wav');
  }

  static Future<void> handRaiseChanged({
    required bool raised,
    required bool hapticsEnabled,
  }) async {
    if (!hapticsEnabled) return;
    if (raised) {
      await HapticFeedback.mediumImpact();
    } else {
      await HapticFeedback.selectionClick();
    }
  }

  /// Remote peer raised their hand — notify this device.
  static Future<void> remoteHandRaised({required bool hapticsEnabled}) async {
    if (!hapticsEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  static Future<void> reactionReceived({required bool hapticsEnabled}) async {
    if (!hapticsEnabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> _hapticStart() async {
    // mediumImpact is reliable on both iOS and Android; lightImpact is
    // often too subtle on Android OEMs.
    await HapticFeedback.mediumImpact();
  }

  static Future<void> _hapticStop() async {
    await HapticFeedback.selectionClick();
  }

  static Future<void> _playAsset(String assetPath) async {
    try {
      await _ensureConfigured();
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (error, stack) {
      debugPrint('TalkFeedback play failed: $error\n$stack');
    }
  }
}
