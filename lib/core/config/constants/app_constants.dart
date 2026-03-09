class AppConstants {
  static const String appName = 'Boilerplate App';

  static const String baseUrl = 'http://localhost:4200';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  static const connectTimeout = Duration(minutes: 3);
  static const receiveTimeout = Duration(minutes: 3);
  static const sendTimeout = Duration(minutes: 3);

  static const int pageSize = 10;

  static const Duration cacheDuration = Duration(hours: 1);

  static const String modelUrl =
      'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3VL-2B-Instruct-Q4_K_M.gguf';
  static const String modelId = 'Qwen3VL-2B-Instruct-Q4_K_M.gguf';

  static const String mmprojUrl =
      'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-2B-Instruct-F16.gguf';
  static const String mmprojId = 'mmproj-Qwen3VL-2B-Instruct-F16.gguf';

  static const int modelContextSize = 4096;
  static const int defaultMaxTokens = 4096;
  static const int maxAllowedTokens = 4096;
  static const int visionMaxTokens = 512;
}
