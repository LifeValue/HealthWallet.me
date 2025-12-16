/// Service for managing LocalQR Code expiration and auto-deletion
abstract class LocalQRExpirationService {
  /// Start expiration timer for a session
  /// Returns a stream that emits remaining seconds until expiration
  Stream<int> startExpirationTimer({
    required int expirationMinutes,
    required Function() onExpired,
  });

  /// Start expiration timer for received LocalQR resources
  /// Returns a stream that emits remaining seconds until expiration
  Stream<int> startExpirationTimerForReceived({
    required DateTime expiresAt,
    required Function() onExpired,
  });

  /// Cancel the expiration timer
  void cancelTimer();

  /// Check if screenshot/recording prevention is enabled
  bool isScreenshotPreventionEnabled();

  /// Enable screenshot/recording prevention (UI-level enforcement)
  void enableScreenshotPrevention();

  /// Disable screenshot/recording prevention
  void disableScreenshotPrevention();
}

