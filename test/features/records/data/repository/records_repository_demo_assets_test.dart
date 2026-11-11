import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/data/repository/records_repository_impl.dart';

import '../../records_test_helpers.dart';

const _demoJson = 'assets/demo_data/demo_data.json';
const _demoPdf = 'assets/demo_data/pdf_preview_demo_data.pdf';

/// The demo data as other asset files would hold it: the bundle serves
/// [assets] (key → JSON) and has no other file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordsRepositoryImpl repository;
  late Map<String, Object> assets;
  late List<String> requested;

  setUp(() async {
    db = openTestDatabase();
    repository = await openRepository(db);
    assets = {};
    requested = [];
    // The bundle caches the text it loaded; each test serves its own.
    rootBundle.evict(_demoJson);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          requested.add(key);
          final asset = assets[key];
          if (asset == null) return null;
          return ByteData.sublistView(utf8.encode(jsonEncode(asset)));
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    rootBundle.evict(_demoJson);
    await db.close();
  });

  Future<List<String>> demoIds() async => [
    for (final row in await (db.select(
      db.fhirResource,
    )..where((r) => r.sourceId.equals('demo_data'))).get())
      row.id,
  ];

  test('a plain list of resources loads, and a missing demo PDF is '
      'skipped', () async {
    assets[_demoJson] = {
      'resources': [
        {
          'resourceType': 'Patient',
          'id': 'demo-patient',
          'name': [
            {
              'family': 'Doe',
              'given': ['John'],
            },
          ],
        },
        {
          'resourceType': 'Observation',
          'id': 'demo-obs',
          'status': 'final',
          'code': {'text': 'Heart rate'},
          'subject': {'reference': 'Patient/demo-patient'},
        },
      ],
    };

    await repository.loadDemoData();

    expect(await demoIds(), unorderedEquals(['demo-patient', 'demo-obs']));
    expect(await repository.hasDemoData(), isTrue);
    expect(requested, contains(_demoPdf));
  });

  test('a file with neither a bundle nor a resource list fails and stores '
      'nothing', () async {
    assets[_demoJson] = {'resourceType': 'Patient'};

    await expectLater(
      repository.loadDemoData(),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('invalid format'),
        ),
      ),
    );

    expect(await demoIds(), isEmpty);
    expect(await repository.hasDemoData(), isFalse);
  });

  test('a missing demo file fails', () async {
    await expectLater(
      repository.loadDemoData(),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          startsWith('Exception: Failed to load demo data'),
        ),
      ),
    );

    expect(await demoIds(), isEmpty);
  });
}
