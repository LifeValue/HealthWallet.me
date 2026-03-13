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
      'https://huggingface.co/SandLogicTechnologies/MedGemma-4B-IT-GGUF/resolve/main/medgemma-4b-it_Q4_K_M.gguf';
  static const String modelId = 'medgemma-4b-it_Q4_K_M.gguf';

  static const String mmprojUrl =
      'https://huggingface.co/SandLogicTechnologies/MedGemma-4B-IT-GGUF/resolve/main/mmproj-medgemma-4b-it-F16.gguf';
  static const String mmprojId = 'mmproj-medgemma-4b-it-F16.gguf';

  static const int modelContextSize = 4096;
  static const int defaultMaxTokens = 4096;
  static const int maxAllowedTokens = 4096;
  static const int visionMaxTokens = 512;
}
