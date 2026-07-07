class UserSettingsRecord {
  const UserSettingsRecord({
    required this.accentColorKey,
    required this.hapticsEnabled,
    required this.audioOutputPreference,
    required this.autoOnlineOnLaunch,
    required this.updatedAt,
  });

  final String accentColorKey;
  final bool hapticsEnabled;
  final String audioOutputPreference;
  final bool autoOnlineOnLaunch;
  final int updatedAt;

  Map<String, Object?> toJson() {
    return {
      'accentColorKey': accentColorKey,
      'hapticsEnabled': hapticsEnabled,
      'audioOutputPreference': audioOutputPreference,
      'autoOnlineOnLaunch': autoOnlineOnLaunch,
      'updatedAt': updatedAt,
    };
  }

  static UserSettingsRecord defaults(int now) {
    return UserSettingsRecord(
      accentColorKey: 'coral',
      hapticsEnabled: true,
      audioOutputPreference: 'speaker',
      autoOnlineOnLaunch: false,
      updatedAt: now,
    );
  }

  static UserSettingsRecord fromJson(Map<Object?, Object?> data) {
    final audioOutputPreference = data['audioOutputPreference']?.toString();

    return UserSettingsRecord(
      accentColorKey: data['accentColorKey']?.toString() ?? 'coral',
      hapticsEnabled: data.containsKey('hapticsEnabled')
          ? data['hapticsEnabled'] == true
          : true,
      audioOutputPreference: audioOutputPreference == 'earpiece'
          ? 'earpiece'
          : 'speaker',
      autoOnlineOnLaunch: data['autoOnlineOnLaunch'] == true,
      updatedAt: _readInt(data['updatedAt']),
    );
  }

  UserSettingsRecord copyWith({
    String? accentColorKey,
    bool? hapticsEnabled,
    String? audioOutputPreference,
    bool? autoOnlineOnLaunch,
    int? updatedAt,
  }) {
    return UserSettingsRecord(
      accentColorKey: accentColorKey ?? this.accentColorKey,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      audioOutputPreference:
          audioOutputPreference ?? this.audioOutputPreference,
      autoOnlineOnLaunch: autoOnlineOnLaunch ?? this.autoOnlineOnLaunch,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
