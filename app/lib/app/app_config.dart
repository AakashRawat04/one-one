class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'ONE_ONE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String firebaseDatabaseUrl = String.fromEnvironment(
    'ONE_ONE_FIREBASE_DATABASE_URL',
    defaultValue:
        'https://oneone-3adb5-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
