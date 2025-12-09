import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/scan/domain/repository/scan_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'ai_model_download_service.freezed.dart';

enum AiModelDownloadStatus {
  idle,
  checking,
  downloading,
  completed,
  error,
  cancelled,
}

@freezed
class AiModelDownloadState with _$AiModelDownloadState {
  const factory AiModelDownloadState({
    @Default(AiModelDownloadStatus.idle) AiModelDownloadStatus status,
    @Default(0.0) double progress,
    @Default(false) bool isModelAvailable,
    String? errorMessage,
  }) = _AiModelDownloadState;
}

@LazySingleton()
class AiModelDownloadService with WidgetsBindingObserver {
  final ScanRepository _repository;
  final SharedPreferences _prefs;

  static const String _downloadInterruptedKey = 'ai_model_download_interrupted';
  static const String _downloadInProgressKey = 'ai_model_download_in_progress';

  AiModelDownloadService(this._repository, this._prefs) {
    WidgetsBinding.instance.addObserver(this);
    _checkForInterruptedDownload();
  }

  final _stateController = StreamController<AiModelDownloadState>.broadcast();

  AiModelDownloadState _state = const AiModelDownloadState();

  StreamSubscription<double>? _downloadSubscription;

  Stream<AiModelDownloadState> get stateStream => _stateController.stream;

  AiModelDownloadState get state => _state;

  void _checkForInterruptedDownload() {
    final wasInterrupted = _prefs.getBool(_downloadInterruptedKey) ?? false;
    if (wasInterrupted) {
      _prefs.remove(_downloadInterruptedKey);
      _prefs.remove(_downloadInProgressKey);
      _updateState(_state.copyWith(
        status: AiModelDownloadStatus.cancelled,
        errorMessage: 'AI Model download was cancelled',
      ));
    }
  }

  Future<bool> checkModelExists() async {
    if (_state.status == AiModelDownloadStatus.downloading) {
      try {
        return await _repository.checkModelExistence();
      } catch (e) {
        return false;
      }
    }

    _updateState(_state.copyWith(status: AiModelDownloadStatus.checking));
    try {
      final exists = await _repository.checkModelExistence();
      _updateState(_state.copyWith(
        status: AiModelDownloadStatus.idle,
        isModelAvailable: exists,
      ));
      return exists;
    } catch (e) {
      _updateState(_state.copyWith(
        status: AiModelDownloadStatus.error,
        errorMessage: 'Failed to check model existence',
      ));
      return false;
    }
  }

  Future<void> startDownload() async {
    if (_state.status == AiModelDownloadStatus.downloading) {
      return;
    }

    await _downloadSubscription?.cancel();
    _downloadSubscription = null;

    try {
      final exists = await _repository.checkModelExistence();
      if (exists) {
        _updateState(_state.copyWith(
          status: AiModelDownloadStatus.completed,
          isModelAvailable: true,
          progress: 100.0,
        ));
        return;
      }
    } catch (e) {}

    await _prefs.setBool(_downloadInProgressKey, true);

    _updateState(_state.copyWith(
      status: AiModelDownloadStatus.downloading,
      progress: 0.0,
      errorMessage: null,
    ));

    try {
      final stream = _repository.downloadModel();

      _downloadSubscription = stream.listen(
        (progress) {
          if (_state.status == AiModelDownloadStatus.downloading) {
            _updateState(_state.copyWith(progress: progress));
          }
        },
        onDone: () async {
          await _prefs.remove(_downloadInProgressKey);
          _downloadSubscription = null;
          _updateState(_state.copyWith(
            status: AiModelDownloadStatus.completed,
            isModelAvailable: true,
            progress: 100.0,
          ));
        },
        onError: (error) async {
          await _prefs.remove(_downloadInProgressKey);
          _downloadSubscription = null;
          _updateState(_state.copyWith(
            status: AiModelDownloadStatus.error,
            errorMessage: 'Download failed: ${error.toString()}',
          ));
        },
        cancelOnError: true,
      );
    } catch (e) {
      await _prefs.remove(_downloadInProgressKey);
      _updateState(_state.copyWith(
        status: AiModelDownloadStatus.error,
        errorMessage: 'Failed to start download: ${e.toString()}',
      ));
    }
  }

  Future<void> cancelDownload() async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    await _prefs.remove(_downloadInProgressKey);
    _updateState(_state.copyWith(
      status: AiModelDownloadStatus.cancelled,
      errorMessage: 'Download cancelled',
    ));
  }

  void resetState() {
    _updateState(const AiModelDownloadState());
  }

  void _updateState(AiModelDownloadState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.detached) {
      final wasDownloading = _prefs.getBool(_downloadInProgressKey) ?? false;

      if (wasDownloading &&
          _state.status == AiModelDownloadStatus.downloading) {
        _prefs.setBool(_downloadInterruptedKey, true);
      }
    }

    if (state == AppLifecycleState.resumed) {
      final wasInterrupted = _prefs.getBool(_downloadInterruptedKey) ?? false;
      if (wasInterrupted) {
        _checkForInterruptedDownload();
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadSubscription?.cancel();
    _stateController.close();
  }
}
