import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
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
    @Default(false) bool isMmprojDownload,
    String? errorMessage,
    AiModelVariant? variant,
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
  final Map<AiModelVariant, StreamSubscription<double>> _variantSubscriptions = {};
  StreamSubscription<double>? _mmprojSubscription;

  AiModelDownloadState _state = const AiModelDownloadState();

  Stream<AiModelDownloadState> get stateStream => _stateController.stream;

  AiModelDownloadState get state => _state;

  bool isVariantDownloading(AiModelVariant variant) =>
      _variantSubscriptions.containsKey(variant);

  bool get isAnyDownloading =>
      _variantSubscriptions.isNotEmpty || _mmprojSubscription != null;

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
    if (isAnyDownloading) {
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
    if (isAnyDownloading) return;

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
      final sub = stream.listen(
        (progress) {
          _updateState(AiModelDownloadState(
            status: AiModelDownloadStatus.downloading,
            progress: progress,
          ));
        },
        onDone: () async {
          await _prefs.remove(_downloadInProgressKey);
          _updateState(_state.copyWith(
            status: AiModelDownloadStatus.completed,
            isModelAvailable: true,
            progress: 100.0,
          ));
        },
        onError: (error) async {
          await _prefs.remove(_downloadInProgressKey);
          _updateState(_state.copyWith(
            status: AiModelDownloadStatus.error,
            errorMessage: 'Download failed: ${error.toString()}',
          ));
        },
        cancelOnError: true,
      );
      _variantSubscriptions[AiModelVariant.qwen] = sub;
    } catch (e) {
      await _prefs.remove(_downloadInProgressKey);
      _updateState(_state.copyWith(
        status: AiModelDownloadStatus.error,
        errorMessage: 'Failed to start download: ${e.toString()}',
      ));
    }
  }

  Future<bool> checkModelExistsForVariant(AiModelVariant variant) async {
    try {
      return await _repository.checkModelExistenceForVariant(variant);
    } catch (e) {
      return false;
    }
  }

  Future<void> startDownloadForVariant(AiModelVariant variant) async {
    if (_variantSubscriptions.containsKey(variant)) return;

    try {
      final exists =
          await _repository.checkModelExistenceForVariant(variant);
      if (exists) {
        _updateState(AiModelDownloadState(
          status: AiModelDownloadStatus.completed,
          isModelAvailable: true,
          progress: 100.0,
          variant: variant,
        ));
        return;
      }
    } catch (e) {}

    await _prefs.setBool(_downloadInProgressKey, true);

    _updateState(AiModelDownloadState(
      status: AiModelDownloadStatus.downloading,
      progress: 0.0,
      variant: variant,
    ));

    try {
      final stream = _repository.downloadModelForVariant(variant);

      _variantSubscriptions[variant] = stream.listen(
        (progress) {
          if (_variantSubscriptions.containsKey(variant)) {
            _updateState(AiModelDownloadState(
              status: AiModelDownloadStatus.downloading,
              progress: progress,
              variant: variant,
            ));
          }
        },
        onDone: () async {
          _variantSubscriptions.remove(variant);
          if (!isAnyDownloading) {
            await _prefs.remove(_downloadInProgressKey);
          }
          _updateState(AiModelDownloadState(
            status: AiModelDownloadStatus.completed,
            isModelAvailable: true,
            progress: 100.0,
            variant: variant,
          ));
        },
        onError: (error) async {
          _variantSubscriptions.remove(variant);
          if (!isAnyDownloading) {
            await _prefs.remove(_downloadInProgressKey);
          }
          _updateState(AiModelDownloadState(
            status: AiModelDownloadStatus.error,
            errorMessage: 'Download failed: ${error.toString()}',
            variant: variant,
          ));
        },
        cancelOnError: true,
      );
    } catch (e) {
      _variantSubscriptions.remove(variant);
      if (!isAnyDownloading) {
        await _prefs.remove(_downloadInProgressKey);
      }
      _updateState(AiModelDownloadState(
        status: AiModelDownloadStatus.error,
        errorMessage: 'Failed to start download: ${e.toString()}',
        variant: variant,
      ));
    }
  }

  Future<void> deleteModelForVariant(AiModelVariant variant) async {
    await _repository.deleteModelForVariant(variant);
  }

  Future<void> cancelDownload() async {
    for (final sub in _variantSubscriptions.values) {
      await sub.cancel();
    }
    _variantSubscriptions.clear();
    await _prefs.remove(_downloadInProgressKey);
    _updateState(_state.copyWith(
      status: AiModelDownloadStatus.cancelled,
      errorMessage: 'Download cancelled',
    ));
  }

  Future<void> cancelDownloadForVariant(AiModelVariant variant) async {
    final sub = _variantSubscriptions.remove(variant);
    await sub?.cancel();
    if (!isAnyDownloading) {
      await _prefs.remove(_downloadInProgressKey);
    }
    _updateState(AiModelDownloadState(
      status: AiModelDownloadStatus.cancelled,
      errorMessage: 'Download cancelled',
      variant: variant,
    ));
  }

  Future<bool> checkMmprojExistsForVariant(AiModelVariant variant) async {
    try {
      return await _repository.checkMmprojExistenceForVariant(variant);
    } catch (e) {
      return false;
    }
  }

  Future<void> startMmprojDownloadForVariant(AiModelVariant variant) async {
    if (_mmprojSubscription != null) return;

    try {
      final exists =
          await _repository.checkMmprojExistenceForVariant(variant);
      if (exists) {
        _updateState(AiModelDownloadState(
          status: AiModelDownloadStatus.completed,
          isMmprojDownload: true,
          isModelAvailable: true,
          progress: 100.0,
          variant: variant,
        ));
        return;
      }
    } catch (e) {}

    _updateState(AiModelDownloadState(
      status: AiModelDownloadStatus.downloading,
      isMmprojDownload: true,
      progress: 0.0,
      variant: variant,
    ));

    try {
      final stream = _repository.downloadMmprojForVariant(variant);

      _mmprojSubscription = stream.listen(
        (progress) {
          if (_mmprojSubscription != null) {
            _updateState(AiModelDownloadState(
              status: AiModelDownloadStatus.downloading,
              isMmprojDownload: true,
              progress: progress,
              variant: variant,
            ));
          }
        },
        onDone: () {
          _mmprojSubscription = null;
          _updateState(AiModelDownloadState(
            status: AiModelDownloadStatus.completed,
            isMmprojDownload: true,
            isModelAvailable: true,
            progress: 100.0,
            variant: variant,
          ));
        },
        onError: (error) {
          _mmprojSubscription = null;
          _updateState(AiModelDownloadState(
            status: AiModelDownloadStatus.error,
            isMmprojDownload: true,
            errorMessage: 'Download failed: ${error.toString()}',
            variant: variant,
          ));
        },
        cancelOnError: true,
      );
    } catch (e) {
      _mmprojSubscription = null;
      _updateState(AiModelDownloadState(
        status: AiModelDownloadStatus.error,
        isMmprojDownload: true,
        errorMessage: 'Failed to start download: ${e.toString()}',
        variant: variant,
      ));
    }
  }

  Future<void> cancelMmprojDownload() async {
    await _mmprojSubscription?.cancel();
    _mmprojSubscription = null;
    _updateState(_state.copyWith(
      status: AiModelDownloadStatus.cancelled,
      isMmprojDownload: true,
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

      if (wasDownloading && isAnyDownloading) {
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
    for (final sub in _variantSubscriptions.values) {
      sub.cancel();
    }
    _mmprojSubscription?.cancel();
    _stateController.close();
  }
}
