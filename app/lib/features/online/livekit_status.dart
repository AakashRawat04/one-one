/// Maps LiveKit / connection internals to short, user-facing status copy.
class LiveKitStatus {
  const LiveKitStatus._();

  static const connecting = 'Connecting...';
  static const connected = 'Voice Connected';
  static const reconnecting = 'Reconnecting...';
  static const disconnected = 'Disconnected';
  static const connectionError = 'Couldn’t connect. Try again.';
  static const receivingVoice = 'Receiving voice';
  static const talking = 'Talking';
  static const live = 'Live';
  static const away = 'Away';

  static String fromDisconnectReason(Object? reason) {
    final text = reason?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null' || text.toLowerCase() == 'none') {
      return disconnected;
    }
    // Never surface raw SDK enums / stack-ish strings.
    return disconnected;
  }

  static String sanitizeError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('token') ||
        lower.contains('livekit') ||
        lower.contains('wss://') ||
        lower.contains('ws://') ||
        lower.contains('exception') ||
        lower.contains('stack')) {
      return connectionError;
    }
    // Keep short, non-technical app errors (e.g. talk lock busy).
    if (text.length <= 80 && !text.contains('{') && !text.contains('://')) {
      return text;
    }
    return connectionError;
  }

  /// LiveKit participant identity is `groupId:userId:deviceId`.
  static String? userIdFromIdentity(String? identity) {
    if (identity == null || identity.isEmpty) return null;
    final parts = identity.split(':');
    if (parts.length >= 2 && parts[1].isNotEmpty) return parts[1];
    return identity;
  }
}
