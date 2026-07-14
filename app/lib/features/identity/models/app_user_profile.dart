class AppUserProfile {
  const AppUserProfile({
    required this.userId,
    required this.displayName,
    required this.authProvider,
    required this.accountState,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
    this.profilePhotoUrl,
    this.profilePhotoBase64,
  });

  final String userId;
  final String displayName;
  final String authProvider;
  final String accountState;
  final int createdAt;
  final int updatedAt;
  final int lastSeenAt;
  final String? profilePhotoUrl;
  final String? profilePhotoBase64;

  bool get hasProfilePhoto {
    final url = profilePhotoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return true;
    }

    final encodedPhoto = profilePhotoBase64?.trim();
    return encodedPhoto != null && encodedPhoto.isNotEmpty;
  }

  Map<String, Object?> toJson() {
    final data = <String, Object?>{
      'displayName': displayName,
      'authProvider': authProvider,
      'accountState': accountState,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastSeenAt': lastSeenAt,
    };

    if (profilePhotoUrl != null) {
      data['profilePhotoUrl'] = profilePhotoUrl;
    }

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
      profilePhotoUrl: data['profilePhotoUrl']?.toString(),
      profilePhotoBase64: data['profilePhotoBase64']?.toString(),
    );
  }

  AppUserProfile copyWith({
    String? displayName,
    String? authProvider,
    int? updatedAt,
    int? lastSeenAt,
    String? profilePhotoUrl,
    String? profilePhotoBase64,
    bool clearProfilePhotoUrl = false,
    bool clearProfilePhotoBase64 = false,
  }) {
    return AppUserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      authProvider: authProvider ?? this.authProvider,
      accountState: accountState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      profilePhotoUrl: clearProfilePhotoUrl
          ? null
          : (profilePhotoUrl ?? this.profilePhotoUrl),
      profilePhotoBase64: clearProfilePhotoBase64
          ? null
          : (profilePhotoBase64 ?? this.profilePhotoBase64),
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
