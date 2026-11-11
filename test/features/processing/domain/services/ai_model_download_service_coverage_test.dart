import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/log_capture.dart';

const _inProgressKey = 'ai_model_download_in_progress';
const _interruptedKey = 'ai_model_download_interrupted';
const _qwen = AiModelVariant.qwen;
const _gemma = AiModelVariant.medGemma;

/// One download the test drives. Cancelling its subscription runs [onCancel],
/// which waits for [cancelGate] and then throws [cancelError] if set.
class _Download {
  final controller = StreamController<double>();
  var cancels = 0;
  Completer<void>? cancelGate;
  Error? cancelError;

  _Download() {
    controller.onCancel = () async {
      cancels++;
      await cancelGate?.future;
      if (cancelError != null) throw cancelError!;
    };
  }

  Stream<double> get stream => controller.stream;

  /// Not awaited: a stream nobody listened to never delivers its done event.
  void close() => unawaited(controller.close());
}

class _FakeRepository extends Fake implements ProcessingRepository {
  bool modelExists = false;
  Error? existenceError;
  bool mmprojExists = false;
  Error? mmprojExistenceError;
  Error? startError;
  final legacy = _Download();
  final variants = <AiModelVariant, _Download>{};
  final mmprojs = <AiModelVariant, _Download>{};
  final deleted = <AiModelVariant>[];
  var legacyStarts = 0;
  var variantStarts = 0;
  var mmprojStarts = 0;

  _Download variant(AiModelVariant v) => variants.putIfAbsent(v, _Download.new);
  _Download mmproj(AiModelVariant v) => mmprojs.putIfAbsent(v, _Download.new);

  void closeAll() {
    for (final d in [legacy, ...variants.values, ...mmprojs.values]) {
      d.close();
    }
  }

  @override
  Future<bool> checkModelExistence() async {
    if (existenceError != null) throw existenceError!;
    return modelExists;
  }

  @override
  Stream<double> downloadModel() {
    legacyStarts++;
    if (startError != null) throw startError!;
    return legacy.stream;
  }

  @override
  Future<bool> checkModelExistenceForVariant(AiModelVariant variant) async {
    if (existenceError != null) throw existenceError!;
    return modelExists;
  }

  @override
  Stream<double> downloadModelForVariant(AiModelVariant variant) {
    variantStarts++;
    if (startError != null) throw startError!;
    return this.variant(variant).stream;
  }

  @override
  Future<bool> checkMmprojExistenceForVariant(AiModelVariant variant) async {
    if (mmprojExistenceError != null) throw mmprojExistenceError!;
    return mmprojExists;
  }

  @override
  Stream<double> downloadMmprojForVariant(AiModelVariant variant) {
    mmprojStarts++;
    if (startError != null) throw startError!;
    return mmproj(variant).stream;
  }

  @override
  Future<void> deleteModelForVariant(AiModelVariant variant) async =>
      deleted.add(variant);
}

Matcher _state(
  AiModelDownloadStatus status, {
  AiModelVariant? variant,
  double? progress,
  bool? available,
  bool? mmproj,
  Object? error,
}) {
  var m = isA<AiModelDownloadState>().having(
    (s) => s.status,
    'status',
    status,
  );
  if (variant != null) m = m.having((s) => s.variant, 'variant', variant);
  if (progress != null) m = m.having((s) => s.progress, 'progress', progress);
  if (available != null) {
    m = m.having((s) => s.isModelAvailable, 'isModelAvailable', available);
  }
  if (mmproj != null) {
    m = m.having((s) => s.isMmprojDownload, 'isMmprojDownload', mmproj);
  }
  if (error != null) m = m.having((s) => s.errorMessage, 'errorMessage', error);
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
  late _FakeRepository repository;
  late SharedPreferences prefs;
  late List<AiModelDownloadState> states;

  Future<AiModelDownloadService> service({
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    final service = AiModelDownloadService(
      repository,
      prefs,
      AppStringsProvider.forLocale(const Locale('en')),
    );
    addTearDown(service.dispose);
    final sub = service.stateStream.listen(states.add);
    addTearDown(sub.cancel);
    return service;
  }

  setUp(() {
    repository = _FakeRepository();
    // Registered before each test's service, so it runs after the dispose.
    addTearDown(repository.closeAll);
    states = [];
  });

  group('on start', () {
    test('a download the app was closed during is reported as cancelled and '
        'its flags cleared', () async {
      final s = await service(
        prefsValues: {_interruptedKey: true, _inProgressKey: true},
      );

      expect(
        s.state,
        _state(
          AiModelDownloadStatus.cancelled,
          error: 'AI model download was cancelled',
        ),
      );
      expect(prefs.containsKey(_interruptedKey), isFalse);
      expect(prefs.containsKey(_inProgressKey), isFalse);
    });

    test('with no interrupted download it starts idle', () async {
      final s = await service(prefsValues: {_inProgressKey: true});

      expect(s.state, const AiModelDownloadState());
      expect(s.isAnyDownloading, isFalse);
      expect(prefs.getBool(_inProgressKey), isTrue);
    });
  });

  group('checkModelExists', () {
    test('reports checking, then whether the model is there', () async {
      final s = await service();
      repository.modelExists = true;

      expect(await s.checkModelExists(), isTrue);
      await pumpEventQueue();

      expect(states, [
        _state(AiModelDownloadStatus.checking),
        _state(AiModelDownloadStatus.idle, available: true),
      ]);
    });

    test('a missing model is idle and not available', () async {
      final s = await service();

      expect(await s.checkModelExists(), isFalse);
      expect(s.state, _state(AiModelDownloadStatus.idle, available: false));
    });

    test('a failed check is an error and counts as missing', () async {
      final s = await service();
      repository.existenceError = StateError('disk');

      expect(await s.checkModelExists(), isFalse);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.error,
          error: 'Failed to check model existence',
        ),
      );
    });

    test('during a download it answers without touching the download '
        'state', () async {
      final s = await service();
      await s.startDownloadForVariant(_qwen);
      final before = s.state;
      repository.modelExists = true;

      expect(await s.checkModelExists(), isTrue);
      repository.existenceError = StateError('disk');
      expect(await s.checkModelExists(), isFalse);

      expect(s.state, before);
    });
  });

  group('startDownload (default model)', () {
    test('a model already there completes at once without '
        'downloading', () async {
      final s = await service();
      repository.modelExists = true;

      await s.startDownload();

      expect(repository.legacyStarts, 0);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.completed,
          progress: 100.0,
          available: true,
        ),
      );
      expect(prefs.containsKey(_inProgressKey), isFalse);
    });

    test('reports progress and completes, clearing the in-progress '
        'flag', () async {
      final s = await service();

      await s.startDownload();
      expect(prefs.getBool(_inProgressKey), isTrue);
      expect(s.state, _state(AiModelDownloadStatus.downloading, progress: 0));
      expect(s.isVariantDownloading(_qwen), isTrue);

      repository.legacy.controller.add(40);
      await pumpEventQueue();
      expect(s.state, _state(AiModelDownloadStatus.downloading, progress: 40));

      await repository.legacy.controller.close();
      await pumpEventQueue();
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.completed,
          progress: 100.0,
          available: true,
        ),
      );
      expect(prefs.containsKey(_inProgressKey), isFalse);
    });

    test('a failed existence check still downloads', () async {
      final s = await service();
      repository.existenceError = StateError('disk');

      await s.startDownload();

      expect(repository.legacyStarts, 1);
      expect(s.state.status, AiModelDownloadStatus.downloading);
    });

    test('a second start during the download is ignored', () async {
      final s = await service();

      await s.startDownload();
      await s.startDownload();

      expect(repository.legacyStarts, 1);
    });

    test('a failed download is an error and clears the flag', () async {
      final s = await service();

      await s.startDownload();
      repository.legacy.controller.addError(StateError('offline'));
      await pumpEventQueue();

      expect(
        s.state,
        _state(
          AiModelDownloadStatus.error,
          error:
              'AI model download failed. Please check your connection and '
              'try again.',
        ),
      );
      expect(prefs.containsKey(_inProgressKey), isFalse);
    });

    test('a download that cannot start is an error and clears the '
        'flag', () async {
      final s = await service();
      repository.startError = StateError('no network');

      await s.startDownload();

      expect(s.state.status, AiModelDownloadStatus.error);
      expect(s.state.errorMessage, contains('AI model download failed'));
      expect(prefs.containsKey(_inProgressKey), isFalse);
      expect(s.isAnyDownloading, isFalse);
    });

    test(
      'a finished download no longer counts as running',
      skip:
          'BUG: startDownload never removes its subscription from '
          '_variantSubscriptions on done or error, so isAnyDownloading stays '
          'true and later starts are ignored',
      () async {
        final s = await service();

        await s.startDownload();
        await repository.legacy.controller.close();
        await pumpEventQueue();

        expect(s.isAnyDownloading, isFalse);
        expect(s.isVariantDownloading(_qwen), isFalse);
      },
    );
  });

  group('startDownloadForVariant', () {
    test('a model already there completes at once for that variant', () async {
      final s = await service();
      repository.modelExists = true;

      await s.startDownloadForVariant(_gemma);

      expect(repository.variantStarts, 0);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.completed,
          variant: _gemma,
          progress: 100.0,
          available: true,
        ),
      );
    });

    test('reports progress for the variant and completes', () async {
      final s = await service();

      await s.startDownloadForVariant(_gemma);
      expect(prefs.getBool(_inProgressKey), isTrue);
      expect(s.isVariantDownloading(_gemma), isTrue);
      expect(s.isVariantDownloading(_qwen), isFalse);
      expect(s.isAnyDownloading, isTrue);

      repository.variant(_gemma).controller.add(12.5);
      await pumpEventQueue();
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.downloading,
          variant: _gemma,
          progress: 12.5,
        ),
      );

      await repository.variant(_gemma).controller.close();
      await pumpEventQueue();
      expect(
        states.map((e) => e.status),
        [
          AiModelDownloadStatus.downloading,
          AiModelDownloadStatus.downloading,
          AiModelDownloadStatus.completed,
        ],
      );
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.completed,
          variant: _gemma,
          progress: 100.0,
          available: true,
        ),
      );
      expect(s.isAnyDownloading, isFalse);
      expect(prefs.containsKey(_inProgressKey), isFalse);
    });

    test('a failed existence check still downloads', () async {
      final s = await service();
      repository.existenceError = StateError('disk');

      await s.startDownloadForVariant(_gemma);

      expect(repository.variantStarts, 1);
      expect(s.isVariantDownloading(_gemma), isTrue);
    });

    test('a second start of the same variant is ignored', () async {
      final s = await service();

      await s.startDownloadForVariant(_gemma);
      await s.startDownloadForVariant(_gemma);

      expect(repository.variantStarts, 1);
    });

    test('the in-progress flag stays until the last download ends', () async {
      final s = await service();
      await s.startDownloadForVariant(_gemma);
      await s.startDownloadForVariant(_qwen);

      await repository.variant(_gemma).controller.close();
      await pumpEventQueue();
      expect(prefs.getBool(_inProgressKey), isTrue);
      expect(s.isVariantDownloading(_qwen), isTrue);

      repository.variant(_qwen).controller.addError(StateError('offline'));
      await pumpEventQueue();
      expect(prefs.containsKey(_inProgressKey), isFalse);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.error,
          variant: _qwen,
          error:
              'AI model download failed. Please check your connection and '
              'try again.',
        ),
      );
      expect(s.isAnyDownloading, isFalse);
    });

    test('a failure keeps the flag while another download runs', () async {
      final s = await service();
      await s.startDownloadForVariant(_gemma);
      await s.startDownloadForVariant(_qwen);

      repository.variant(_gemma).controller.addError(StateError('offline'));
      await pumpEventQueue();

      expect(prefs.getBool(_inProgressKey), isTrue);
      expect(s.isVariantDownloading(_gemma), isFalse);
      expect(s.isVariantDownloading(_qwen), isTrue);
    });

    test('a download that cannot start is an error for that variant', () async {
      final s = await service();
      repository.startError = StateError('no network');

      await s.startDownloadForVariant(_gemma);

      expect(
        s.state,
        _state(AiModelDownloadStatus.error, variant: _gemma),
      );
      expect(s.state.errorMessage, contains('AI model download failed'));
      expect(s.isVariantDownloading(_gemma), isFalse);
      expect(prefs.containsKey(_inProgressKey), isFalse);
    });
  });

  group('cancelDownload', () {
    test('stops every model download, waits for each, and keeps the vision '
        'one', () async {
      final s = await service();
      await s.startDownloadForVariant(_gemma);
      await s.startDownloadForVariant(_qwen);
      await s.startMmprojDownloadForVariant(_qwen);
      final gate = Completer<void>();
      repository.variant(_gemma).cancelGate = gate;

      var done = false;
      final cancel = s.cancelDownload().then((_) => done = true);
      await pumpEventQueue();
      // Still listed while its transfer is stopping, so a restart is ignored.
      expect(done, isFalse);
      expect(s.isVariantDownloading(_gemma), isTrue);
      await s.startDownloadForVariant(_gemma);
      expect(repository.variantStarts, 2);

      gate.complete();
      await cancel;
      await pumpEventQueue();

      expect(repository.variant(_gemma).cancels, 1);
      expect(repository.variant(_qwen).cancels, 1);
      expect(repository.mmproj(_qwen).cancels, 0);
      expect(s.isVariantDownloading(_gemma), isFalse);
      expect(s.isVariantDownloading(_qwen), isFalse);
      expect(s.isAnyDownloading, isTrue, reason: 'the vision download runs');
      expect(prefs.getBool(_inProgressKey), isTrue);
      expect(
        states.where((e) => e.status == AiModelDownloadStatus.cancelled),
        [
          _state(
            AiModelDownloadStatus.cancelled,
            variant: _gemma,
            error: 'Download cancelled',
          ),
          _state(
            AiModelDownloadStatus.cancelled,
            variant: _qwen,
            error: 'Download cancelled',
          ),
        ],
      );
    });

    test('clears the in-progress flag once nothing downloads', () async {
      final s = await service();
      await s.startDownloadForVariant(_gemma);

      await s.cancelDownload();

      expect(prefs.containsKey(_inProgressKey), isFalse);
      expect(s.isAnyDownloading, isFalse);
    });

    test('a cancel that fails is logged and the variant is still '
        'cancelled', () async {
      final s = await service();
      await s.startDownloadForVariant(_gemma);
      repository.variant(_gemma).cancelError = StateError('stuck');

      await s.cancelDownload();

      expect(logs, loggedWarning('Could not cancel the medGemma model'));
      expect(s.isVariantDownloading(_gemma), isFalse);
      expect(
        s.state,
        _state(AiModelDownloadStatus.cancelled, variant: _gemma),
      );
    });

    test('with nothing running it reports nothing', () async {
      final s = await service();

      await s.cancelDownload();
      await pumpEventQueue();

      expect(states, isEmpty);
      expect(s.state, const AiModelDownloadState());
    });
  });

  group('cancelDownloadForVariant', () {
    test('stops only that variant', () async {
      final s = await service();
      await s.startDownloadForVariant(_gemma);
      await s.startDownloadForVariant(_qwen);

      await s.cancelDownloadForVariant(_gemma);

      expect(repository.variant(_gemma).cancels, 1);
      expect(repository.variant(_qwen).cancels, 0);
      expect(s.isVariantDownloading(_qwen), isTrue);
      expect(prefs.getBool(_inProgressKey), isTrue);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.cancelled,
          variant: _gemma,
          error: 'Download cancelled',
        ),
      );

      await s.cancelDownloadForVariant(_qwen);
      expect(prefs.containsKey(_inProgressKey), isFalse);
      expect(s.isAnyDownloading, isFalse);
    });

    test('a variant not downloading is still reported cancelled', () async {
      final s = await service();

      await s.cancelDownloadForVariant(_gemma);

      expect(s.state, _state(AiModelDownloadStatus.cancelled, variant: _gemma));
    });
  });

  group('per-variant files', () {
    test('existence checks pass through and a failed check is '
        '"missing"', () async {
      final s = await service();

      expect(await s.checkModelExistsForVariant(_gemma), isFalse);
      expect(await s.checkMmprojExistsForVariant(_gemma), isFalse);
      repository
        ..modelExists = true
        ..mmprojExists = true;
      expect(await s.checkModelExistsForVariant(_gemma), isTrue);
      expect(await s.checkMmprojExistsForVariant(_gemma), isTrue);
      repository
        ..existenceError = StateError('disk')
        ..mmprojExistenceError = StateError('disk');
      expect(await s.checkModelExistsForVariant(_gemma), isFalse);
      expect(await s.checkMmprojExistsForVariant(_gemma), isFalse);
      expect(states, isEmpty);
    });

    test('deleting a model goes to the repository', () async {
      final s = await service();

      await s.deleteModelForVariant(_gemma);

      expect(repository.deleted, [_gemma]);
    });
  });

  group('startMmprojDownloadForVariant', () {
    test('a projector already there completes at once', () async {
      final s = await service();
      repository.mmprojExists = true;

      await s.startMmprojDownloadForVariant(_qwen);

      expect(repository.mmprojStarts, 0);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.completed,
          variant: _qwen,
          mmproj: true,
          available: true,
          progress: 100.0,
        ),
      );
    });

    test('reports progress and completes without the in-progress '
        'flag', () async {
      final s = await service();

      await s.startMmprojDownloadForVariant(_qwen);
      expect(s.isAnyDownloading, isTrue);
      expect(s.isVariantDownloading(_qwen), isFalse);
      expect(prefs.containsKey(_inProgressKey), isFalse);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.downloading,
          variant: _qwen,
          mmproj: true,
          progress: 0,
        ),
      );

      repository.mmproj(_qwen).controller.add(70);
      await pumpEventQueue();
      expect(
        s.state,
        _state(AiModelDownloadStatus.downloading, mmproj: true, progress: 70),
      );

      await repository.mmproj(_qwen).controller.close();
      await pumpEventQueue();
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.completed,
          variant: _qwen,
          mmproj: true,
          available: true,
          progress: 100.0,
        ),
      );
      expect(s.isAnyDownloading, isFalse);
    });

    test('a failed existence check still downloads', () async {
      final s = await service();
      repository.mmprojExistenceError = StateError('disk');

      await s.startMmprojDownloadForVariant(_qwen);

      expect(repository.mmprojStarts, 1);
    });

    test('only one projector download runs at a time', () async {
      final s = await service();

      await s.startMmprojDownloadForVariant(_qwen);
      await s.startMmprojDownloadForVariant(_gemma);

      expect(repository.mmprojStarts, 1);
    });

    test('a failed download is an error and frees the slot', () async {
      final s = await service();

      await s.startMmprojDownloadForVariant(_qwen);
      repository.mmproj(_qwen).controller.addError(StateError('offline'));
      await pumpEventQueue();

      expect(
        s.state,
        _state(AiModelDownloadStatus.error, variant: _qwen, mmproj: true),
      );
      expect(s.state.errorMessage, contains('AI model download failed'));
      expect(s.isAnyDownloading, isFalse);
    });

    test('a download that cannot start is an error', () async {
      final s = await service();
      repository.startError = StateError('no network');

      await s.startMmprojDownloadForVariant(_qwen);

      expect(
        s.state,
        _state(AiModelDownloadStatus.error, variant: _qwen, mmproj: true),
      );
      expect(s.isAnyDownloading, isFalse);
    });

    test('cancelling stops it and reports it cancelled', () async {
      final s = await service();
      await s.startMmprojDownloadForVariant(_qwen);

      await s.cancelMmprojDownload();

      expect(repository.mmproj(_qwen).cancels, 1);
      expect(s.isAnyDownloading, isFalse);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.cancelled,
          variant: _qwen,
          mmproj: true,
          error: 'Download cancelled',
        ),
      );
    });
  });

  test('resetState goes back to the idle state', () async {
    final s = await service();
    await s.cancelDownloadForVariant(_gemma);

    s.resetState();

    expect(s.state, const AiModelDownloadState());
  });

  group('app lifecycle', () {
    test('closing the app during a download marks it interrupted, and the '
        'next resume reports it cancelled', () async {
      final s = await service();
      await s.startDownloadForVariant(_gemma);

      s.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(prefs.getBool(_interruptedKey), isTrue);

      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(prefs.containsKey(_interruptedKey), isFalse);
      expect(prefs.containsKey(_inProgressKey), isFalse);
      expect(
        s.state,
        _state(
          AiModelDownloadStatus.cancelled,
          error: 'AI model download was cancelled',
        ),
      );
    });

    test('closing the app with no download marks nothing', () async {
      final s = await service(prefsValues: {_inProgressKey: true});

      s.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(prefs.containsKey(_interruptedKey), isFalse);
    });

    test('a running download without the in-progress flag is not marked '
        'interrupted', () async {
      final s = await service();
      await s.startMmprojDownloadForVariant(_qwen);

      s.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(prefs.containsKey(_interruptedKey), isFalse);
    });

    test('resuming with nothing interrupted changes nothing', () async {
      final s = await service();

      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();

      expect(states, isEmpty);
    });
  });

  test('dispose cancels every download and closes the state stream', () async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final s = AiModelDownloadService(
      repository,
      prefs,
      AppStringsProvider.forLocale(const Locale('en')),
    );
    final done = expectLater(s.stateStream, emitsThrough(emitsDone));
    await s.startDownloadForVariant(_gemma);
    await s.startMmprojDownloadForVariant(_qwen);

    s.dispose();
    await done;

    expect(repository.variant(_gemma).cancels, 1);
    expect(repository.mmproj(_qwen).cancels, 1);
  });
}
