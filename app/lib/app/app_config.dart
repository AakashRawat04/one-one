class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'ONE_ONE_API_BASE_URL',
    defaultValue: 'https://one-one-xw00.onrender.com',
  );

  static const String firebaseDatabaseUrl = String.fromEnvironment(
    'ONE_ONE_FIREBASE_DATABASE_URL',
    defaultValue:
        'https://oneone-3adb5-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const String cloudinaryCloudName = String.fromEnvironment(
    'ONE_ONE_CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dfmdfwxlu',
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'ONE_ONE_CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'one-one',
  );

  static const String cloudinaryProfileFolder = 'one_one/profile_photos';

  // RevenueCat public SDK keys are supplied per build/environment. They are
  // intentionally not stored in source control and are not secret server API
  // keys. Pass them with --dart-define for Android and iOS builds.
  static const String revenueCatAndroidApiKey = String.fromEnvironment(
    'ONE_ONE_REVENUECAT_ANDROID_API_KEY',
  );

  static const String revenueCatAppleApiKey = String.fromEnvironment(
    'ONE_ONE_REVENUECAT_APPLE_API_KEY',
  );
}
