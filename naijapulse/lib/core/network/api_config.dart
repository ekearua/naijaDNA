class ApiConfig {
  const ApiConfig._();

  static const String _defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';

  /// Override with:
  /// flutter run --dart-define=API_BASE_URL=https://your-ngrok-url/api/v1
  static const String _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
  static const String _deviceIdFromEnv = String.fromEnvironment(
    'API_DEVICE_ID',
  );

  static String get baseUrl {
    final value = _baseUrlFromEnv.trim();
    if (value.isEmpty) {
      return _defaultBaseUrl;
    }
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  /// Optional stable device identifier for backend vote reconciliation.
  /// Example:
  /// flutter run --dart-define=API_DEVICE_ID=android-emulator-5554
  static String? get deviceId {
    final value = _deviceIdFromEnv.trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }
}
