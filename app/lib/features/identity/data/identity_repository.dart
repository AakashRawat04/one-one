import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/accent_theme.dart';
import '../../../core/firebase/app_database.dart';
import '../../../core/storage/profile_photo_storage.dart';
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
    ProfilePhotoStorage? profilePhotoStorage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? AppDatabase.instance(),
       _deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore(),
       _profilePhotoStorage = profilePhotoStorage ?? ProfilePhotoStorage();

  static const Duration _requiredStartupTimeout = Duration(seconds: 20);
  static const Duration _optionalStartupTimeout = Duration(seconds: 4);

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final DeviceIdentityStore _deviceIdentityStore;
  final ProfilePhotoStorage _profilePhotoStorage;
  IdentitySession? _cachedSession;
  final ValueNotifier<IdentitySession?> _sessionNotifier = ValueNotifier(null);

  ValueListenable<IdentitySession?> get sessionListenable => _sessionNotifier;
  IdentitySession? get currentSession => _sessionNotifier.value;

  static Future<void>? _googleSignInInitialization;

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

    final localSession = IdentitySession(
      user: AppUserProfile(
        userId: firebaseUser.uid,
        displayName: _defaultDisplayName(firebaseUser),
        authProvider: _authProviderFor(firebaseUser),
        accountState: 'active',
        createdAt: now,
        updatedAt: now,
        lastSeenAt: now,
        profilePhotoUrl: _cachedSession?.user.profilePhotoUrl,
        profilePhotoBase64: _cachedSession?.user.profilePhotoBase64,
      ),
      device: UserDeviceRecord(
        deviceId: localDevice.deviceId,
        platform: Platform.isAndroid ? 'android' : Platform.operatingSystem,
        appVersion: appVersion,
        installId: localDevice.installId,
        micPermissionGranted: permissions.micPermissionGranted,
        notificationPermissionGranted:
            permissions.notificationPermissionGranted,
        batteryOptimizationIgnored: permissions.batteryOptimizationIgnored,
        deviceState: 'active',
        createdAt: now,
        updatedAt: now,
        lastSeenAt: now,
      ),
      settings: UserSettingsRecord.defaults(now),
    );

    _publishSession(localSession);
    final syncedSession = await _optionalStartupValue(
      _syncRemoteIdentityState(
        userId: firebaseUser.uid,
        localDevice: localDevice,
        appVersion: appVersion,
        permissions: permissions,
        now: now,
      ),
    );

    if (syncedSession != null) {
      return syncedSession;
    }

    unawaited(
      _syncRemoteIdentityState(
        userId: firebaseUser.uid,
        localDevice: localDevice,
        appVersion: appVersion,
        permissions: permissions,
        now: now,
      ),
    );

    return localSession;
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

    final session = _cachedSession;
    if (session != null) {
      final updatedSession = IdentitySession(
        user: session.user.copyWith(
          displayName: cleanName,
          updatedAt: now,
          lastSeenAt: now,
        ),
        device: session.device,
        settings: session.settings,
      );
      _publishSession(updatedSession);
      return updatedSession;
    }

    return ensureIdentity();
  }

  Future<IdentitySession> updateSettings({
    required String accentColorKey,
    required bool hapticsEnabled,
    required String audioOutputPreference,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update settings before sign-in.');
    }

    final cleanAccentKey =
        accentOptions.any((option) => option.key == accentColorKey)
        ? accentColorKey
        : 'coral';
    final cleanAudioPreference = audioOutputPreference == 'earpiece'
        ? 'earpiece'
        : 'speaker';
    final now = _nowSeconds();
    final settings =
        (_cachedSession?.settings ?? UserSettingsRecord.defaults(now)).copyWith(
          accentColorKey: cleanAccentKey,
          hapticsEnabled: hapticsEnabled,
          audioOutputPreference: cleanAudioPreference,
          updatedAt: now,
        );

    await _database.ref('userSettings/${user.uid}').update(settings.toJson());

    final session = _cachedSession;
    if (session != null) {
      final updatedSession = IdentitySession(
        user: session.user,
        device: session.device,
        settings: settings,
      );
      _publishSession(updatedSession);
      return updatedSession;
    }

    return ensureIdentity();
  }

  Future<IdentitySession> updateProfilePhoto(Uint8List imageBytes) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update profile photo before sign-in.');
    }

    final previousPhotoUrl = _cachedSession?.user.profilePhotoUrl;
    final uploadedPhotoUrl = await _profilePhotoStorage.uploadProfilePhoto(
      userId: user.uid,
      imageBytes: imageBytes,
    );
    final now = _nowSeconds();
    final photoUrl = _withCacheVersion(uploadedPhotoUrl, now);
    await _database.ref('users/${user.uid}').update({
      'profilePhotoUrl': photoUrl,
      'profilePhotoBase64': null,
      'updatedAt': now,
      'lastSeenAt': now,
    });

    final session = _cachedSession;
    if (session != null) {
      final updatedSession = IdentitySession(
        user: session.user.copyWith(
          profilePhotoUrl: photoUrl,
          clearProfilePhotoBase64: true,
          updatedAt: now,
          lastSeenAt: now,
        ),
        device: session.device,
        settings: session.settings,
      );
      await _evictProfilePhoto(previousPhotoUrl);
      await _evictProfilePhoto(uploadedPhotoUrl);
      _publishSession(updatedSession);
      return updatedSession;
    }

    return ensureIdentity();
  }

  Future<User> signInWithGoogle() async {
    _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
    await _googleSignInInitialization;

    final googleAccount = await GoogleSignIn.instance.authenticate();
    final idToken = googleAccount.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not return an ID token.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final currentUser = _auth.currentUser;
    UserCredential result;
    if (currentUser?.isAnonymous == true) {
      try {
        result = await currentUser!.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'credential-already-in-use' ||
            error.code == 'account-exists-with-different-credential') {
          throw StateError(
            'That Google account is already connected to another One One account.',
          );
        }
        rethrow;
      }
    } else {
      result = await _auth.signInWithCredential(credential);
    }

    final user = result.user;
    if (user == null) {
      throw StateError('Firebase Google sign-in returned no user.');
    }
    if (_cachedSession?.userId != user.uid) {
      _cachedSession = null;
      _sessionNotifier.value = null;
    }
    return user;
  }

  void dispose() => _sessionNotifier.dispose();

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

  Future<AppUserProfile> _upsertUserProfile(User firebaseUser, int now) async {
    final userId = firebaseUser.uid;
    final ref = _database.ref('users/$userId');
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
      final existing = AppUserProfile.fromJson(
        userId,
        snapshot.value! as Map<Object?, Object?>,
      );
      final authProvider = _authProviderFor(firebaseUser);
      final updated = existing.copyWith(
        authProvider: authProvider,
        updatedAt: now,
        lastSeenAt: now,
      );
      await ref.update({
        'authProvider': authProvider,
        'updatedAt': now,
        'lastSeenAt': now,
      });
      return updated;
    }

    final profile = AppUserProfile(
      userId: userId,
      displayName: _defaultDisplayName(firebaseUser),
      authProvider: _authProviderFor(firebaseUser),
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

  Future<IdentitySession?> _syncRemoteIdentityState({
    required String userId,
    required LocalDeviceIdentity localDevice,
    required String appVersion,
    required _PermissionDiagnostics permissions,
    required int now,
  }) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null || firebaseUser.uid != userId) return null;
      final user = await _upsertUserProfile(firebaseUser, now);
      final settings = await _ensureUserSettings(userId, now);
      final device = await _upsertUserDevice(
        userId: userId,
        localDevice: localDevice,
        appVersion: appVersion,
        permissions: permissions,
        now: now,
      );

      final session = IdentitySession(
        user: user,
        device: device,
        settings: settings,
      );
      _publishSession(session);
      return session;
    } catch (_) {
      // Keep startup responsive even if the database sync is slow or fails.
      return null;
    }
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

  String _defaultDisplayName(User user) {
    final providerName = user.displayName?.trim();
    if (providerName != null && providerName.isNotEmpty) return providerName;
    final userId = user.uid;
    final suffix = userId.length >= 4 ? userId.substring(0, 4) : userId;
    return 'Friend $suffix';
  }

  String _authProviderFor(User user) {
    if (user.isAnonymous) return 'anonymous';
    if (user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    )) {
      return 'google';
    }
    return user.providerData.firstOrNull?.providerId ?? 'firebase';
  }

  void _publishSession(IdentitySession session) {
    _cachedSession = session;
    _sessionNotifier.value = session;
  }

  Future<void> _evictProfilePhoto(String? url) async {
    final cleanUrl = url?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) return;
    try {
      await CachedNetworkImage.evictFromCache(cleanUrl);
    } catch (_) {
      // Cache eviction is best effort; the versioned cache key still forces a refresh.
    }
  }

  String _withCacheVersion(String url, int version) {
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'one_one_v': '$version'},
        )
        .toString();
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
