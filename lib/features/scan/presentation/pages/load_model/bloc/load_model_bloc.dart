import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/scan/domain/services/ai_model_download_service.dart';
import 'package:injectable/injectable.dart';

part 'load_model_event.dart';
part 'load_model_state.dart';
part 'load_model_bloc.freezed.dart';

const String kAiModelDownloadNotificationId = 'ai_model_download';

@LazySingleton()
class LoadModelBloc extends Bloc<LoadModelEvent, LoadModelState> {
  LoadModelBloc(
    this._downloadService,
    this._notificationBloc,
  ) : super(const LoadModelState()) {
    on<LoadModelInitialized>(_onLoadModelInitialized);
    on<LoadModelDownloadInitiated>(
      _onLoadModelDownloadInitiated,
      transformer: restartable(),
    );
    on<LoadModelServiceStateChanged>(_onServiceStateChanged);
    on<LoadModelDownloadCancelled>(_onLoadModelDownloadCancelled);

    _serviceSubscription = _downloadService.stateStream.listen((serviceState) {
      add(LoadModelServiceStateChanged(serviceState: serviceState));
    });

    _syncFromService();
  }

  final AiModelDownloadService _downloadService;
  final NotificationBloc _notificationBloc;
  StreamSubscription<AiModelDownloadState>? _serviceSubscription;

  void _syncFromService() {
    final serviceState = _downloadService.state;
    if (serviceState.status == AiModelDownloadStatus.downloading) {
      add(LoadModelServiceStateChanged(serviceState: serviceState));
    }
  }

  Future<void> _onLoadModelInitialized(
    LoadModelInitialized event,
    Emitter<LoadModelState> emit,
  ) async {
    final serviceState = _downloadService.state;
    if (serviceState.status == AiModelDownloadStatus.downloading) {
      emit(state.copyWith(
        status: LoadModelStatus.loading,
        downloadProgress: serviceState.progress,
        isBackgroundDownload: true,
      ));
      return;
    }

    if (state.status == LoadModelStatus.loading && state.isBackgroundDownload) {
      return;
    }

    if (serviceState.status == AiModelDownloadStatus.cancelled) {
      _addCancelledNotification();
      _downloadService.resetState();
    }

    if (serviceState.status == AiModelDownloadStatus.completed) {
      emit(state.copyWith(
        status: LoadModelStatus.modelLoaded,
        isBackgroundDownload: false,
      ));
      return;
    }

    bool isModelLoaded = false;
    try {
      isModelLoaded = await _downloadService.checkModelExists();
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

  Future<void> _onLoadModelDownloadInitiated(
    LoadModelDownloadInitiated event,
    Emitter<LoadModelState> emit,
  ) async {
    if (_downloadService.state.status == AiModelDownloadStatus.downloading) {
      emit(state.copyWith(
        status: LoadModelStatus.loading,
        isBackgroundDownload: true,
        downloadProgress: _downloadService.state.progress,
      ));
      return;
    }

    emit(state.copyWith(
      status: LoadModelStatus.loading,
      isBackgroundDownload: true,
      downloadProgress: 0.0,
    ));

    _notificationBloc.add(NotificationAdded(
      notification: Notification(
        id: kAiModelDownloadNotificationId,
        text: 'Downloading AI Model',
        description: 'Starting download...',
        type: NotificationType.progress,
        progress: 0.0,
        time: DateTime.now(),
        read: false,
      ),
    ));

    _downloadService.startDownload();
  }

  void _onServiceStateChanged(
    LoadModelServiceStateChanged event,
    Emitter<LoadModelState> emit,
  ) {
    final serviceState = event.serviceState;

    switch (serviceState.status) {
      case AiModelDownloadStatus.idle:
      case AiModelDownloadStatus.checking:
        break;

      case AiModelDownloadStatus.downloading:
        emit(state.copyWith(
          status: LoadModelStatus.loading,
          downloadProgress: serviceState.progress,
          isBackgroundDownload: true,
        ));
        _notificationBloc.add(NotificationProgressUpdated(
          id: kAiModelDownloadNotificationId,
          progress: serviceState.progress,
        ));
        break;

      case AiModelDownloadStatus.completed:
        emit(state.copyWith(
          status: LoadModelStatus.modelLoaded,
          downloadProgress: 100.0,
          isBackgroundDownload: false,
        ));
        _notificationBloc.add(NotificationTypeUpdated(
          id: kAiModelDownloadNotificationId,
          type: NotificationType.success,
          text: 'AI Model Ready',
          description: 'The AI model has been downloaded successfully.',
        ));
        break;

      case AiModelDownloadStatus.error:
        emit(state.copyWith(
          status: LoadModelStatus.error,
          errorMessage: serviceState.errorMessage ?? 'Download failed',
          isBackgroundDownload: false,
        ));
        _notificationBloc.add(NotificationTypeUpdated(
          id: kAiModelDownloadNotificationId,
          type: NotificationType.error,
          text: 'AI Model Download Failed',
          description:
              serviceState.errorMessage ?? 'An error occurred during download.',
        ));
        break;

      case AiModelDownloadStatus.cancelled:
        emit(state.copyWith(
          status: LoadModelStatus.modelAbsent,
          isBackgroundDownload: false,
        ));
        _addCancelledNotification();
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
    ));
    _addCancelledNotification();
  }

  @override
  Future<void> close() {
    _serviceSubscription?.cancel();
    return super.close();
  }
}
