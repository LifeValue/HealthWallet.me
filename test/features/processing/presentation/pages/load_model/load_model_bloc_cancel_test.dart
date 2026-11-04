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
  bool isVariantDownloading(AiModelVariant variant) =>
      downloading.contains(variant);

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

  final cancelledOne = <AiModelVariant>[];

  @override
  Future<void> cancelDownloadForVariant(AiModelVariant variant) async {
    cancelledOne.add(variant);
    await transfersEnded.future;
    downloading.remove(variant);
    controller.add(
      AiModelDownloadState(
        status: AiModelDownloadStatus.cancelled,
        variant: variant,
      ),
    );
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

  void serviceReports(
    AiModelDownloadStatus status,
    AiModelVariant variant, {
    bool isMmprojDownload = false,
  }) => bloc.add(
    LoadModelServiceStateChanged(
      serviceState: AiModelDownloadState(
        status: status,
        progress: 40,
        variant: variant,
        isMmprojDownload: isMmprojDownload,
      ),
    ),
  );

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

  test(
    'cancelling another model keeps the selected downloaded model ready',
    () async {
      // qwen finishes and becomes the selected model; qwen35x2b keeps going.
      service.downloading.remove(AiModelVariant.qwen);
      service.onDisk.add(AiModelVariant.qwen);
      serviceReports(AiModelDownloadStatus.completed, AiModelVariant.qwen);
      await settle();
      expect(bloc.state.selectedVariant, AiModelVariant.qwen);

      service.transfersEnded.complete();
      bloc.add(const LoadModelDownloadCancelled());
      await settle();
      await settle();

      expect(bloc.state.status, LoadModelStatus.modelLoaded);
      expect(bloc.state.isVariantDownloaded(AiModelVariant.qwen), isTrue);
      expect(bloc.state.isAnyDownloading, isFalse);
    },
  );

  test('a variant downloading only its vision file stays listed', () async {
    const vision = AiModelVariant.qwen7b;
    serviceReports(
      AiModelDownloadStatus.downloading,
      vision,
      isMmprojDownload: true,
    );
    await settle();

    service.transfersEnded.complete();
    bloc.add(const LoadModelDownloadCancelled());
    await settle();
    await settle();

    expect(bloc.state.isVariantDownloading(vision), isTrue);
    expect(bloc.state.variantProgressOf(vision), 40);
    for (final variant in variants) {
      expect(bloc.state.isVariantDownloading(variant), isFalse);
      expect(bloc.state.variantProgressOf(variant), isNull);
    }
    expect(bloc.state.status, LoadModelStatus.loading);
    expect(bloc.state.isBackgroundDownload, isTrue);
  });

  test('a download started while the cancel runs stays listed', () async {
    const later = AiModelVariant.qwen7b;
    bloc.add(const LoadModelDownloadCancelled());
    await settle();
    serviceReports(AiModelDownloadStatus.downloading, later);
    await settle();

    service.transfersEnded.complete();
    await settle();
    await settle();

    expect(bloc.state.isVariantDownloading(later), isTrue);
    expect(
      notifications.events.whereType<NotificationRemovedById>().map(
        (e) => e.id,
      ),
      isNot(contains(_notificationId(later))),
    );
    expect(bloc.state.status, LoadModelStatus.loading);
  });

  group('cancelling one model', () {
    const one = AiModelVariant.qwen;
    const other = AiModelVariant.qwen35x2b;

    test(
      'stops only that download and removes only its notification',
      () async {
        service.transfersEnded.complete();
        bloc.add(const LoadModelDownloadCancelled(variant: one));
        await settle();
        await settle();

        expect(service.cancelledOne, [one]);
        expect(service.cancelCalls, 0, reason: 'the other keeps downloading');
        expect(
          notifications.events
              .whereType<NotificationRemovedById>()
              .map(
                (e) => e.id,
              )
              .toSet(),
          {_notificationId(one)},
        );
        expect(bloc.state.isVariantDownloading(one), isFalse);
        expect(bloc.state.variantProgressOf(one), isNull);
        expect(bloc.state.isVariantDownloading(other), isTrue);
        expect(bloc.state.variantProgressOf(other), 40);
        expect(bloc.state.status, LoadModelStatus.loading);
      },
    );

    test('the last one cancelled leaves no model downloading', () async {
      service.transfersEnded.complete();
      bloc.add(const LoadModelDownloadCancelled(variant: one));
      await settle();
      await settle();
      bloc.add(const LoadModelDownloadCancelled(variant: other));
      await settle();
      await settle();

      expect(service.cancelledOne, [one, other]);
      expect(bloc.state.isAnyDownloading, isFalse);
      expect(bloc.state.status, LoadModelStatus.modelAbsent);
    });

    test('a model that is not downloading is left alone', () async {
      const idle = AiModelVariant.qwen7b;
      service.transfersEnded.complete();
      bloc.add(const LoadModelDownloadCancelled(variant: idle));
      await settle();
      await settle();

      expect(service.cancelledOne, isEmpty);
      expect(service.cancelCalls, 0);
      expect(notifications.events, isEmpty);
      expect(bloc.state.isVariantDownloading(one), isTrue);
    });

    test('a model whose download finished first keeps its file', () async {
      service
        ..onDisk.add(one)
        ..transfersEnded.complete();
      bloc.add(const LoadModelDownloadCancelled(variant: one));
      await settle();
      await settle();

      expect(bloc.state.isVariantDownloaded(one), isTrue);
    });
  });
}
