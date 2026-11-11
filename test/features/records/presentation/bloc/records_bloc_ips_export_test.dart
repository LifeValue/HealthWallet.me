import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/log_capture.dart';
import '../../../share_records/share_test_helpers.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  Error? error;
  final requests = <(String?, String?)>[];

  @override
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
    List<String>? sourceIds,
    String? patientId,
  }) async {
    requests.add((sourceId, patientId));
    if (error != null) throw error!;
    return (
      bytes: Uint8List.fromList([37, 80, 68, 70]),
      patientName: 'Jane Doe',
    );
  }
}

class _FakeSpecialtyClassifier extends Fake implements SpecialtyClassifier {}

/// An IPS PDF that is written like any file but cannot be deleted, as when
/// the share target still holds it open.
class _UndeletableFile extends Fake implements File {
  _UndeletableFile(this._file);

  final File _file;

  @override
  String get path => _file.path;

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => _file.writeAsBytes(bytes, mode: mode, flush: flush);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('Operation not permitted', path);
}

/// Makes every IPS PDF undeletable.
final class _UndeletableIpsPdfs extends IOOverrides {
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.contains(' - IPS Summary - ') ? _UndeletableFile(file) : file;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final logs = captureLogs();

  late Directory root;
  late _FakeRecordsRepository repository;
  late RecordsBloc bloc;
  late List<Map<Object?, Object?>> shared;
  late List<IpsExportStatus> statuses;
  late StreamSubscription<IpsExportStatus> statusSub;
  PlatformException? shareError;

  setUp(() {
    root = mockPathProvider();
    SharedPreferences.setMockInitialValues({});
    repository = _FakeRecordsRepository();
    bloc = RecordsBloc(repository, _FakeSpecialtyClassifier());
    shared = [];
    shareError = null;
    statuses = [];
    statusSub = bloc.stream
        .map((s) => s.ipsExportStatus)
        .distinct()
        .listen(statuses.add);
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      if (shareError != null) throw shareError!;
      return 'dev.fluttercommunity.plus/share/success';
    });
  });

  tearDown(() async {
    await statusSub.cancel();
    await bloc.close();
    messenger.setMockMethodCallHandler(_shareChannel, null);
  });

  String today() => RegionPreset.fromString(null).formatDate(DateTime.now());

  File pdf(String name) =>
      File('${root.path}/tmp/$name - IPS Summary - ${today()}.pdf');

  /// Exports and waits until the export has ended, in success or failure.
  /// The handler does real file I/O, so wait for its last state rather than
  /// for the microtask queue.
  Future<void> export({String? patientName, String? patientId}) async {
    final done = bloc.stream
        .skipWhile((s) => s.ipsExportStatus != IpsExportStatus.exporting)
        .firstWhere((s) => s.ipsExportStatus != IpsExportStatus.exporting)
        .timeout(const Duration(seconds: 5));
    bloc.add(
      RecordsSharePressed(patientName: patientName, patientId: patientId),
    );
    await done;
    await pumpEventQueue();
  }

  test('a second tap while exporting is dropped', () async {
    final done = bloc.stream
        .skipWhile((s) => s.ipsExportStatus != IpsExportStatus.exporting)
        .firstWhere((s) => s.ipsExportStatus != IpsExportStatus.exporting)
        .timeout(const Duration(seconds: 5));
    bloc
      ..add(const RecordsSharePressed(patientId: 'p1'))
      ..add(const RecordsSharePressed(patientId: 'p1'));
    await done;
    await pumpEventQueue();

    expect(repository.requests, hasLength(1));
    expect(shared, hasLength(1));
  });

  test('starts idle', () {
    expect(bloc.state.ipsExportStatus, IpsExportStatus.idle);
  });

  test('writes the IPS PDF to temp and opens the share sheet', () async {
    await export(patientId: 'p1');

    expect(statuses, [IpsExportStatus.exporting, IpsExportStatus.idle]);

    final file = pdf('Jane Doe');
    expect(repository.requests, [(null, 'p1')]);
    expect(file.readAsBytesSync(), [37, 80, 68, 70]);
    expect(shared, hasLength(1));
    expect(shared.single['title'], 'Jane Doe - IPS Summary - ${today()}');
    expect(shared.single['paths'], [file.path]);
  });

  test(
    'the given patient name wins and is stripped of path characters',
    () async {
      await export(patientName: '../Jo/hn: Smith');

      expect(pdf('John Smith').existsSync(), isTrue);
      expect(Directory('${root.path}/tmp').listSync(), hasLength(1));
    },
  );

  test('a new export deletes the previous PDF', () async {
    await export(patientName: 'First');
    final first = pdf('First');
    expect(first.existsSync(), isTrue);

    await export(patientName: 'Second');

    expect(first.existsSync(), isFalse);
    expect(pdf('Second').existsSync(), isTrue);
  });

  test('a previous PDF that cannot be deleted is logged and left for the '
      'startup sweep, and the new export is still shared', () async {
    // The bloc's handlers run in the zone it was created in.
    await statusSub.cancel();
    await bloc.close();
    bloc = IOOverrides.runWithIOOverrides(
      () => RecordsBloc(repository, _FakeSpecialtyClassifier()),
      _UndeletableIpsPdfs(),
    );
    statuses = [];
    statusSub = bloc.stream
        .map((s) => s.ipsExportStatus)
        .distinct()
        .listen(statuses.add);

    await export(patientName: 'First');
    await export(patientName: 'Second');

    expect(logs, loggedWarning('Deleting the previous IPS PDF failed'));
    expect(pdf('First').existsSync(), isTrue);
    expect(pdf('Second').existsSync(), isTrue);
    expect(shared, hasLength(2));
    expect(shared.last['paths'], [pdf('Second').path]);
    expect(bloc.state.ipsExportStatus, IpsExportStatus.idle);
  });

  test('exporting the same patient again keeps one current PDF', () async {
    await export();
    await export();

    expect(pdf('Jane Doe').existsSync(), isTrue);
    expect(shared, hasLength(2));
  });

  test('the newest PDF stays in temp after sharing', () async {
    await export();
    await pumpEventQueue();

    expect(pdf('Jane Doe').existsSync(), isTrue);
  });

  test('a failed export writes and shares nothing', () async {
    repository.error = StateError('no patient');

    await export();

    expect(Directory('${root.path}/tmp').listSync(), isEmpty);
    expect(shared, isEmpty);
    expect(statuses, [IpsExportStatus.exporting, IpsExportStatus.failed]);
  });

  test('each failed export is a new failure for listeners', () async {
    repository.error = StateError('no patient');

    await export();
    await export();

    expect(statuses, [
      IpsExportStatus.exporting,
      IpsExportStatus.failed,
      IpsExportStatus.exporting,
      IpsExportStatus.failed,
    ]);
  });

  test('a share sheet that fails to open fails the export', () async {
    shareError = PlatformException(code: 'SHARE_FAILED');

    await export();

    expect(shared, hasLength(1));
    expect(bloc.state.ipsExportStatus, IpsExportStatus.failed);
  });

  test('an export after a failure succeeds again', () async {
    repository.error = StateError('no patient');
    await export();
    repository.error = null;

    await export();

    expect(bloc.state.ipsExportStatus, IpsExportStatus.idle);
    expect(shared, hasLength(1));
  });
}
