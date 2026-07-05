class UserDeviceRecord {
  const UserDeviceRecord({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.installId,
    required this.fcmToken,
    required this.micPermissionGranted,
    required this.notificationPermissionGranted,
    required this.batteryOptimizationIgnored,
    required this.deviceState,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  final String deviceId;
  final String platform;
  final String appVersion;
  final String installId;
  final String? fcmToken;
  final bool micPermissionGranted;
  final bool notificationPermissionGranted;
  final bool batteryOptimizationIgnored;
  final String deviceState;
  final int createdAt;
  final int updatedAt;
  final int lastSeenAt;

  Map<String, Object?> toJson() {
    return {
      'platform': platform,
      'appVersion': appVersion,
      'installId': installId,
      'fcmToken': fcmToken,
      'micPermissionGranted': micPermissionGranted,
      'notificationPermissionGranted': notificationPermissionGranted,
      'batteryOptimizationIgnored': batteryOptimizationIgnored,
      'deviceState': deviceState,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastSeenAt': lastSeenAt,
    };
  }
}
