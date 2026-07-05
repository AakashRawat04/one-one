import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_user_profile.dart';
import '../models/identity_session.dart';
import '../models/user_device_record.dart';
import '../models/user_settings_record.dart';
import 'device_identity_store.dart';

class IdentityRepository {
  IdentityRepository({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    FirebaseMessaging? messaging,
    DeviceIdentityStore? deviceIdentityStore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final FirebaseMessaging _messaging;
  final DeviceIdentityStore _deviceIdentityStore;

  StreamSubscription<String>? _fcmTokenSubscription;
  String? _latestUserId;
  String? _latestDeviceId;

  Future<IdentitySession> ensureIdentity() async {
    final firebaseUser = await _ensureAnonymousUser();
    final now = _nowSeconds();
    final localDevice = await _deviceIdentityStore.getOrCreate();
    final appVersion = await _readAppVersion();
    final fcmToken = await _readFcmToken();
    final permissions = await _readPermissionDiagnostics();

    final user = await _upsertUserProfile(firebaseUser.uid, now);
    final settings = await _ensureUserSettings(firebaseUser.uid, now);
    final device = await _upsertUserDevice(
      userId: firebaseUser.uid,
      localDevice: localDevice,
      appVersion: appVersion,
      fcmToken: fcmToken,
      permissions: permissions,
      now: now,
    );

    _latestUserId = firebaseUser.uid;
    _latestDeviceId = localDevice.deviceId;

    return IdentitySession(user: user, device: device, settings: settings);
  }

  Future<IdentitySession> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update display name before sign-in.');
    }

    final cleanName = displayName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    final now = _nowSeconds();
    await _database.ref('users/${user.uid}').update({
      'displayName': cleanName,
      'updatedAt': now,
      'lastSeenAt': now,
    });

    return ensureIdentity();
  }

  void startFcmTokenRefreshListener() {
    _fcmTokenSubscription ??= _messaging.onTokenRefresh.listen((token) {
      final userId = _latestUserId;
      final deviceId = _latestDeviceId;

      if (userId == null || deviceId == null) return;

      _database.ref('userDevices/$userId/$deviceId').update({
        'fcmToken': token,
        'updatedAt': _nowSeconds(),
        'lastSeenAt': _nowSeconds(),
      });
    });
  }

  void dispose() {
    _fcmTokenSubscription?.cancel();
    _fcmTokenSubscription = null;
  }

  Future<User> _ensureAnonymousUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return currentUser;
    }

    final credential = await _auth.signInAnonymously();
    final user = credential.user;

    if (user == null) {
      throw StateError('Firebase anonymous sign-in returned no user.');
    }

    return user;
  }

  Future<AppUserProfile> _upsertUserProfile(String userId, int now) async {
    final ref = _database.ref('users/$userId');
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
      final existing = AppUserProfile.fromJson(
        userId,
        snapshot.value! as Map<Object?, Object?>,
      );
      final updated = existing.copyWith(updatedAt: now, lastSeenAt: now);
      await ref.update({'updatedAt': now, 'lastSeenAt': now});
      return updated;
    }

    final profile = AppUserProfile(
      userId: userId,
      displayName: _defaultDisplayName(userId),
      authProvider: 'anonymous',
      accountState: 'active',
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now,
    );
    await ref.set(profile.toJson());
    return profile;
  }

  Future<UserSettingsRecord> _ensureUserSettings(String userId, int now) async {
    final ref = _database.ref('userSettings/$userId');
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
      return UserSettingsRecord.fromJson(
        snapshot.value! as Map<Object?, Object?>,
      );
    }

    final settings = UserSettingsRecord.defaults(now);
    await ref.set(settings.toJson());
    return settings;
  }

  Future<UserDeviceRecord> _upsertUserDevice({
    required String userId,
    required LocalDeviceIdentity localDevice,
    required String appVersion,
    required String? fcmToken,
    required _PermissionDiagnostics permissions,
    required int now,
  }) async {
    final ref = _database.ref('userDevices/$userId/${localDevice.deviceId}');
    final snapshot = await ref.get();
    int createdAt = now;

    if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
      final data = snapshot.value! as Map<Object?, Object?>;
      createdAt = _readInt(data['createdAt'], fallback: now);
    }

    final device = UserDeviceRecord(
      deviceId: localDevice.deviceId,
      platform: Platform.isAndroid ? 'android' : Platform.operatingSystem,
      appVersion: appVersion,
      installId: localDevice.installId,
      fcmToken: fcmToken,
      micPermissionGranted: permissions.micPermissionGranted,
      notificationPermissionGranted: permissions.notificationPermissionGranted,
      batteryOptimizationIgnored: permissions.batteryOptimizationIgnored,
      deviceState: 'active',
      createdAt: createdAt,
      updatedAt: now,
      lastSeenAt: now,
    );

    await ref.set(device.toJson());
    return device;
  }

  Future<String> _readAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Future<String?> _readFcmToken() async {
    try {
      await _messaging.requestPermission();
      return _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<_PermissionDiagnostics> _readPermissionDiagnostics() async {
    bool batteryOptimizationIgnored = false;
    bool notificationPermissionGranted = false;

    try {
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      notificationPermissionGranted =
          notificationPermission == NotificationPermission.granted;
    } catch (_) {
      notificationPermissionGranted = false;
    }

    try {
      batteryOptimizationIgnored =
          await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      batteryOptimizationIgnored = false;
    }

    final micStatus = await Permission.microphone.status;

    if (Platform.isAndroid) {
      try {
        await DeviceInfoPlugin().androidInfo;
      } catch (_) {
        // Device metadata is not stored in the Phase 3 ERD. This call is kept
        // as a plugin smoke path for later diagnostics.
      }
    }

    return _PermissionDiagnostics(
      micPermissionGranted: micStatus.isGranted,
      notificationPermissionGranted: notificationPermissionGranted,
      batteryOptimizationIgnored: batteryOptimizationIgnored,
    );
  }

  String _defaultDisplayName(String userId) {
    final suffix = userId.length >= 4 ? userId.substring(0, 4) : userId;
    return 'Friend $suffix';
  }

  int _nowSeconds() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}

class _PermissionDiagnostics {
  const _PermissionDiagnostics({
    required this.micPermissionGranted,
    required this.notificationPermissionGranted,
    required this.batteryOptimizationIgnored,
  });

  final bool micPermissionGranted;
  final bool notificationPermissionGranted;
  final bool batteryOptimizationIgnored;
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
