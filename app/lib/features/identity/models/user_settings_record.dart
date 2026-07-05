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
    return UserSettingsRecord(
      accentColorKey: data['accentColorKey']?.toString() ?? 'coral',
      hapticsEnabled: data['hapticsEnabled'] == true,
      audioOutputPreference:
          data['audioOutputPreference']?.toString() ?? 'speaker',
      autoOnlineOnLaunch: data['autoOnlineOnLaunch'] == true,
      updatedAt: _readInt(data['updatedAt']),
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
