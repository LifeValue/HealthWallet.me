class AppConstants {
  static const String appName = 'Boilerplate App';

  // API Endpoints
  static const String baseUrl = 'http://localhost:4200';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Timeouts
  static const connectTimeout = Duration(minutes: 3);
  static const receiveTimeout = Duration(minutes: 3);
  static const sendTimeout = Duration(minutes: 3);

  // Pagination
  static const int pageSize = 10;

  // Cache Duration
  static const Duration cacheDuration = Duration(hours: 1);

  static const String modelUrl =
      'https://huggingface.co/google/gemma-2b-it-tflite/resolve/main/gemma-2b-it-gpu-int4.bin';
  static const String modelId = 'gemma-2b-it-gpu-int4.bin';
}
