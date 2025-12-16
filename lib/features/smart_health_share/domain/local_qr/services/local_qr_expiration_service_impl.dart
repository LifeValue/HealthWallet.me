import 'dart:async';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/local_qr_expiration_service.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: LocalQRExpirationService)
class LocalQRExpirationServiceImpl implements LocalQRExpirationService {
  Timer? _expirationTimer;
  StreamController<int>? _timerController;
  bool _screenshotPreventionEnabled = false;

  @override
  Stream<int> startExpirationTimer({
    required int expirationMinutes,
    required Function() onExpired,
  }) {
    // Cancel any existing timer
    cancelTimer();

    final totalSeconds = expirationMinutes * 60;
    _timerController = StreamController<int>.broadcast();

    int remainingSeconds = totalSeconds;

    // Emit initial value
    _timerController!.add(remainingSeconds);

    _expirationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        remainingSeconds--;

        if (remainingSeconds <= 0) {
          timer.cancel();
          _timerController!.add(0);
          _timerController!.close();
          _timerController = null;
          onExpired();
        } else {
          _timerController!.add(remainingSeconds);
        }
      },
    );

    return _timerController!.stream;
  }

  @override
  Stream<int> startExpirationTimerForReceived({
    required DateTime expiresAt,
    required Function() onExpired,
  }) {
    // Cancel any existing timer
    cancelTimer();

    final now = DateTime.now();
    final durationUntilExpiry = expiresAt.difference(now);

    if (durationUntilExpiry.isNegative) {
      // Already expired
      onExpired();
      return Stream.value(0);
    }

    final totalSeconds = durationUntilExpiry.inSeconds;
    _timerController = StreamController<int>.broadcast();

    int remainingSeconds = totalSeconds;

    // Emit initial value
    _timerController!.add(remainingSeconds);

    _expirationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        remainingSeconds--;

        if (remainingSeconds <= 0) {
          timer.cancel();
          _timerController!.add(0);
          _timerController!.close();
          _timerController = null;
          onExpired();
        } else {
          _timerController!.add(remainingSeconds);
        }
      },
    );

    return _timerController!.stream;
  }

  @override
  void cancelTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = null;
    _timerController?.close();
    _timerController = null;
  }

  @override
  bool isScreenshotPreventionEnabled() {
    return _screenshotPreventionEnabled;
  }

  @override
  void enableScreenshotPrevention() {
    _screenshotPreventionEnabled = true;
    // Note: Actual screenshot prevention needs to be implemented at the UI level
    // using Flutter's WidgetsBindingObserver or platform-specific solutions
  }

  @override
  void disableScreenshotPrevention() {
    _screenshotPreventionEnabled = false;
  }
}

