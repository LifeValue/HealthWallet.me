import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
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
abstract class AiModelDownloadState with _$AiModelDownloadState {
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
  final ProcessingRepository _repository;
  final SharedPreferences _prefs;
  final AppStringsProvider _strings;

  static const String _downloadInterruptedKey = 'ai_model_download_interrupted';
  static const String _downloadInProgressKey = 'ai_model_download_in_progress';

  AiModelDownloadService(this._repository, this._prefs, this._strings) {
    WidgetsBinding.instance.addObserver(this);
    _checkForInterruptedDownload();
  }

  final _stateController = StreamController<AiModelDownloadState>.broadcast();
  final Map<AiModelVariant, StreamSubscription<double>> _variantSubscriptions =
      {};
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
      _updateState(
        _state.copyWith(
          status: AiModelDownloadStatus.cancelled,
          errorMessage: _strings.l10n.aiModelDownloadWasCancelled,
        ),
      );
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
      final exists = await _repository.checkModelExistenceForVariant(variant);
      if (exists) {
        _updateState(
          AiModelDownloadState(
            status: AiModelDownloadStatus.completed,
            isModelAvailable: true,
            progress: 100.0,
            variant: variant,
          ),
        );
        return;
      }
    } catch (_) {
      // The existence check failed; fall through and download the model.
    }

    await _prefs.setBool(_downloadInProgressKey, true);

    _updateState(
      AiModelDownloadState(
        status: AiModelDownloadStatus.downloading,
        progress: 0.0,
        variant: variant,
      ),
    );

    try {
      final stream = _repository.downloadModelForVariant(variant);

      _variantSubscriptions[variant] = stream.listen(
        (progress) {
          if (_variantSubscriptions.containsKey(variant)) {
            _updateState(
              AiModelDownloadState(
                status: AiModelDownloadStatus.downloading,
                progress: progress,
                variant: variant,
              ),
            );
          }
        },
        onDone: () async {
          _variantSubscriptions.remove(variant);
          if (!isAnyDownloading) {
            await _prefs.remove(_downloadInProgressKey);
          }
          _updateState(
            AiModelDownloadState(
              status: AiModelDownloadStatus.completed,
              isModelAvailable: true,
              progress: 100.0,
              variant: variant,
            ),
          );
        },
        onError: (error) async {
          debugPrint('AI model download error for ${variant.name}: $error');
          _variantSubscriptions.remove(variant);
          if (!isAnyDownloading) {
            await _prefs.remove(_downloadInProgressKey);
          }
          _updateState(
            AiModelDownloadState(
              status: AiModelDownloadStatus.error,
              errorMessage: _strings.l10n.aiModelDownloadFailedMessage,
              variant: variant,
            ),
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('AI model download start error for ${variant.name}: $e');
      _variantSubscriptions.remove(variant);
      if (!isAnyDownloading) {
        await _prefs.remove(_downloadInProgressKey);
      }
      _updateState(
        AiModelDownloadState(
          status: AiModelDownloadStatus.error,
          errorMessage: _strings.l10n.aiModelDownloadFailedMessage,
          variant: variant,
        ),
      );
    }
  }

  Future<void> deleteModelForVariant(AiModelVariant variant) async {
    await _repository.deleteModelForVariant(variant);
  }

  /// Stops every running model download; the vision (mmproj) download keeps
  /// running. Completes once each transfer has ended and its partial file is
  /// deleted, then reports each variant as cancelled.
  Future<void> cancelDownload() async {
    // The variants stay listed as downloading until their transfers have
    // ended, so a restart can't slip in while they are stopping.
    final variants = _variantSubscriptions.keys.toList();
    await Future.wait(variants.map(_stopVariantDownload));
    for (final variant in variants) {
      _variantSubscriptions.remove(variant);
    }
    if (!isAnyDownloading) {
      await _prefs.remove(_downloadInProgressKey);
    }
    for (final variant in variants) {
      _updateState(_cancelledState(variant));
    }
  }

  Future<void> cancelDownloadForVariant(AiModelVariant variant) async {
    await _stopVariantDownload(variant);
    _variantSubscriptions.remove(variant);
    if (!isAnyDownloading) {
      await _prefs.remove(_downloadInProgressKey);
    }
    _updateState(_cancelledState(variant));
  }

  /// Cancelling the subscription stops the transfer and waits for it to end.
  Future<void> _stopVariantDownload(AiModelVariant variant) async {
    try {
      await _variantSubscriptions[variant]?.cancel();
    } catch (e, s) {
      logger.e('Could not cancel the ${variant.name} model download', e, s);
    }
  }

  AiModelDownloadState _cancelledState(AiModelVariant variant) =>
      AiModelDownloadState(
        status: AiModelDownloadStatus.cancelled,
        errorMessage: _strings.l10n.aiModelDownloadCancelled,
        variant: variant,
      );

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
      final exists = await _repository.checkMmprojExistenceForVariant(variant);
      if (exists) {
        _updateState(
          AiModelDownloadState(
            status: AiModelDownloadStatus.completed,
            isMmprojDownload: true,
            isModelAvailable: true,
            progress: 100.0,
            variant: variant,
          ),
        );
        return;
      }
    } catch (_) {
      // The existence check failed; fall through and download the model.
    }

    _updateState(
      AiModelDownloadState(
        status: AiModelDownloadStatus.downloading,
        isMmprojDownload: true,
        progress: 0.0,
        variant: variant,
      ),
    );

    try {
      final stream = _repository.downloadMmprojForVariant(variant);

      _mmprojSubscription = stream.listen(
        (progress) {
          if (_mmprojSubscription != null) {
            _updateState(
              AiModelDownloadState(
                status: AiModelDownloadStatus.downloading,
                isMmprojDownload: true,
                progress: progress,
                variant: variant,
              ),
            );
          }
        },
        onDone: () {
          _mmprojSubscription = null;
          _updateState(
            AiModelDownloadState(
              status: AiModelDownloadStatus.completed,
              isMmprojDownload: true,
              isModelAvailable: true,
              progress: 100.0,
              variant: variant,
            ),
          );
        },
        onError: (error) {
          debugPrint('AI model component download error: $error');
          _mmprojSubscription = null;
          _updateState(
            AiModelDownloadState(
              status: AiModelDownloadStatus.error,
              isMmprojDownload: true,
              errorMessage: _strings.l10n.aiModelDownloadFailedMessage,
              variant: variant,
            ),
          );
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('AI model component download start error: $e');
      _mmprojSubscription = null;
      _updateState(
        AiModelDownloadState(
          status: AiModelDownloadStatus.error,
          isMmprojDownload: true,
          errorMessage: _strings.l10n.aiModelDownloadFailedMessage,
          variant: variant,
        ),
      );
    }
  }

  Future<void> cancelMmprojDownload() async {
    await _mmprojSubscription?.cancel();
    _mmprojSubscription = null;
    _updateState(
      _state.copyWith(
        status: AiModelDownloadStatus.cancelled,
        isMmprojDownload: true,
        errorMessage: _strings.l10n.aiModelDownloadCancelled,
      ),
    );
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
