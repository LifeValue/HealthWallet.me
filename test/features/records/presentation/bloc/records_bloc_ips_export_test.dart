import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../share_records/share_test_helpers.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

class _FakeRecordsRepository extends Fake implements RecordsRepository {
  Error? error;
  final requests = <(String?, String?)>[];

  @override
  Future<({Uint8List bytes, String patientName})> buildIpsExport({
    String? sourceId,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory root;
  late _FakeRecordsRepository repository;
  late RecordsBloc bloc;
  late List<Map<Object?, Object?>> shared;

  setUp(() {
    root = mockPathProvider();
    SharedPreferences.setMockInitialValues({});
    repository = _FakeRecordsRepository();
    bloc = RecordsBloc(repository, _FakeSpecialtyClassifier());
    shared = [];
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      return 'dev.fluttercommunity.plus/share/success';
    });
  });

  tearDown(() async {
    await bloc.close();
    messenger.setMockMethodCallHandler(_shareChannel, null);
  });

  String today() => RegionPreset.fromString(null).formatDate(DateTime.now());

  File pdf(String name) =>
      File('${root.path}/tmp/$name - IPS Summary - ${today()}.pdf');

  /// Exports and waits until the share sheet opens, or until the export
  /// failed. The handler emits no state and does real file I/O, so the share
  /// call is the signal that it finished.
  Future<void> export({String? patientName, String? patientId}) async {
    final sharesBefore = shared.length;
    final requestsBefore = repository.requests.length;
    bloc.add(
      RecordsSharePressed(patientName: patientName, patientId: patientId),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (shared.length == sharesBefore && DateTime.now().isBefore(deadline)) {
      if (repository.error != null &&
          repository.requests.length > requestsBefore) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await pumpEventQueue();
  }

  test('writes the IPS PDF to temp and opens the share sheet', () async {
    await export(patientId: 'p1');

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
  });
}
