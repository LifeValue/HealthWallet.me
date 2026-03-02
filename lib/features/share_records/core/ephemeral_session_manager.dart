import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

typedef SessionDestroyedCallback = void Function(String sessionId);

class EphemeralSessionManager with WidgetsBindingObserver {
  EphemeralSessionManager._internal();

  static final EphemeralSessionManager _instance =
      EphemeralSessionManager._internal();

  static EphemeralSessionManager get instance => _instance;

  EphemeralRecordsContainer? _currentSession;

  Timer? _expiryTimer;

  SessionDestroyedCallback? _onSessionDestroyed;

  final _sessionStateController =
      StreamController<EphemeralRecordsContainer?>.broadcast();

  Stream<EphemeralRecordsContainer?> get sessionStateStream =>
      _sessionStateController.stream;

  EphemeralRecordsContainer? get currentSession => _currentSession;

  bool get hasActiveSession =>
      _currentSession != null && !_currentSession!.hasExpired;

  void initialize({SessionDestroyedCallback? onSessionDestroyed}) {
    _onSessionDestroyed = onSessionDestroyed;
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[SESSION:ℹ️] Initialized and observing lifecycle');
  }

  void dispose() {
    destroySession(reason: 'manager_disposed');
    WidgetsBinding.instance.removeObserver(this);
    _sessionStateController.close();
    debugPrint('[SESSION:ℹ️] Disposed');
  }

  void startSession(EphemeralRecordsContainer container) {
    if (_currentSession != null) {
      destroySession(reason: 'new_session_started');
    }

    _currentSession = container;
    _sessionStateController.add(_currentSession);

    _startExpiryTimer(container.viewDuration);

    debugPrint(
      '[SESSION:ℹ️] Started session ${container.sessionId}, '
      'expires in ${container.viewDuration.inSeconds}s',
    );
  }

  void destroySession({String reason = 'explicit'}) {
    if (_currentSession == null) return;

    final sessionId = _currentSession!.sessionId;

    _expiryTimer?.cancel();
    _expiryTimer = null;

    _currentSession = null;
    _sessionStateController.add(null);

    _onSessionDestroyed?.call(sessionId);

    debugPrint(
      '[SESSION:ℹ️] Destroyed session $sessionId, reason: $reason',
    );
  }

  Duration? get timeRemaining => _currentSession?.timeRemaining;

  bool get isExpired => _currentSession?.hasExpired ?? true;

  void extendSession(Duration additionalTime) {
    if (_currentSession == null) return;

    final newDuration = _currentSession!.viewDuration + additionalTime;
    _currentSession = _currentSession!.copyWith(viewDuration: newDuration);
    _sessionStateController.add(_currentSession);

    _expiryTimer?.cancel();
    _startExpiryTimer(_currentSession!.timeRemaining);

    debugPrint(
      '[SESSION:🔍] Extended session by ${additionalTime.inSeconds}s',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[SESSION:🔍] App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (_currentSession != null) {
          destroySession(reason: 'app_lifecycle_$state');
        }
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _startExpiryTimer(Duration duration) {
    _expiryTimer?.cancel();
    _expiryTimer = Timer(duration, () {
      destroySession(reason: 'timer_expired');
    });
  }

  void markExpired() {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(isExpired: true);
    _sessionStateController.add(_currentSession);

    destroySession(reason: 'expired');
  }
}
