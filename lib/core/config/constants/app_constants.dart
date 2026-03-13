class AppConstants {
  static const String baseUrl = 'http://localhost:4200';

  static const connectTimeout = Duration(minutes: 3);
  static const receiveTimeout = Duration(minutes: 3);
  static const sendTimeout = Duration(minutes: 3);

  static const int defaultMaxTokens = 4096;
  static const int maxAllowedTokens = 4096;
  static const int visionMaxTokens = 512;
}
