class AppUserProfile {
  const AppUserProfile({
    required this.userId,
    required this.displayName,
    required this.authProvider,
    required this.accountState,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  final String userId;
  final String displayName;
  final String authProvider;
  final String accountState;
  final int createdAt;
  final int updatedAt;
  final int lastSeenAt;

  Map<String, Object?> toJson() {
    return {
      'displayName': displayName,
      'authProvider': authProvider,
      'accountState': accountState,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastSeenAt': lastSeenAt,
    };
  }

  static AppUserProfile fromJson(String userId, Map<Object?, Object?> data) {
    return AppUserProfile(
      userId: userId,
      displayName: data['displayName']?.toString() ?? '',
      authProvider: data['authProvider']?.toString() ?? 'anonymous',
      accountState: data['accountState']?.toString() ?? 'active',
      createdAt: _readInt(data['createdAt']),
      updatedAt: _readInt(data['updatedAt']),
      lastSeenAt: _readInt(data['lastSeenAt']),
    );
  }

  AppUserProfile copyWith({
    String? displayName,
    int? updatedAt,
    int? lastSeenAt,
  }) {
    return AppUserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      authProvider: authProvider,
      accountState: accountState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
