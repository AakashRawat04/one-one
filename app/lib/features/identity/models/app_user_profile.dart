class AppUserProfile {
  const AppUserProfile({
    required this.userId,
    required this.displayName,
    required this.authProvider,
    required this.accountState,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
    this.profilePhotoBase64,
  });

  final String userId;
  final String displayName;
  final String authProvider;
  final String accountState;
  final int createdAt;
  final int updatedAt;
  final int lastSeenAt;
  final String? profilePhotoBase64;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{
      'displayName': displayName,
      'authProvider': authProvider,
      'accountState': accountState,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastSeenAt': lastSeenAt,
    };

    if (profilePhotoBase64 != null) {
      data['profilePhotoBase64'] = profilePhotoBase64;
    }

    return data;
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
      profilePhotoBase64: data['profilePhotoBase64']?.toString(),
    );
  }

  AppUserProfile copyWith({
    String? displayName,
    int? updatedAt,
    int? lastSeenAt,
    String? profilePhotoBase64,
  }) {
    return AppUserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      authProvider: authProvider,
      accountState: accountState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      profilePhotoBase64: profilePhotoBase64 ?? this.profilePhotoBase64,
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
