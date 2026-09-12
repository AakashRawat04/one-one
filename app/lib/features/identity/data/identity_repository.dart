import 'package:one_one_app/one_one.dart';

class IdentityRepository {
  IdentityRepository({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    DeviceIdentityStore? deviceIdentityStore,
    ProfilePhotoStorage? profilePhotoStorage,
    ApiClient? apiClient,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? AppDatabase.instance(),
       _deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore(),
       _profilePhotoStorage = profilePhotoStorage ?? ProfilePhotoStorage(),
       _apiClient = apiClient ?? ApiClient();

  static const Duration _requiredStartupTimeout = Duration(seconds: 3);
  static const Duration _optionalStartupTimeout = Duration(seconds: 4);

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final DeviceIdentityStore _deviceIdentityStore;
  final ProfilePhotoStorage _profilePhotoStorage;
  final ApiClient _apiClient;
  IdentitySession? _cachedSession;
  Future<void>? _identityRefresh;
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
    final cachedSession = _cachedSession;

    if (cachedSession?.userId == firebaseUser.uid) {
      _scheduleIdentityRefresh(
        userId: firebaseUser.uid,
        localDevice: LocalDeviceIdentity(
          installId: cachedSession!.device.installId,
          deviceId: cachedSession.device.deviceId,
        ),
        now: now,
      );
      return cachedSession;
    }

    final localDevice = await _requiredStartupStep(
      _deviceIdentityStore.getOrCreate(),
      'local device identity setup',
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
        avatarAsset: _cachedSession?.user.avatarAsset,
      ),
      device: UserDeviceRecord(
        deviceId: localDevice.deviceId,
        platform: Platform.isAndroid ? 'android' : Platform.operatingSystem,
        appVersion: 'unknown',
        installId: localDevice.installId,
        micPermissionGranted: false,
        notificationPermissionGranted: false,
        batteryOptimizationIgnored: false,
        deviceState: 'active',
        createdAt: now,
        updatedAt: now,
        lastSeenAt: now,
        fcmToken: null,
      ),
      settings: UserSettingsRecord.defaults(now),
    );

    _publishSession(localSession);
    _scheduleIdentityRefresh(
      userId: firebaseUser.uid,
      localDevice: localDevice,
      now: now,
    );

    return localSession;
  }

  void _scheduleIdentityRefresh({
    required String userId,
    required LocalDeviceIdentity localDevice,
    required int now,
  }) {
    if (_identityRefresh != null) return;
    _identityRefresh = _refreshIdentity(
      userId: userId,
      localDevice: localDevice,
      now: now,
    ).whenComplete(() => _identityRefresh = null);
    unawaited(_identityRefresh);
  }

  Future<void> _refreshIdentity({
    required String userId,
    required LocalDeviceIdentity localDevice,
    required int now,
  }) async {
    final stopwatch = Stopwatch()..start();
    final appVersionFuture = _optionalStartupStep(
      _readAppVersion(),
      fallback: 'unknown',
    );
    final permissionsFuture = _readPermissionDiagnostics();
    final fcmTokenFuture = Platform.isAndroid
        ? _optionalStartupValue(AndroidVoiceNudgeBridge().getFcmToken())
        : Future<String?>.value(null);

    final appVersion = await appVersionFuture;
    final permissions = await permissionsFuture;
    final fcmToken = await fcmTokenFuture;
    logStartupMilestone('identity diagnostics ready', stopwatch);
    debugPrint(
      '[OneOneFCM][DART-03] Identity registration available='
      '${fcmToken != null}',
    );

    final syncedSession = await _syncRemoteIdentityState(
      userId: userId,
      localDevice: localDevice,
      appVersion: appVersion,
      permissions: permissions,
      fcmToken: fcmToken,
      now: now,
    );
    logStartupMilestone('remote identity sync finished', stopwatch);
    debugPrint(
      syncedSession == null
          ? '[OneOneFCM][DART-W1] Background identity sync deferred'
          : '[OneOneFCM][DART-05] Device registration synchronized to Firebase',
    );
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
      unawaited(AnalyticsService.logProfileUpdated(field: 'display_name'));
      return updatedSession;
    }

    return ensureIdentity();
  }

  Future<bool> hasCompletedSetup() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot resolve setup before sign-in.');
    }

    // Fast path: SharedPreferences is available locally on-device and was
    // written by markSetupComplete() when the user finished onboarding.
    // This avoids a blocking RTDB network round-trip on every cold launch.
    try {
      final prefs = await SharedPreferences.getInstance();
      final localFlag = prefs.getBool(_setupCompleteKey(user.uid));
      if (localFlag == true) return true;
    } catch (_) {
      // SharedPreferences read failed — fall through to RTDB.
    }

    final snapshot = await _requiredStartupStep(
      _database.ref('users/${user.uid}').get(),
      'profile lookup',
    );
    if (!snapshot.exists || snapshot.value is! Map<Object?, Object?>) {
      return false;
    }

    final data = snapshot.value! as Map<Object?, Object?>;
    final profile = AppUserProfile.fromJson(user.uid, data);
    if (profile.setupCompleted) {
      // Backfill the local cache so the next launch is instant.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_setupCompleteKey(user.uid), true);
      } catch (_) {}
      return true;
    }

    // Existing accounts predate the explicit flag. Completed onboarding
    // always produced both a chosen name and profile photo.
    final completedLegacySetup = hasCompletedProfileSetup(
      profile,
      isLegacyProfile: !data.containsKey('setupCompleted'),
    );
    if (completedLegacySetup) {
      await markSetupComplete(logAnalytics: false);
    }
    return completedLegacySetup;
  }

  static String _setupCompleteKey(String userId) =>
      'one_one_setup_complete_$userId';

  Future<void> markSetupComplete({bool logAnalytics = true}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot complete setup before sign-in.');
    }

    final now = _nowSeconds();
    // Write to both RTDB and SharedPreferences so the next cold launch
    // skips the RTDB round-trip via the fast path in hasCompletedSetup().
    await _database.ref('users/${user.uid}').update({
      'setupCompleted': true,
      'updatedAt': now,
      'lastSeenAt': now,
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupCompleteKey(user.uid), true);
    } catch (_) {
      // SharedPreferences write is a best-effort cache; RTDB is authoritative.
    }

    final session = _cachedSession;
    if (session != null) {
      _publishSession(
        IdentitySession(
          user: session.user.copyWith(
            setupCompleted: true,
            updatedAt: now,
            lastSeenAt: now,
          ),
          device: session.device,
          settings: session.settings,
        ),
      );
    }
    if (logAnalytics) {
      unawaited(AnalyticsService.logSetupCompleted());
    }
  }

  Future<IdentitySession> updateSettings({
    String? accentColorKey,
    HapticsIntensity? hapticsIntensity,
    String? audioOutputPreference,
    String? preferredLocale,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update settings before sign-in.');
    }

    final now = _nowSeconds();
    final current =
        _cachedSession?.settings ?? UserSettingsRecord.defaults(now);
    final cleanAccentKey = accentColorKey == null
        ? current.accentColorKey
        : (accentOptions.any((option) => option.key == accentColorKey)
              ? accentColorKey
              : 'coral');
    final cleanAudioOutput = audioOutputPreference == null
        ? null
        : (audioOutputPreference == 'earpiece' ? 'earpiece' : 'speaker');
    final settings = current.copyWith(
      accentColorKey: cleanAccentKey,
      hapticsIntensity: hapticsIntensity,
      audioOutputPreference: cleanAudioOutput,
      preferredLocale: preferredLocale,
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
      unawaited(AnalyticsService.logProfileUpdated(field: 'settings'));
      return updatedSession;
    }

    return ensureIdentity();
  }

  /// Persists the resolved Play/account market onto the user profile.
  /// Does not overwrite an existing market (travel must not swap the product).
  Future<void> persistMarketIfAbsent(String isoCode) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final clean = isoCode.trim().toUpperCase();
    if (clean.isEmpty || clean == Market.unknown.isoCode) return;

    final existing = _cachedSession?.user.market?.trim();
    if (existing != null && existing.isNotEmpty) return;

    final now = _nowSeconds();
    await _database.ref('users/${user.uid}').update({
      'market': clean,
      'updatedAt': now,
      'lastSeenAt': now,
    });
    final session = _cachedSession;
    if (session != null) {
      _publishSession(
        IdentitySession(
          user: session.user.copyWith(
            market: clean,
            updatedAt: now,
            lastSeenAt: now,
          ),
          device: session.device,
          settings: session.settings,
        ),
      );
    }
  }

  Future<IdentitySession> updateProfilePhoto(Uint8List imageBytes) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update profile photo before sign-in.');
    }

    unawaited(
      CrashlyticsService.log(
        'identity_update_profile_photo_start uid=${user.uid}',
      ),
    );
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
      'avatarAsset': null,
      'updatedAt': now,
      'lastSeenAt': now,
    });
    unawaited(
      CrashlyticsService.log(
        'identity_update_profile_photo_rtdb_ok photoUrl=$photoUrl',
      ),
    );

    final session = _cachedSession;
    if (session != null) {
      final updatedSession = IdentitySession(
        user: session.user.copyWith(
          profilePhotoUrl: photoUrl,
          clearProfilePhotoBase64: true,
          clearAvatarAsset: true,
          updatedAt: now,
          lastSeenAt: now,
        ),
        device: session.device,
        settings: session.settings,
      );
      await _evictProfilePhoto(previousPhotoUrl);
      await _evictProfilePhoto(uploadedPhotoUrl);
      _publishSession(updatedSession);
      unawaited(
        CrashlyticsService.log(
          'identity_update_profile_photo_session_published '
          'avatarAsset=${updatedSession.user.avatarAsset} '
          'photoUrl=${updatedSession.user.profilePhotoUrl}',
        ),
      );
      unawaited(AnalyticsService.logProfileUpdated(field: 'profile_photo'));
      return updatedSession;
    }

    return ensureIdentity();
  }

  Future<IdentitySession> updatePresetAvatar(String assetPath) async {
    if (!AvatarAssets.isPresetAvatarPath(assetPath)) {
      throw ArgumentError.value(assetPath, 'assetPath', 'Unsupported avatar.');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Cannot update profile photo before sign-in.');
    }
    unawaited(
      CrashlyticsService.log(
        'identity_update_preset_avatar_start uid=${user.uid} '
        'assetPath=$assetPath',
      ),
    );
    final now = _nowSeconds();
    await _database.ref('users/${user.uid}').update({
      'avatarAsset': assetPath,
      'profilePhotoUrl': null,
      'profilePhotoBase64': null,
      'updatedAt': now,
      'lastSeenAt': now,
    });
    unawaited(
      CrashlyticsService.log(
        'identity_update_preset_avatar_rtdb_ok assetPath=$assetPath',
      ),
    );
    final session = _cachedSession;
    if (session == null) return ensureIdentity();
    final updatedSession = IdentitySession(
      user: session.user.copyWith(
        avatarAsset: assetPath,
        clearProfilePhotoUrl: true,
        clearProfilePhotoBase64: true,
        updatedAt: now,
        lastSeenAt: now,
      ),
      device: session.device,
      settings: session.settings,
    );
    _publishSession(updatedSession);
    unawaited(
      CrashlyticsService.log(
        'identity_update_preset_avatar_session_published '
        'avatarAsset=${updatedSession.user.avatarAsset}',
      ),
    );
    unawaited(AnalyticsService.logProfileUpdated(field: 'preset_avatar'));
    return updatedSession;
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
    final isNewUser = result.additionalUserInfo?.isNewUser == true;
    unawaited(
      isNewUser
          ? AnalyticsService.logSignUp(method: 'google')
          : AnalyticsService.logLogin(method: 'google'),
    );
    unawaited(CrashlyticsService.log('google_sign_in_success'));
    return user;
  }

  Future<void> signOut() async {
    // Drop this phone from the outgoing account before clearing auth so
    // friends stop targeting a device that is about to sign into someone else.
    await _unregisterCurrentDeviceBestEffort();
    try {
      await GoogleSignIn.instance.signOut();
    } finally {
      await _auth.signOut();
      _clearSession();
      unawaited(AppTelemetry.clearUser());
      unawaited(AnalyticsService.logLogout());
      unawaited(CrashlyticsService.log('user_signed_out'));
    }
  }

  Future<void> _unregisterCurrentDeviceBestEffort() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final deviceId =
          _cachedSession?.device.deviceId ??
          (await _deviceIdentityStore.getOrCreate()).deviceId;
      await _database.ref('userDevices/${user.uid}/$deviceId').remove();
      debugPrint(
        '[OneOneFCM][DART-05] userDevices cleared on sign-out '
        'userSuffix=${_diagnosticSuffix(user.uid)} '
        'deviceSuffix=${_diagnosticSuffix(deviceId)}',
      );
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'device_unregister_on_sign_out_failed',
          feature: 'identity',
        ),
      );
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('No Google account is signed in.');
    }

    final credential = await _googleCredential();
    await user.reauthenticateWithCredential(credential);

    // Purge every per-group row (membership, presence, usage, unread piles,
    // sessions) via the backend — client security rules forbid deleting
    // groupMembers/userGroups directly. Without this, deleted users linger as
    // ghost members in groups they belonged to.
    try {
      await _apiClient.deleteJson('/v1/account');
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'account_purge_backend_failed',
          feature: 'account',
        ),
      );
      // Fall through: still remove the local records and auth user so the
      // deletion isn't blocked by a transient backend failure.
    }

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
    unawaited(AppTelemetry.clearUser());
    unawaited(AnalyticsService.logAccountDeleted());
    unawaited(CrashlyticsService.log('user_account_deleted'));
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
    await ref.update(profile.toJson());
    return profile;
  }

  Future<UserSettingsRecord> _ensureUserSettings(String userId, int now) async {
    final ref = _database.ref('userSettings/$userId');
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
      final settings = UserSettingsRecord.fromJson(
        snapshot.value! as Map<Object?, Object?>,
      );
      final localLocale = LocaleController.languageCode;
      if ((settings.preferredLocale == null ||
              settings.preferredLocale!.trim().isEmpty) &&
          localLocale.isNotEmpty) {
        final merged = settings.copyWith(preferredLocale: localLocale);
        await ref.update({'preferredLocale': localLocale, 'updatedAt': now});
        return merged;
      }
      return settings;
    }

    final settings = UserSettingsRecord.defaults(
      now,
    ).copyWith(preferredLocale: LocaleController.languageCode);
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
      unawaited(
        MarketController.syncWithAccount(
          backendMarketIso: user.market,
          persistIfAbsent: persistMarketIfAbsent,
        ),
      );
      unawaited(LocaleController.syncWithAccount(settings.preferredLocale));
      return session;
    } catch (error, stack) {
      debugPrint(
        '[OneOneFCM][DART-E4] Firebase device sync failed '
        '${error.runtimeType}: $error',
      );
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'identity_device_sync_failed',
        ),
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

    final notificationPermission = await notificationPermissionFuture;
    final batteryOptimizationIgnored = await batteryOptimizationFuture ?? false;
    final micStatus = await micStatusFuture ?? PermissionStatus.denied;

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
    unawaited(
      AndroidVoiceNudgeBridge.setHapticsIntensity(
        session.settings.hapticsIntensity,
      ),
    );
    unawaited(
      AppTelemetry.identifyUser(
        userId: session.userId,
        appVersion: session.device.appVersion,
        deviceId: session.device.deviceId,
        environment: kReleaseMode ? 'release' : 'debug',
      ),
    );
    LogManager.setIdentity(userId: session.userId);
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
    } on TimeoutException catch (error, stack) {
      final wrapped = IdentityStartupException(
        '$stepName timed out after ${_requiredStartupTimeout.inSeconds}s. '
        'Check Firebase setup, phone internet, and Google Play services.',
      );
      unawaited(
        CrashlyticsService.recordError(
          wrapped,
          stack,
          reason: 'identity_startup_timeout:$stepName',
          information: [error],
        ),
      );
      throw wrapped;
    } catch (error, stack) {
      final wrapped = IdentityStartupException('$stepName failed: $error');
      unawaited(
        CrashlyticsService.recordError(
          wrapped,
          stack,
          reason: 'identity_startup_failed:$stepName',
        ),
      );
      throw wrapped;
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
