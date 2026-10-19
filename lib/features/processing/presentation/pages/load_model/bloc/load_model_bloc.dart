import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'load_model_event.dart';
part 'load_model_state.dart';
part 'load_model_bloc.freezed.dart';

const String kAiModelDownloadNotificationId = 'ai_model_download';
const String kNoInternetErrorKey = 'no_internet';

@LazySingleton()
class LoadModelBloc extends Bloc<LoadModelEvent, LoadModelState> {
  LoadModelBloc(
    this._downloadService,
    this._notificationBloc,
    this._deviceCapabilityService,
    this._prefs,
  ) : super(const LoadModelState()) {
    on<LoadModelInitialized>(_onLoadModelInitialized);
    on<LoadModelDownloadInitiated>(
      _onLoadModelDownloadInitiated,
      transformer: concurrent(),
    );
    on<LoadModelServiceStateChanged>(_onServiceStateChanged);
    on<LoadModelDownloadCancelled>(_onLoadModelDownloadCancelled);
    on<LoadModelVariantSelected>(_onVariantSelected);
    on<LoadModelDeleteRequested>(_onDeleteRequested);

    _serviceSubscription = _downloadService.stateStream.listen((serviceState) {
      add(LoadModelServiceStateChanged(serviceState: serviceState));
    });

    _syncFromService();
  }

  final AiModelDownloadService _downloadService;
  final NotificationBloc _notificationBloc;
  final DeviceCapabilityService _deviceCapabilityService;
  final SharedPreferences _prefs;
  StreamSubscription<AiModelDownloadState>? _serviceSubscription;

  void _syncFromService() {
    if (_downloadService.isAnyDownloading) {
      final serviceState = _downloadService.state;
      add(LoadModelServiceStateChanged(serviceState: serviceState));
    }
  }

  Future<void> _onLoadModelInitialized(
    LoadModelInitialized event,
    Emitter<LoadModelState> emit,
  ) async {
    final selectedName =
        _prefs.getString(SharedPrefsConstants.aiSelectedModel);
    final selectedVariant = selectedName != null
        ? AiModelConfig.getActive(_prefs).variant
        : null;

    final downloaded = <AiModelVariant, bool>{};
    for (final config in AiModelConfig.availableVariants) {
      downloaded[config.variant] =
          await _downloadService.checkModelExistsForVariant(config.variant);
    }

    final capability = await _deviceCapabilityService.getCapability();

    final autoSelected = selectedVariant ?? _autoSelectSingleModel(downloaded);

    final downloading = <AiModelVariant, bool>{};
    for (final config in AiModelConfig.availableVariants) {
      downloading[config.variant] =
          _downloadService.isVariantDownloading(config.variant);
    }

    emit(state.copyWith(
      selectedVariant: autoSelected,
      downloadedVariants: downloaded,
      deviceCapability: capability,
      downloadingVariants: downloading,
    ));

    if (_downloadService.isAnyDownloading) {
      emit(state.copyWith(
        status: LoadModelStatus.loading,
        isBackgroundDownload: true,
      ));
      return;
    }

    if (state.status == LoadModelStatus.loading && state.isBackgroundDownload) {
      return;
    }

    final serviceState = _downloadService.state;

    if (serviceState.status == AiModelDownloadStatus.cancelled) {
      _addCancelledNotification();
      _downloadService.resetState();
    }

    if (serviceState.status == AiModelDownloadStatus.completed) {
      final activeLoaded = autoSelected != null &&
          (downloaded[autoSelected] ?? false);
      emit(state.copyWith(
        status: activeLoaded
            ? LoadModelStatus.modelLoaded
            : LoadModelStatus.modelAbsent,
        isBackgroundDownload: false,
      ));
      return;
    }

    if (autoSelected == null) {
      emit(state.copyWith(status: LoadModelStatus.modelAbsent));
      return;
    }

    final activeConfig = AiModelConfig.fromVariant(autoSelected);
    if (capability == DeviceAiCapability.unsupported &&
        !activeConfig.skipDeviceCheck) {
      emit(state.copyWith(status: LoadModelStatus.modelAbsent));
      return;
    }

    bool isModelLoaded = false;
    try {
      isModelLoaded = await _downloadService
          .checkModelExistsForVariant(autoSelected);
    } on Exception catch (e) {
      log(e.toString());
      emit(state.copyWith(
        status: LoadModelStatus.error,
        errorMessage: 'An error appeared while checking model existence',
      ));
      return;
    }

    emit(state.copyWith(
      status: isModelLoaded
          ? LoadModelStatus.modelLoaded
          : LoadModelStatus.modelAbsent,
    ));
  }

  AiModelVariant? _autoSelectSingleModel(
    Map<AiModelVariant, bool> downloadedMap,
  ) {
    final downloaded = downloadedMap.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (downloaded.length == 1) {
      _prefs.setString(
          SharedPrefsConstants.aiSelectedModel, downloaded.first.name);
      return downloaded.first;
    }
    return null;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onLoadModelDownloadInitiated(
    LoadModelDownloadInitiated event,
    Emitter<LoadModelState> emit,
  ) async {
    final variant = event.variant ?? state.selectedVariant;
    if (variant == null) return;

    if (_downloadService.isVariantDownloading(variant)) return;

    if (state.status == LoadModelStatus.error) {
      emit(state.copyWith(status: LoadModelStatus.modelAbsent, errorMessage: null));
    }

    if (!await _hasInternetConnection()) {
      emit(state.copyWith(
        status: LoadModelStatus.error,
        errorMessage: kNoInternetErrorKey,
      ));
      return;
    }

    emit(state.copyWith(
      status: LoadModelStatus.loading,
      isBackgroundDownload: true,
      downloadProgress: 0.0,
      downloadingVariant: variant,
      downloadingVariants: {...state.downloadingVariants, variant: true},
      variantProgress: {...state.variantProgress, variant: 0.0},
    ));

    final modelName = AiModelConfig.fromVariant(variant).displayName;

    final notifId = '${kAiModelDownloadNotificationId}_${variant.name}';
    _notificationBloc.add(NotificationAdded(
      notification: Notification(
        id: notifId,
        text: 'Downloading $modelName',
        description: 'Starting download...',
        type: NotificationType.progress,
        progress: 0.0,
        time: DateTime.now(),
        read: false,
      ),
    ));

    _downloadService.startDownloadForVariant(variant);
  }

  void _onServiceStateChanged(
    LoadModelServiceStateChanged event,
    Emitter<LoadModelState> emit,
  ) {
    final serviceState = event.serviceState;
    final variant = serviceState.variant;

    switch (serviceState.status) {
      case AiModelDownloadStatus.idle:
      case AiModelDownloadStatus.checking:
        break;

      case AiModelDownloadStatus.downloading:
        emit(state.copyWith(
          status: LoadModelStatus.loading,
          downloadProgress: serviceState.progress,
          isBackgroundDownload: true,
          downloadingVariant: variant,
          downloadingVariants: variant != null
              ? {...state.downloadingVariants, variant: true}
              : state.downloadingVariants,
          variantProgress: variant != null
              ? {...state.variantProgress, variant: serviceState.progress ?? 0.0}
              : state.variantProgress,
        ));
        if (variant != null) {
          final notifId = '${kAiModelDownloadNotificationId}_${variant.name}';
          _notificationBloc.add(NotificationProgressUpdated(
            id: notifId,
            progress: serviceState.progress,
          ));
        }
        break;

      case AiModelDownloadStatus.completed:
        final updatedDownloaded = variant != null
            ? {...state.downloadedVariants, variant: true}
            : state.downloadedVariants;

        final updatedDownloading = variant != null
            ? {...state.downloadingVariants, variant: false}
            : state.downloadingVariants;

        final updatedProgress = variant != null
            ? (Map<AiModelVariant, double>.from(state.variantProgress)
                ..remove(variant))
            : state.variantProgress;

        final anyStillDownloading = updatedDownloading.entries
            .any((e) => e.value && e.key != variant);

        var effectiveSelected = state.selectedVariant;
        if (effectiveSelected == null) {
          effectiveSelected = _autoSelectSingleModel(updatedDownloaded);
        }

        final selectedIsLoaded = effectiveSelected != null &&
            (updatedDownloaded[effectiveSelected] ?? false);

        final newStatus = anyStillDownloading
            ? LoadModelStatus.loading
            : (selectedIsLoaded
                ? LoadModelStatus.modelLoaded
                : LoadModelStatus.modelAbsent);

        emit(state.copyWith(
          status: newStatus,
          selectedVariant: effectiveSelected,
          downloadProgress: anyStillDownloading ? state.downloadProgress : 100.0,
          isBackgroundDownload: anyStillDownloading,
          downloadedVariants: updatedDownloaded,
          downloadingVariants: updatedDownloading,
          variantProgress: updatedProgress,
        ));
        if (variant != null) {
          final notifId = '${kAiModelDownloadNotificationId}_${variant.name}';
          final modelName = AiModelConfig.fromVariant(variant).displayName;
          _notificationBloc.add(NotificationTypeUpdated(
            id: notifId,
            type: NotificationType.success,
            text: '$modelName Ready',
            description: '$modelName has been downloaded successfully.',
          ));
        }
        break;

      case AiModelDownloadStatus.error:
        final updatedDownloading = variant != null
            ? {...state.downloadingVariants, variant: false}
            : state.downloadingVariants;

        final updatedProgress = variant != null
            ? (Map<AiModelVariant, double>.from(state.variantProgress)
                ..remove(variant))
            : state.variantProgress;

        final anyStillDownloading = updatedDownloading.entries
            .any((e) => e.value && e.key != variant);

        emit(state.copyWith(
          status: anyStillDownloading
              ? LoadModelStatus.loading
              : LoadModelStatus.error,
          errorMessage: serviceState.errorMessage ?? 'Download failed',
          isBackgroundDownload: anyStillDownloading,
          downloadingVariants: updatedDownloading,
          variantProgress: updatedProgress,
        ));
        if (variant != null) {
          final notifId = '${kAiModelDownloadNotificationId}_${variant.name}';
          _notificationBloc.add(NotificationTypeUpdated(
            id: notifId,
            type: NotificationType.error,
            text: 'Download Failed',
            description: 'AI model download failed. Please check your connection and try again.',
          ));
        }
        break;

      case AiModelDownloadStatus.cancelled:
        final updatedDownloading = variant != null
            ? {...state.downloadingVariants, variant: false}
            : state.downloadingVariants;

        final updatedProgress = variant != null
            ? (Map<AiModelVariant, double>.from(state.variantProgress)
                ..remove(variant))
            : state.variantProgress;

        final anyStillDownloading = updatedDownloading.entries
            .any((e) => e.value && e.key != variant);

        emit(state.copyWith(
          status: anyStillDownloading
              ? LoadModelStatus.loading
              : LoadModelStatus.modelAbsent,
          isBackgroundDownload: anyStillDownloading,
          downloadingVariants: updatedDownloading,
          variantProgress: updatedProgress,
        ));
        if (variant != null) {
          final notifId = '${kAiModelDownloadNotificationId}_${variant.name}';
          _notificationBloc.add(NotificationTypeUpdated(
            id: notifId,
            type: NotificationType.error,
            text: 'Download Cancelled',
            description: 'The download was interrupted. Please try again.',
          ));
        }
        break;
    }
  }

  void _addCancelledNotification() {
    _notificationBloc.add(NotificationTypeUpdated(
      id: kAiModelDownloadNotificationId,
      type: NotificationType.error,
      text: 'AI Model Download Cancelled',
      description: 'The download was interrupted. Please try again.',
    ));
  }

  Future<void> _onLoadModelDownloadCancelled(
    LoadModelDownloadCancelled event,
    Emitter<LoadModelState> emit,
  ) async {
    await _downloadService.cancelDownload();
    emit(state.copyWith(
      status: LoadModelStatus.modelAbsent,
      isBackgroundDownload: false,
      downloadProgress: null,
      downloadingVariants: {},
      variantProgress: {},
    ));
    _addCancelledNotification();
  }

  Future<void> _onVariantSelected(
    LoadModelVariantSelected event,
    Emitter<LoadModelState> emit,
  ) async {
    await _prefs.setString(
        SharedPrefsConstants.aiSelectedModel, event.variant.name);
    emit(state.copyWith(selectedVariant: event.variant));
    add(const LoadModelInitialized());
  }

  Future<void> _onDeleteRequested(
    LoadModelDeleteRequested event,
    Emitter<LoadModelState> emit,
  ) async {
    await _downloadService.deleteModelForVariant(event.variant);

    emit(state.copyWith(
      downloadedVariants: {...state.downloadedVariants, event.variant: false},
    ));

    if (state.selectedVariant == event.variant) {
      emit(state.copyWith(status: LoadModelStatus.modelAbsent));
    }
  }

  @override
  Future<void> close() {
    _serviceSubscription?.cancel();
    return super.close();
  }
}
