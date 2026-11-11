import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/services/device_capability_service.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:health_wallet/features/processing/presentation/pages/load_model/bloc/load_model_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A download service whose files, running downloads and reported state the
/// test sets, and which records what the bloc asks of it.
class _FakeDownloadService extends Fake implements AiModelDownloadService {
  final controller = StreamController<AiModelDownloadState>.broadcast();
  final onDisk = <AiModelVariant>{};
  final downloading = <AiModelVariant>{};
  final started = <AiModelVariant>[];
  final deleted = <AiModelVariant>[];
  final checks = <AiModelVariant, int>{};
  var anyDownloading = false;
  var resetCalls = 0;
  AiModelDownloadState current = const AiModelDownloadState();

  /// Fails the second existence check of this variant: the first one runs in
  /// the scan of every variant, the second is the selected model's check.
  AiModelVariant? failSecondCheckOf;

  @override
  Stream<AiModelDownloadState> get stateStream => controller.stream;

  Future<void> closeStream() => controller.close();

  @override
  AiModelDownloadState get state => current;

  @override
  bool get isAnyDownloading => anyDownloading;

  @override
  bool isVariantDownloading(AiModelVariant variant) =>
      downloading.contains(variant);

  @override
  Future<bool> checkModelExistsForVariant(AiModelVariant variant) async {
    final count = checks[variant] = (checks[variant] ?? 0) + 1;
    if (variant == failSecondCheckOf && count >= 2) {
      throw const FileSystemException('disk unreadable');
    }
    return onDisk.contains(variant);
  }

  @override
  void resetState() => resetCalls++;

  @override
  Future<void> startDownloadForVariant(AiModelVariant variant) async =>
      started.add(variant);

  @override
  Future<void> deleteModelForVariant(AiModelVariant variant) async {
    deleted.add(variant);
    onDisk.remove(variant);
  }
}

class _FakeNotificationBloc extends Fake implements NotificationBloc {
  final events = <NotificationEvent>[];

  @override
  void add(NotificationEvent event) => events.add(event);
}

class _FakeDeviceCapabilityService extends Fake
    implements DeviceCapabilityService {
  DeviceAiCapability capability = DeviceAiCapability.full;
  bool advancedModel = false;

  @override
  Future<DeviceAiCapability> getCapability() async => capability;

  @override
  Future<bool> supportsAdvancedModel() async => advancedModel;
}

final _en = lookupAppLocalizations(const Locale('en'));

String _notificationId(AiModelVariant variant) =>
    '${kAiModelDownloadNotificationId}_${variant.name}';

String _name(AiModelVariant variant) =>
    AiModelConfig.fromVariant(variant).localizedName(_en);

AiModelDownloadState _report(
  AiModelDownloadStatus status, {
  AiModelVariant? variant,
  double progress = 0,
  String? errorMessage,
}) => AiModelDownloadState(
  status: status,
  variant: variant,
  progress: progress,
  errorMessage: errorMessage,
);

/// Whether this machine can resolve the host the bloc probes before a
/// download; the bloc's check reads the network, which a test cannot fake.
Future<bool> _online() async {
  try {
    final result = await InternetAddress.lookup(
      'example.com',
    ).timeout(const Duration(seconds: 5));
    return result.isNotEmpty;
  } on Exception catch (_) {
    // No network on this machine: the bloc takes its no-internet branch.
    return false;
  }
}

void main() {
  late _FakeDownloadService service;
  late _FakeNotificationBloc notifications;
  late _FakeDeviceCapabilityService capability;
  late SharedPreferences prefs;

  // The host running the tests decides the offered variants (desktop has
  // Ultra), so the expected maps are built from the config.
  final scanned = [
    ...AiModelConfig.availableVariants,
    ...AiModelConfig.retiredVariants,
  ].map((c) => c.variant);
  final offered = AiModelConfig.availableVariants.map((c) => c.variant);

  Map<AiModelVariant, bool> downloadedMap(Set<AiModelVariant> onDisk) => {
    for (final v in scanned) v: onDisk.contains(v),
  };
  Map<AiModelVariant, bool> downloadingMap(Set<AiModelVariant> running) => {
    for (final v in offered) v: running.contains(v),
  };

  Future<void> setUpWith([Map<String, Object> saved = const {}]) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
  }

  setUp(() async {
    service = _FakeDownloadService();
    notifications = _FakeNotificationBloc();
    capability = _FakeDeviceCapabilityService();
    await setUpWith();
  });

  tearDown(() => service.closeStream());

  LoadModelBloc build() => LoadModelBloc(
    service,
    notifications,
    capability,
    prefs,
    AppStringsProvider.forLocale(const Locale('en')),
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('initialisation', () {
    blocTest<LoadModelBloc, LoadModelState>(
      'with no model on the device and none chosen, no model is selected',
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      expect: () => [
        LoadModelState(
          deviceCapability: DeviceAiCapability.full,
          downloadedVariants: downloadedMap({}),
          downloadingVariants: downloadingMap({}),
        ),
        LoadModelState(
          status: LoadModelStatus.modelAbsent,
          deviceCapability: DeviceAiCapability.full,
          downloadedVariants: downloadedMap({}),
          downloadingVariants: downloadingMap({}),
        ),
      ],
      verify: (_) {
        expect(prefs.getString(SharedPrefsConstants.aiSelectedModel), isNull);
        expect(service.resetCalls, 0);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'says whether the device has the memory for the Advanced model',
      setUp: () => capability.advancedModel = true,
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) => expect(bloc.state.advancedModelSupported, isTrue),
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'the only model on the device is selected and saved',
      setUp: () => service.onDisk.add(AiModelVariant.qwen35x4b),
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, AiModelVariant.qwen35x4b);
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
        expect(
          bloc.state.downloadedVariants,
          downloadedMap({AiModelVariant.qwen35x4b}),
        );
        expect(
          prefs.getString(SharedPrefsConstants.aiSelectedModel),
          AiModelVariant.qwen35x4b.name,
        );
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a retired model that is the only one on the device is selected',
      setUp: () => service.onDisk.add(AiModelVariant.medGemma),
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, AiModelVariant.medGemma);
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'with two models on the device and none chosen, the user has to pick',
      setUp: () => service.onDisk.addAll({
        AiModelVariant.qwen,
        AiModelVariant.qwen35x4b,
      }),
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, isNull);
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
        expect(prefs.getString(SharedPrefsConstants.aiSelectedModel), isNull);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a chosen model on the device is ready',
      setUp: () async {
        await setUpWith({
          SharedPrefsConstants.aiSelectedModel: AiModelVariant.qwen.name,
        });
        service.onDisk.addAll({AiModelVariant.qwen, AiModelVariant.qwen35x4b});
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, AiModelVariant.qwen);
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a chosen model that is not on the device is absent',
      setUp: () async {
        await setUpWith({
          SharedPrefsConstants.aiSelectedModel: AiModelVariant.qwen35x4b.name,
        });
        service.onDisk.add(AiModelVariant.qwen);
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, AiModelVariant.qwen35x4b);
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'an unsupported device cannot use a model that checks the device',
      setUp: () async {
        await setUpWith({
          SharedPrefsConstants.aiSelectedModel: AiModelVariant.qwen.name,
        });
        service.onDisk.add(AiModelVariant.qwen);
        capability.capability = DeviceAiCapability.unsupported;
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(AiModelConfig.qwen.skipDeviceCheck, isFalse);
        expect(bloc.state.deviceCapability, DeviceAiCapability.unsupported);
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
        // Only the scan of every variant ran, not the selected model's check.
        expect(service.checks[AiModelVariant.qwen], 1);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'an unsupported device still uses a model that skips the device check',
      setUp: () async {
        await setUpWith({
          SharedPrefsConstants.aiSelectedModel: AiModelVariant.qwen35x4b.name,
        });
        service.onDisk.add(AiModelVariant.qwen35x4b);
        capability.capability = DeviceAiCapability.unsupported;
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(AiModelConfig.qwen35x4b.skipDeviceCheck, isTrue);
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a failed check of the chosen model shows an error',
      setUp: () async {
        await setUpWith({
          SharedPrefsConstants.aiSelectedModel: AiModelVariant.qwen.name,
        });
        service
          ..onDisk.add(AiModelVariant.qwen)
          ..failSecondCheckOf = AiModelVariant.qwen;
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.error);
        expect(bloc.state.errorMessage, _en.aiModelCheckFailed);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a download running in the service shows as a background download',
      setUp: () {
        service
          ..anyDownloading = true
          ..downloading.add(AiModelVariant.qwen);
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.loading);
        expect(bloc.state.isBackgroundDownload, isTrue);
        expect(
          bloc.state.downloadingVariants,
          downloadingMap({AiModelVariant.qwen}),
        );
        expect(bloc.state.isAnyDownloading, isTrue);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a background download the bloc still shows stays shown',
      build: build,
      act: (bloc) async {
        bloc.add(
          LoadModelServiceStateChanged(
            serviceState: _report(
              AiModelDownloadStatus.downloading,
              variant: AiModelVariant.qwen,
              progress: 50,
            ),
          ),
        );
        await settle();
        bloc.add(const LoadModelInitialized());
      },
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.loading);
        expect(bloc.state.isBackgroundDownload, isTrue);
        expect(bloc.state.downloadProgress, 50);
        expect(service.resetCalls, 0);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a cancelled service state is reset',
      setUp: () => service.current = _report(AiModelDownloadStatus.cancelled),
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(service.resetCalls, 1);
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'after a completed download the chosen model on disk is ready',
      setUp: () {
        service
          ..current = _report(AiModelDownloadStatus.completed)
          ..onDisk.add(AiModelVariant.qwen);
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
        expect(bloc.state.isBackgroundDownload, isFalse);
        // The completed branch returns before the selected model's check.
        expect(service.checks[AiModelVariant.qwen], 1);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'after a completed download with no model chosen, it is absent',
      setUp: () {
        service
          ..current = _report(AiModelDownloadStatus.completed)
          ..onDisk.addAll({AiModelVariant.qwen, AiModelVariant.qwen35x4b});
      },
      build: build,
      act: (bloc) => bloc.add(const LoadModelInitialized()),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, isNull);
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
      },
    );
  });

  group('a new bloc', () {
    test('picks up a download already running in the service', () async {
      service
        ..anyDownloading = true
        ..current = _report(
          AiModelDownloadStatus.downloading,
          variant: AiModelVariant.qwen35x4b,
          progress: 30,
        );
      final bloc = build();
      addTearDown(bloc.close);
      await settle();

      expect(bloc.state.status, LoadModelStatus.loading);
      expect(bloc.state.downloadProgress, 30);
      expect(bloc.state.downloadingVariant, AiModelVariant.qwen35x4b);
      expect(bloc.state.variantProgressOf(AiModelVariant.qwen35x4b), 30);
      expect(notifications.events, [
        NotificationProgressUpdated(
          id: _notificationId(AiModelVariant.qwen35x4b),
          progress: 30,
        ),
      ]);
    });

    test('follows the states the service reports on its stream', () async {
      final bloc = build();
      addTearDown(bloc.close);

      service.controller.add(
        _report(
          AiModelDownloadStatus.downloading,
          variant: AiModelVariant.qwen,
          progress: 12,
        ),
      );
      await settle();

      expect(bloc.state.variantProgressOf(AiModelVariant.qwen), 12);
      expect(bloc.state.isVariantDownloading(AiModelVariant.qwen), isTrue);
    });

    test('stops listening to the service when closed', () async {
      final bloc = build();
      expect(service.controller.hasListener, isTrue);

      await bloc.close();

      expect(service.controller.hasListener, isFalse);
    });
  });

  group('starting a download', () {
    blocTest<LoadModelBloc, LoadModelState>(
      'does nothing with no variant given and none selected',
      build: build,
      act: (bloc) => bloc.add(const LoadModelDownloadInitiated()),
      expect: () => <LoadModelState>[],
      verify: (_) {
        expect(service.started, isEmpty);
        expect(notifications.events, isEmpty);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'does nothing for a variant already downloading',
      setUp: () => service.downloading.add(AiModelVariant.qwen),
      build: build,
      seed: () => const LoadModelState(status: LoadModelStatus.error),
      act: (bloc) => bloc.add(
        const LoadModelDownloadInitiated(variant: AiModelVariant.qwen),
      ),
      expect: () => <LoadModelState>[],
      verify: (_) {
        expect(service.started, isEmpty);
        expect(notifications.events, isEmpty);
      },
    );

    test(
      'clears an earlier error, then starts the selected model with a '
      'progress notification, or reports no internet',
      () async {
        final online = await _online();
        final bloc = build();
        addTearDown(bloc.close);
        bloc.emit(
          const LoadModelState(
            status: LoadModelStatus.error,
            errorMessage: 'old',
            selectedVariant: AiModelVariant.qwen35x4b,
          ),
        );
        final states = <LoadModelState>[];
        final sub = bloc.stream.listen(states.add);
        addTearDown(sub.cancel);

        bloc.add(const LoadModelDownloadInitiated());
        await bloc.stream
            .firstWhere(
              (s) =>
                  s.status == LoadModelStatus.loading ||
                  s.status == LoadModelStatus.error,
            )
            .timeout(const Duration(seconds: 10));
        await settle();

        expect(states.first.status, LoadModelStatus.modelAbsent);
        expect(states.first.errorMessage, isNull);

        if (!online) {
          expect(bloc.state.status, LoadModelStatus.error);
          expect(bloc.state.errorMessage, kNoInternetErrorKey);
          expect(service.started, isEmpty);
          expect(notifications.events, isEmpty);
          return;
        }

        const variant = AiModelVariant.qwen35x4b;
        expect(bloc.state.status, LoadModelStatus.loading);
        expect(bloc.state.isBackgroundDownload, isTrue);
        expect(bloc.state.downloadProgress, 0);
        expect(bloc.state.downloadingVariant, variant);
        expect(bloc.state.isVariantDownloading(variant), isTrue);
        expect(bloc.state.variantProgressOf(variant), 0);
        expect(service.started, [variant]);

        final added = notifications.events.single as NotificationAdded;
        expect(added.notification.id, _notificationId(variant));
        expect(
          added.notification.text,
          _en.aiModelDownloadingTitle(_name(variant)),
        );
        expect(added.notification.description, _en.aiModelDownloadStarting);
        expect(added.notification.type, NotificationType.progress);
        expect(added.notification.progress, 0);
        expect(added.notification.read, isFalse);
      },
    );
  });

  group('a service report', () {
    LoadModelBloc reportTo(LoadModelBloc bloc, AiModelDownloadState s) =>
        bloc..add(LoadModelServiceStateChanged(serviceState: s));

    for (final status in [
      AiModelDownloadStatus.idle,
      AiModelDownloadStatus.checking,
    ]) {
      blocTest<LoadModelBloc, LoadModelState>(
        '${status.name} changes nothing',
        build: build,
        act: (bloc) =>
            reportTo(bloc, _report(status, variant: AiModelVariant.qwen)),
        expect: () => <LoadModelState>[],
        verify: (_) => expect(notifications.events, isEmpty),
      );
    }

    blocTest<LoadModelBloc, LoadModelState>(
      'of progress updates the variant and its notification',
      build: build,
      act: (bloc) => reportTo(
        bloc,
        _report(
          AiModelDownloadStatus.downloading,
          variant: AiModelVariant.qwen,
          progress: 42,
        ),
      ),
      expect: () => [
        const LoadModelState(
          downloadProgress: 42,
          isBackgroundDownload: true,
          downloadingVariant: AiModelVariant.qwen,
          downloadingVariants: {AiModelVariant.qwen: true},
          variantProgress: {AiModelVariant.qwen: 42},
        ),
      ],
      verify: (_) => expect(notifications.events, [
        NotificationProgressUpdated(
          id: _notificationId(AiModelVariant.qwen),
          progress: 42,
        ),
      ]),
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of progress with no variant updates only the overall progress',
      build: build,
      seed: () => const LoadModelState(status: LoadModelStatus.modelAbsent),
      act: (bloc) => reportTo(
        bloc,
        _report(AiModelDownloadStatus.downloading, progress: 7),
      ),
      expect: () => [
        const LoadModelState(downloadProgress: 7, isBackgroundDownload: true),
      ],
      verify: (_) => expect(notifications.events, isEmpty),
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of completion selects the only model, marks it ready and says so',
      build: build,
      seed: () => const LoadModelState(
        isBackgroundDownload: true,
        downloadingVariants: {AiModelVariant.qwen: true},
        variantProgress: {AiModelVariant.qwen: 90},
      ),
      act: (bloc) => reportTo(
        bloc,
        _report(AiModelDownloadStatus.completed, variant: AiModelVariant.qwen),
      ),
      expect: () => [
        const LoadModelState(
          status: LoadModelStatus.modelLoaded,
          selectedVariant: AiModelVariant.qwen,
          downloadProgress: 100,
          downloadedVariants: {AiModelVariant.qwen: true},
          downloadingVariants: {AiModelVariant.qwen: false},
        ),
      ],
      verify: (_) {
        expect(
          prefs.getString(SharedPrefsConstants.aiSelectedModel),
          AiModelVariant.qwen.name,
        );
        expect(notifications.events, [
          NotificationTypeUpdated(
            id: _notificationId(AiModelVariant.qwen),
            type: NotificationType.success,
            text: _en.aiModelReadyTitle(_name(AiModelVariant.qwen)),
            description: _en.aiModelDownloadedMessage(
              _name(AiModelVariant.qwen),
            ),
          ),
        ]);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of completion keeps loading while another model downloads',
      build: build,
      seed: () => const LoadModelState(
        isBackgroundDownload: true,
        downloadProgress: 33,
        downloadingVariants: {
          AiModelVariant.qwen: true,
          AiModelVariant.qwen35x4b: true,
        },
        variantProgress: {
          AiModelVariant.qwen: 90,
          AiModelVariant.qwen35x4b: 33,
        },
      ),
      act: (bloc) => reportTo(
        bloc,
        _report(AiModelDownloadStatus.completed, variant: AiModelVariant.qwen),
      ),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.loading);
        expect(bloc.state.isBackgroundDownload, isTrue);
        expect(bloc.state.downloadProgress, 33);
        expect(bloc.state.isVariantDownloaded(AiModelVariant.qwen), isTrue);
        expect(bloc.state.variantProgress, {AiModelVariant.qwen35x4b: 33});
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of completion of another model leaves a missing selection absent',
      build: build,
      seed: () => const LoadModelState(
        selectedVariant: AiModelVariant.qwen35x4b,
        downloadingVariants: {AiModelVariant.qwen: true},
      ),
      act: (bloc) => reportTo(
        bloc,
        _report(AiModelDownloadStatus.completed, variant: AiModelVariant.qwen),
      ),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, AiModelVariant.qwen35x4b);
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
        expect(prefs.getString(SharedPrefsConstants.aiSelectedModel), isNull);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of completion with no variant sends no notification',
      build: build,
      seed: () => const LoadModelState(
        selectedVariant: AiModelVariant.qwen,
        downloadedVariants: {AiModelVariant.qwen: true},
      ),
      act: (bloc) => reportTo(bloc, _report(AiModelDownloadStatus.completed)),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
        expect(bloc.state.downloadProgress, 100);
        expect(notifications.events, isEmpty);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of an error shows the service message and an error notification',
      build: build,
      seed: () => const LoadModelState(
        isBackgroundDownload: true,
        downloadingVariants: {AiModelVariant.qwen: true},
        variantProgress: {AiModelVariant.qwen: 10},
      ),
      act: (bloc) => reportTo(
        bloc,
        _report(
          AiModelDownloadStatus.error,
          variant: AiModelVariant.qwen,
          errorMessage: 'disk full',
        ),
      ),
      expect: () => [
        const LoadModelState(
          status: LoadModelStatus.error,
          errorMessage: 'disk full',
          downloadingVariants: {AiModelVariant.qwen: false},
        ),
      ],
      verify: (_) => expect(notifications.events, [
        NotificationTypeUpdated(
          id: _notificationId(AiModelVariant.qwen),
          type: NotificationType.error,
          text: _en.aiModelDownloadFailedTitle,
          description: _en.aiModelDownloadFailedMessage,
        ),
      ]),
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of an error keeps loading while another model downloads',
      build: build,
      seed: () => const LoadModelState(
        isBackgroundDownload: true,
        downloadingVariants: {
          AiModelVariant.qwen: true,
          AiModelVariant.qwen35x4b: true,
        },
      ),
      act: (bloc) => reportTo(
        bloc,
        _report(AiModelDownloadStatus.error, variant: AiModelVariant.qwen),
      ),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.loading);
        expect(bloc.state.isBackgroundDownload, isTrue);
        expect(bloc.state.errorMessage, _en.aiModelDownloadFailed);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of an error with no variant uses the default message and no '
      'notification',
      build: build,
      act: (bloc) => reportTo(bloc, _report(AiModelDownloadStatus.error)),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.error);
        expect(bloc.state.errorMessage, _en.aiModelDownloadFailed);
        expect(notifications.events, isEmpty);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of a cancel keeps a downloaded selection ready',
      build: build,
      seed: () => const LoadModelState(
        selectedVariant: AiModelVariant.qwen,
        downloadedVariants: {AiModelVariant.qwen: true},
        downloadingVariants: {AiModelVariant.qwen35x4b: true},
        variantProgress: {AiModelVariant.qwen35x4b: 5},
        isBackgroundDownload: true,
      ),
      act: (bloc) => reportTo(
        bloc,
        _report(
          AiModelDownloadStatus.cancelled,
          variant: AiModelVariant.qwen35x4b,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
        expect(bloc.state.isBackgroundDownload, isFalse);
        expect(bloc.state.variantProgress, isEmpty);
        expect(notifications.events, [
          NotificationRemovedById(
            id: _notificationId(AiModelVariant.qwen35x4b),
          ),
        ]);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of a cancel keeps loading while another model downloads',
      build: build,
      seed: () => const LoadModelState(
        downloadingVariants: {
          AiModelVariant.qwen: true,
          AiModelVariant.qwen35x4b: true,
        },
      ),
      act: (bloc) => reportTo(
        bloc,
        _report(AiModelDownloadStatus.cancelled, variant: AiModelVariant.qwen),
      ),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.loading);
        expect(bloc.state.isBackgroundDownload, isTrue);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'of a cancel with no variant leaves no selection absent and sends no '
      'notification',
      build: build,
      act: (bloc) => reportTo(bloc, _report(AiModelDownloadStatus.cancelled)),
      verify: (bloc) {
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
        expect(notifications.events, isEmpty);
      },
    );
  });

  group('choosing a model', () {
    blocTest<LoadModelBloc, LoadModelState>(
      'saves it and re-checks the device, so a model on disk is ready',
      setUp: () => service.onDisk.addAll({
        AiModelVariant.qwen,
        AiModelVariant.qwen35x4b,
      }),
      build: build,
      act: (bloc) =>
          bloc.add(const LoadModelVariantSelected(AiModelVariant.qwen35x4b)),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(
          prefs.getString(SharedPrefsConstants.aiSelectedModel),
          AiModelVariant.qwen35x4b.name,
        );
        expect(bloc.state.selectedVariant, AiModelVariant.qwen35x4b);
        expect(bloc.state.status, LoadModelStatus.modelLoaded);
      },
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'a model not on disk is absent',
      build: build,
      act: (bloc) =>
          bloc.add(const LoadModelVariantSelected(AiModelVariant.qwen)),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.selectedVariant, AiModelVariant.qwen);
        expect(bloc.state.status, LoadModelStatus.modelAbsent);
      },
    );
  });

  group('deleting a model', () {
    blocTest<LoadModelBloc, LoadModelState>(
      'the selected one makes the model absent',
      build: build,
      seed: () => const LoadModelState(
        status: LoadModelStatus.modelLoaded,
        selectedVariant: AiModelVariant.qwen,
        downloadedVariants: {
          AiModelVariant.qwen: true,
          AiModelVariant.qwen35x4b: true,
        },
      ),
      act: (bloc) =>
          bloc.add(const LoadModelDeleteRequested(AiModelVariant.qwen)),
      expect: () => [
        const LoadModelState(
          status: LoadModelStatus.modelLoaded,
          selectedVariant: AiModelVariant.qwen,
          downloadedVariants: {
            AiModelVariant.qwen: false,
            AiModelVariant.qwen35x4b: true,
          },
        ),
        const LoadModelState(
          status: LoadModelStatus.modelAbsent,
          selectedVariant: AiModelVariant.qwen,
          downloadedVariants: {
            AiModelVariant.qwen: false,
            AiModelVariant.qwen35x4b: true,
          },
        ),
      ],
      verify: (_) => expect(service.deleted, [AiModelVariant.qwen]),
    );

    blocTest<LoadModelBloc, LoadModelState>(
      'another one keeps the selected model ready',
      build: build,
      seed: () => const LoadModelState(
        status: LoadModelStatus.modelLoaded,
        selectedVariant: AiModelVariant.qwen,
        downloadedVariants: {
          AiModelVariant.qwen: true,
          AiModelVariant.qwen35x4b: true,
        },
      ),
      act: (bloc) =>
          bloc.add(const LoadModelDeleteRequested(AiModelVariant.qwen35x4b)),
      expect: () => [
        const LoadModelState(
          status: LoadModelStatus.modelLoaded,
          selectedVariant: AiModelVariant.qwen,
          downloadedVariants: {
            AiModelVariant.qwen: true,
            AiModelVariant.qwen35x4b: false,
          },
        ),
      ],
      verify: (_) => expect(service.deleted, [AiModelVariant.qwen35x4b]),
    );
  });
}
