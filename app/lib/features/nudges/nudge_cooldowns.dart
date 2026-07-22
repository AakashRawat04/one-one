/// Configurable client-side cooldown/anti-spam constants for nudges.
///
/// These mirror the backend's authoritative limits (see
/// `backend/src/config.ts` and `backend/src/notifications/nudgeRateLimiter.ts`)
/// so the UI can disable actions and show a countdown *before* a request is
/// even sent, instead of only reacting to a `nudge_rate_limited` error after
/// a round trip. The backend remains the source of truth; these values only
/// drive local UX and should be kept in sync with the server defaults.
class NudgeCooldowns {
  NudgeCooldowns._();

  static const Duration ring = Duration(seconds: 20);
  static const Duration voice = Duration(seconds: 60);
  static const Duration push = Duration(seconds: 10);

  /// Anti-spam guard: max nudges (any type) allowed within [spamWindow].
  static const Duration spamWindow = Duration(minutes: 5);
  static const int spamMaxPerWindow = 10;
}

/// The kind of nudge a cooldown applies to. Kept distinct from any backend
/// wire type so the UI layer doesn't need to depend on server DTOs.
enum NudgeKind { ring, voice, push }

/// Tracks the most recent send time per [NudgeKind] for the lifetime of the
/// app process. Intentionally in-memory only (not persisted): it exists to
/// give the sender immediate, local feedback that mirrors the backend
/// cooldown, not to be a durable record of nudge history.
class NudgeCooldownTracker {
  NudgeCooldownTracker._();

  static final NudgeCooldownTracker instance = NudgeCooldownTracker._();

  final Map<NudgeKind, DateTime> _lastSentAt = {};
  final List<DateTime> _recentSends = [];

  Duration _cooldownFor(NudgeKind kind) {
    switch (kind) {
      case NudgeKind.ring:
        return NudgeCooldowns.ring;
      case NudgeKind.voice:
        return NudgeCooldowns.voice;
      case NudgeKind.push:
        return NudgeCooldowns.push;
    }
  }

  /// Remaining cooldown for [kind], or [Duration.zero] if it may be sent now.
  Duration remaining(NudgeKind kind, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final lastSent = _lastSentAt[kind];
    final typeCooldown = _cooldownFor(kind);
    var longest = Duration.zero;
    if (lastSent != null) {
      final elapsed = currentTime.difference(lastSent);
      final left = typeCooldown - elapsed;
      if (left > longest) longest = left;
    }

    final spamLeft = _spamWindowRemaining(currentTime);
    if (spamLeft > longest) longest = spamLeft;
    return longest;
  }

  /// Whether the spam guard (max sends per rolling window) is currently
  /// blocking every nudge type, regardless of per-type cooldowns.
  Duration _spamWindowRemaining(DateTime now) {
    _recentSends.removeWhere(
      (sentAt) => now.difference(sentAt) > NudgeCooldowns.spamWindow,
    );
    if (_recentSends.length < NudgeCooldowns.spamMaxPerWindow) {
      return Duration.zero;
    }
    final oldest = _recentSends.first;
    final left = NudgeCooldowns.spamWindow - now.difference(oldest);
    return left.isNegative ? Duration.zero : left;
  }

  /// Records a successful send so subsequent [remaining] calls reflect it.
  void record(NudgeKind kind, {DateTime? now}) {
    final sentAt = now ?? DateTime.now();
    _lastSentAt[kind] = sentAt;
    _recentSends.add(sentAt);
  }
}
