/// Maps internal diagnostic strings to copy that is safe to show in the UI.
///
/// Worker names (`W1`, `FCM-W2`), channel IDs, and FCM checkpoints belong in
/// Crashlytics / logcat — never in SnackBars, banners, or notifications.
abstract final class UserFacingCopy {
  /// FCM rejected every registered device (stale token, force-stop, etc.).
  static const notificationDeliveryFailure =
      'Couldn\u2019t reach their device. Ask them to open Duo with this account.';

  /// Friend is in the group but has no active FCM registration — common when
  /// they signed into a different Duo account on that phone.
  static const recipientDeviceUnavailable =
      'They\u2019re not reachable on this Duo account. '
      'Ask them to open Duo signed into the account in this group.';

  /// Named variant of [recipientDeviceUnavailable].
  static String recipientDeviceUnavailableFor(Iterable<String> displayNames) {
    final who = joinFirstNames(displayNames);
    if (who == null) return recipientDeviceUnavailable;
    final verb = _isPlural(displayNames) ? 'aren\u2019t' : 'isn\u2019t';
    return '$who $verb reachable on this Duo account. '
        'Ask them to open Duo signed into the account in this group.';
  }

  /// Named variant of [notificationDeliveryFailure].
  static String notificationDeliveryFailureFor(Iterable<String> displayNames) {
    final who = joinFirstNames(displayNames);
    if (who == null) return notificationDeliveryFailure;
    if (_isPlural(displayNames)) {
      return 'Couldn\u2019t reach $who. Ask them to open Duo with this account.';
    }
    return 'Couldn\u2019t reach $who\u2019s device. '
        'Ask them to open Duo with this account.';
  }

  /// Joins first names for sender-facing copy (`Alex`, `Alex and Sam`, …).
  static String? joinFirstNames(Iterable<String> displayNames) {
    final names = displayNames
        .map(_firstName)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) return null;
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}';
  }

  static bool _isPlural(Iterable<String> displayNames) {
    return displayNames
            .map(_firstName)
            .where((name) => name.isNotEmpty)
            .length >
        1;
  }

  static String _firstName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Checkpoint codes such as `FCM-W1`, `FCM-BE-W1`, `DART-W1`, `[FCM-W2]`.
  static final _checkpointCode = RegExp(
    r'\[OneOneFCM\]'
    r'|\b[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[WE]\d+\b'
    r'|\[(?:FCM|DART|NUDGE)[^\]]*\]'
    r'|walkie_alerts(?:_v\d+)?'
    r'|\bvoice_nudges\b',
    caseSensitive: false,
  );

  /// Phrases like "W1 and W2 notification handling".
  static final _workerPhrase = RegExp(
    r'\bW\d+\b(?:\s*(?:and|/|,)\s*\bW\d+\b)*.{0,40}'
    r'(?:notification|handling|worker|checkpoint|FCM)'
    r'|(?:notification|handling|worker|checkpoint|FCM).{0,40}\bW\d+\b',
    caseSensitive: false,
  );

  static bool containsInternalIdentifier(String text) {
    return _checkpointCode.hasMatch(text) || _workerPhrase.hasMatch(text);
  }

  /// Returns [fallback] when [error] contains worker / channel / FCM internals.
  static String sanitize(
    Object error, {
    String fallback = notificationDeliveryFailure,
  }) {
    final text = error.toString().trim();
    if (text.isEmpty || containsInternalIdentifier(text)) return fallback;
    return text;
  }
}

/// Structured Crashlytics `information` lines for FCM handling failures.
abstract final class FcmHandlingContext {
  static const failureReason = 'fcm_notification_handling_failure';

  static List<String> information({
    required String worker,
    String? groupId,
    String? eventId,
    String? kind,
    DateTime? timestamp,
    required bool inBackground,
  }) {
    final time = (timestamp ?? DateTime.now().toUtc())
        .toUtc()
        .toIso8601String();
    return [
      'worker: $worker',
      'groupId: ${groupId?.trim().isNotEmpty == true ? groupId : '-'}',
      'eventId: ${eventId?.trim().isNotEmpty == true ? eventId : '-'}',
      'kind: ${kind?.trim().isNotEmpty == true ? kind : '-'}',
      'timestamp: $time',
      'appState: ${inBackground ? 'background' : 'foreground'}',
    ];
  }
}
