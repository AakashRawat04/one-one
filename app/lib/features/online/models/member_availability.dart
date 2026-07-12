class MemberAvailability {
  const MemberAvailability({
    required this.desiredState,
    required this.effectiveState,
    required this.canReceiveLiveAudio,
    this.staleAfterAt,
  });

  static const MemberAvailability away = MemberAvailability(
    desiredState: 'away',
    effectiveState: 'away',
    canReceiveLiveAudio: false,
  );

  final String desiredState;
  final String effectiveState;
  final bool canReceiveLiveAudio;
  final int? staleAfterAt;

  factory MemberAvailability.fromJson(Map<Object?, Object?> data) {
    return MemberAvailability(
      desiredState: data['desiredState']?.toString() ?? 'away',
      effectiveState: data['effectiveState']?.toString() ?? 'away',
      canReceiveLiveAudio: data['canReceiveLiveAudio'] == true,
      staleAfterAt: _readInt(data['staleAfterAt']),
    );
  }

  bool get isLive => isLiveAt(
    DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
  );

  bool isLiveAt(int epochSeconds) {
    final expiresAt = staleAfterAt;
    if (expiresAt != null && expiresAt <= epochSeconds) return false;
    if (desiredState != 'online' || !canReceiveLiveAudio) return false;

    return effectiveState == 'live' ||
        effectiveState == 'talking' ||
        effectiveState == 'listening' ||
        effectiveState == 'connected';
  }

  String get label {
    return switch (effectiveState) {
      'talking' => 'Talking',
      'live' => 'Live',
      'connected' => 'Live',
      'connecting' => 'Connecting',
      'listening' => 'Listening',
      'away' => 'Away',
      _ => desiredState == 'online' ? 'Online' : 'Away',
    };
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
