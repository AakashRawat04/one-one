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
import '../../nudges/data/android_voice_nudge_bridge.dart';
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
  bool _disposed = false;

  ValueListenable<IdentitySession?> get sessionListenable => _sessionNotifier;
  IdentitySession? get currentSession {
    if (_disposed) return _cachedSession;
    return _sessionNotifier.value;
  }

  static Future<void>? _googleSignInInitialization;

  Future<IdentitySession> ensureIdentity() async {
    final firebaseUser = await _requiredStartupStep(
      _requireGoogleUser(),
      'Google authentication',
    );
    final now = _nowSeconds();

    // None of these four reads depend on each other, so kick them all off
    // together instead of awaiting one at a time — Dart futures start
    // running the moment they're created, so assigning them to locals
    // before awaiting runs them concurrently and can roughly halve (or
    // better) the time this step takes on a typical connection.
    final localDeviceFuture = _requiredStartupStep(
      _deviceIdentityStore.getOrCreate(),
      'local device identity setup',
    );
    final appVersionFuture = _optionalStartupStep(
      _readAppVersion(),
      fallback: 'unknown',
    );
    final permissionsFuture = _readPermissionDiagnostics();
    final fcmTokenFuture = Platform.isAndroid
        ? _optionalStartupValue(AndroidVoiceNudgeBridge().getFcmToken())
        : Future<String?>.value(null);

    final localDevice = await localDeviceFuture;
    final appVersion = await appVersionFuture;
    final permissions = await permissionsFuture;
    final fcmToken = await fcmTokenFuture;
    debugPrint(
      '[OneOneFCM][DART-03] Identity startup registrationAvailable='
      '${fcmToken != null}',
    );

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
        fcmToken: fcmToken,
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
        fcmToken: fcmToken,
        now: now,
      ),
    );

    if (syncedSession != null) {
      debugPrint(
        '[OneOneFCM][DART-05] Device registration synchronized to Firebase',
      );
      return syncedSession;
    }

    debugPrint(
      '[OneOneFCM][DART-W1] Initial device sync did not complete; retry queued',
    );

    unawaited(
      _syncRemoteIdentityState(
        userId: firebaseUser.uid,
        localDevice: localDevice,
        appVersion: appVersion,
        permissions: permissions,
        fcmToken: fcmToken,
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
          result = await _auth.signInWithCredential(credential);
        } else {
          rethrow;
        }
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

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } finally {
      await _auth.signOut();
      _clearSession();
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('No Google account is signed in.');
    }

    final credential = await _googleCredential();
    await user.reauthenticateWithCredential(credential);

    await _database.ref().update({
      'users/${user.uid}': null,
      'userDevices/${user.uid}': null,
      'userSettings/${user.uid}': null,
    });
    await user.delete();
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {
      await GoogleSignIn.instance.signOut();
    }
    _clearSession();
  }

  void dispose() {
    _disposed = true;
    _cachedSession = null;
    // Do not call _sessionNotifier.dispose() here — this repository is
    // referenced by screens that may outlive the StartupGateScreen that owns
    // it (e.g. SettingsScreen opened via push uses the same listenable).
    // The notifier will be garbage-collected when the app is torn down.
    _sessionNotifier.value = null;
  }

  bool get isDisposed => _disposed;

  Future<User> _requireGoogleUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null &&
        !currentUser.isAnonymous &&
        currentUser.providerData.any(
          (provider) => provider.providerId == 'google.com',
        )) {
      return currentUser;
    }
    throw StateError('Google sign-in is required before setup.');
  }

  Future<AuthCredential> _googleCredential() async {
    _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
    await _googleSignInInitialization;
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not return an ID token.');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  void _clearSession() {
    _cachedSession = null;
    if (!_disposed) _sessionNotifier.value = null;
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
    required String? fcmToken,
    required int now,
  }) async {
    final ref = _database.ref('userDevices/$userId/${localDevice.deviceId}');
    final snapshot = await ref.get();
    int createdAt = now;
    String? resolvedFcmToken = fcmToken;

    if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
      final data = snapshot.value! as Map<Object?, Object?>;
      createdAt = _readInt(data['createdAt'], fallback: now);
      resolvedFcmToken ??= data['fcmToken']?.toString();
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
      fcmToken: resolvedFcmToken,
    );

    await ref.set(device.toJson());
    debugPrint(
      '[OneOneFCM][DART-04] userDevices record written '
      'userSuffix=${_diagnosticSuffix(userId)} '
      'deviceSuffix=${_diagnosticSuffix(localDevice.deviceId)} '
      'registrationAvailable=${resolvedFcmToken != null} '
      'registrationSource=${fcmToken != null ? 'current' : 'existing_or_missing'}',
    );
    return device;
  }

  Future<IdentitySession?> _syncRemoteIdentityState({
    required String userId,
    required LocalDeviceIdentity localDevice,
    required String appVersion,
    required _PermissionDiagnostics permissions,
    required String? fcmToken,
    required int now,
  }) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null || firebaseUser.uid != userId) return null;

      // The profile, settings, and device records live at independent RTDB
      // paths and don't read each other's results, so fetch/write them
      // concurrently rather than as three sequential round trips.
      final userFuture = _upsertUserProfile(firebaseUser, now);
      final settingsFuture = _ensureUserSettings(userId, now);
      final deviceFuture = _upsertUserDevice(
        userId: userId,
        localDevice: localDevice,
        appVersion: appVersion,
        permissions: permissions,
        fcmToken: fcmToken,
        now: now,
      );

      final user = await userFuture;
      final settings = await settingsFuture;
      final device = await deviceFuture;

      final session = IdentitySession(
        user: user,
        device: device,
        settings: settings,
      );
      _publishSession(session);
      return session;
    } catch (error) {
      debugPrint(
        '[OneOneFCM][DART-E4] Firebase device sync failed '
        '${error.runtimeType}: $error',
      );
      // Keep startup responsive even if the database sync is slow or fails.
      return null;
    }
  }

  Future<String> _readAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Future<_PermissionDiagnostics> _readPermissionDiagnostics() async {
    // These are independent plugin channel calls — fire them together
    // instead of one after another to avoid stacking up their latency.
    final notificationPermissionFuture = _optionalStartupValue(
      FlutterForegroundTask.checkNotificationPermission(),
    );
    final batteryOptimizationFuture = _optionalStartupValue(
      FlutterForegroundTask.isIgnoringBatteryOptimizations,
    );
    final micStatusFuture = _optionalStartupValue(Permission.microphone.status);
    // Device metadata is not stored in the Phase 3 ERD. This call is kept
    // as a plugin smoke path for later diagnostics.
    final androidInfoFuture = Platform.isAndroid
        ? _optionalStartupValue(DeviceInfoPlugin().androidInfo)
        : null;

    final notificationPermission = await notificationPermissionFuture;
    final batteryOptimizationIgnored = await batteryOptimizationFuture ?? false;
    final micStatus = await micStatusFuture ?? PermissionStatus.denied;
    if (androidInfoFuture != null) await androidInfoFuture;

    return _PermissionDiagnostics(
      micPermissionGranted: micStatus.isGranted,
      notificationPermissionGranted:
          notificationPermission == NotificationPermission.granted,
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
    if (!_disposed) {
      _sessionNotifier.value = session;
    }
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

String _diagnosticSuffix(String value) =>
    value.length <= 6 ? value : value.substring(value.length - 6);
