class UserDeviceRecord {
  const UserDeviceRecord({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.installId,
    required this.micPermissionGranted,
    required this.notificationPermissionGranted,
    required this.batteryOptimizationIgnored,
    required this.deviceState,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
    this.fcmToken,
  });

  final String deviceId;
  final String platform;
  final String appVersion;
  final String installId;
  final bool micPermissionGranted;
  final bool notificationPermissionGranted;
  final bool batteryOptimizationIgnored;
  final String deviceState;
  final int createdAt;
  final int updatedAt;
  final int lastSeenAt;
  final String? fcmToken;

  Map<String, Object?> toJson() {
    return {
      'platform': platform,
      'appVersion': appVersion,
      'installId': installId,
      'micPermissionGranted': micPermissionGranted,
      'notificationPermissionGranted': notificationPermissionGranted,
      'batteryOptimizationIgnored': batteryOptimizationIgnored,
      'deviceState': deviceState,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastSeenAt': lastSeenAt,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }
}
