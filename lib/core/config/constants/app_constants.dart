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
      'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';
  static const String modelId =
      'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';

  static const int modelKvCacheSize = 4096;
  static const int defaultMaxTokens = 4096;
  static const int maxAllowedTokens = 4096;
}
