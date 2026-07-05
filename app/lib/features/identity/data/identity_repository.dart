import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
    DeviceIdentityStore? deviceIdentityStore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance,
       _deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

  static const Duration _requiredStartupTimeout = Duration(seconds: 20);
  static const Duration _optionalStartupTimeout = Duration(seconds: 4);

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final DeviceIdentityStore _deviceIdentityStore;

  Future<IdentitySession> ensureIdentity() async {
    final firebaseUser = await _requiredStartupStep(
      _ensureAnonymousUser(),
      'Firebase anonymous sign-in',
    );
    final now = _nowSeconds();
    final localDevice = await _requiredStartupStep(
      _deviceIdentityStore.getOrCreate(),
      'local device identity setup',
    );
    final appVersion = await _optionalStartupStep(
      _readAppVersion(),
      fallback: 'unknown',
    );
    final permissions = await _readPermissionDiagnostics();

    final user = await _requiredStartupStep(
      _upsertUserProfile(firebaseUser.uid, now),
      'Firebase Database user profile sync',
    );
    final settings = await _requiredStartupStep(
      _ensureUserSettings(firebaseUser.uid, now),
      'Firebase Database user settings sync',
    );
    final device = await _requiredStartupStep(
      _upsertUserDevice(
        userId: firebaseUser.uid,
        localDevice: localDevice,
        appVersion: appVersion,
        permissions: permissions,
        now: now,
      ),
      'Firebase Database device sync',
    );

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

  void dispose() {}

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

  Future<_PermissionDiagnostics> _readPermissionDiagnostics() async {
    bool batteryOptimizationIgnored = false;
    bool notificationPermissionGranted = false;

    try {
      final notificationPermission = await _optionalStartupValue(
        FlutterForegroundTask.checkNotificationPermission(),
      );
      notificationPermissionGranted =
          notificationPermission == NotificationPermission.granted;
    } catch (_) {
      notificationPermissionGranted = false;
    }

    try {
      batteryOptimizationIgnored = await FlutterForegroundTask
          .isIgnoringBatteryOptimizations
          .timeout(_optionalStartupTimeout);
    } catch (_) {
      batteryOptimizationIgnored = false;
    }

    final micStatus =
        await _optionalStartupValue(Permission.microphone.status) ??
        PermissionStatus.denied;

    if (Platform.isAndroid) {
      try {
        await _optionalStartupValue(DeviceInfoPlugin().androidInfo);
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

  Future<T> _requiredStartupStep<T>(Future<T> future, String stepName) async {
    try {
      return await future.timeout(_requiredStartupTimeout);
    } on TimeoutException {
      throw IdentityStartupException(
        '$stepName timed out after ${_requiredStartupTimeout.inSeconds}s. '
        'Check Firebase setup, phone internet, and Google Play services.',
      );
    } catch (error) {
      throw IdentityStartupException('$stepName failed: $error');
    }
  }

  Future<T> _optionalStartupStep<T>(
    Future<T> future, {
    required T fallback,
  }) async {
    try {
      return await future.timeout(_optionalStartupTimeout);
    } catch (_) {
      return fallback;
    }
  }

  Future<T?> _optionalStartupValue<T>(Future<T> future) async {
    try {
      return await future.timeout(_optionalStartupTimeout);
    } catch (_) {
      return null;
    }
  }
}

class IdentityStartupException implements Exception {
  const IdentityStartupException(this.message);

  final String message;

  @override
  String toString() => message;
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
