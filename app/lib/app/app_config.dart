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
}
