import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the real service: cancelDownload returns only when the test
/// lets the transfers end, then reports each variant as cancelled.
class _FakeDownloadService extends Fake implements AiModelDownloadService {
  final controller = StreamController<AiModelDownloadState>.broadcast();
  final downloading = <AiModelVariant>{};
  final onDisk = <AiModelVariant>{};
  var transfersEnded = Completer<void>();
  var cancelCalls = 0;

  @override
  Stream<AiModelDownloadState> get stateStream => controller.stream;

  @override
  bool get isAnyDownloading => false;

  @override
  Future<void> cancelDownload() async {
    cancelCalls++;
    await transfersEnded.future;
    for (final variant in downloading) {
      controller.add(
        AiModelDownloadState(
          status: AiModelDownloadStatus.cancelled,
          variant: variant,
        ),
      );
    }
    downloading.clear();
  }

  @override
  Future<bool> checkModelExistsForVariant(AiModelVariant variant) async =>
      onDisk.contains(variant);
}

class _FakeNotificationBloc extends Fake implements NotificationBloc {
  final events = <NotificationEvent>[];

  @override
  void add(NotificationEvent event) => events.add(event);
}

class _FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {}

String _notificationId(AiModelVariant variant) =>
    '${kAiModelDownloadNotificationId}_${variant.name}';

void main() {
  const variants = [AiModelVariant.qwen, AiModelVariant.qwen35x2b];

  late _FakeDownloadService service;
  late _FakeNotificationBloc notifications;
  late LoadModelBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = _FakeDownloadService();
    notifications = _FakeNotificationBloc();
    bloc = LoadModelBloc(
      service,
      notifications,
      _FakeDeviceCapabilityService(),
      await SharedPreferences.getInstance(),
      AppStringsProvider.forLocale(const Locale('en')),
    );

    for (final variant in variants) {
      service.downloading.add(variant);
      bloc.add(
        LoadModelServiceStateChanged(
          serviceState: AiModelDownloadState(
            status: AiModelDownloadStatus.downloading,
            progress: 40,
            variant: variant,
          ),
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.isAnyDownloading, isTrue);
    notifications.events.clear();
  });

  tearDown(() async {
    await bloc.close();
    await service.controller.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'cancel removes the notification of every downloading model and shows '
    'them as not downloaded',
    () async {
      bloc.add(const LoadModelDownloadCancelled());
      await settle();
      // Nothing changes until the transfers have ended.
      expect(notifications.events, isEmpty);
      expect(bloc.state.isAnyDownloading, isTrue);

      service.transfersEnded.complete();
      await settle();
      await settle();

      final removed = notifications.events
          .whereType<NotificationRemovedById>()
          .map((e) => e.id)
          .toSet();
      expect(removed, variants.map(_notificationId).toSet());
      expect(
        notifications.events.whereType<NotificationTypeUpdated>(),
        isEmpty,
      );
      expect(bloc.state.isAnyDownloading, isFalse);
      expect(bloc.state.variantProgress, isEmpty);
      expect(bloc.state.isBackgroundDownload, isFalse);
      expect(bloc.state.status, LoadModelStatus.modelAbsent);
      for (final variant in variants) {
        expect(bloc.state.isVariantDownloaded(variant), isFalse);
      }
    },
  );

  test('a second cancel while the first is stopping is dropped', () async {
    bloc
      ..add(const LoadModelDownloadCancelled())
      ..add(const LoadModelDownloadCancelled());
    await settle();
    service.transfersEnded.complete();
    await settle();
    await settle();

    expect(service.cancelCalls, 1);
  });

  test('a cancel after the first one has finished runs again', () async {
    service.transfersEnded.complete();
    bloc.add(const LoadModelDownloadCancelled());
    await settle();
    await settle();
    bloc.add(const LoadModelDownloadCancelled());
    await settle();
    await settle();

    expect(service.cancelCalls, 2);
  });

  test(
    'a model that finished downloading just before the cancel shows as '
    'downloaded',
    () async {
      service
        ..onDisk.add(AiModelVariant.qwen)
        ..transfersEnded.complete();
      bloc.add(const LoadModelDownloadCancelled());
      await settle();
      await settle();

      expect(bloc.state.isVariantDownloaded(AiModelVariant.qwen), isTrue);
      expect(bloc.state.isVariantDownloaded(AiModelVariant.qwen35x2b), isFalse);
    },
  );
}
