class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'ONE_ONE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
