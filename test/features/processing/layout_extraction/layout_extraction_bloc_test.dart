import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/data/local/app_database.dart'
    show FhirResourceLocalDto;
import 'package:health_wallet/core/l10n/app_strings_provider.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/holders/domain/repository/holder_repository.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linking_service.dart';
import 'package:health_wallet/features/holders/domain/services/holder_selection.dart';
import 'package:health_wallet/features/holders/domain/services/holder_service.dart';
import 'package:health_wallet/features/processing/data/extractors/clearvis/clearvis_io_extractor.dart';
import 'package:health_wallet/features/processing/domain/entity/extraction_output_mode.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_practitioner.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/domain/services/document_reference_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extraction_service.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/ocr_processing_service.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/repository/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_device_capability_service.dart';
import 'clearvis_io_extractor_test.dart' show fixture;

/// The wallet's rows by row id, as the database would hand them back.
class _Wallet {
  final rows = <String, IFhirResource>{};
  final sources = <String, Source>{};
  final documents = <({String sessionId, String? encounterId})>[];
  int writes = 0;

  void put(IFhirResource resource) {
    final dto = resource.toDto();
    rows[resource.id] = IFhirResource.fromLocalDto(
      FhirResourceLocalDto(
        id: resource.id,
        sourceId: dto.sourceId,
        resourceType: dto.resourceType,
        resourceId: dto.resourceId,
        title: dto.title,
        date: dto.date,
        resourceRaw: jsonEncode(dto.resourceRaw),
        encounterId: dto.encounterId,
        subjectId: dto.subjectId,
      ),
    );
  }

  List<T> of<T extends IFhirResource>() => rows.values.whereType<T>().toList();
}

class _FakeRecords extends Fake implements RecordsRepository {
  _FakeRecords(this.wallet);
  final _Wallet wallet;

  @override
  Future<List<IFhirResource>> getResources({
    List<FhirType> resourceTypes = const [],
    String? sourceId,
    List<String>? sourceIds,
    int limit = 20,
    int offset = 0,
    DateFilter? dateFilter,
  }) async => wallet.rows.values
      .where(
        (r) =>
            (resourceTypes.isEmpty || resourceTypes.contains(r.fhirType)) &&
            (sourceId == null || r.sourceId == sourceId) &&
            (sourceIds == null || sourceIds.contains(r.sourceId)),
      )
      .toList();

  @override
  Future<void> updatePatient(IFhirResource patient) async {
    wallet.writes++;
    wallet.put(patient);
  }
}

class _FakeSync extends Fake implements SyncRepository {
  _FakeSync(this.wallet);
  final _Wallet wallet;

  @override
  Future<List<Source>> getSources() async => wallet.sources.values.toList();

  @override
  Future<void> cacheSources(List<Source> sources) async {
    for (final s in sources) {
      wallet.sources[s.id] = s;
    }
  }

  @override
  Future saveResources(List<IFhirResource> resources) async {
    wallet.writes++;
    resources.forEach(wallet.put);
  }
}

class _FakeHolderRepository extends Fake implements HolderRepository {
  _FakeHolderRepository(this.wallet);
  final _Wallet wallet;

  @override
  Future<bool> hasUnassigned() async => false;

  @override
  Future<Map<String, String>> holderBySource() async => {
    for (final s in wallet.sources.values)
      if (s.holderId != null) s.id: s.holderId!,
  };

  @override
  Future<void> mergeHolders(Map<String, String> into) async {
    fail('people of two clinics were merged: $into');
  }

  @override
  Future<HolderSnapshot> snapshot() => throw UnimplementedError();
}

class _FakeDocuments extends Fake implements DocumentReferenceService {
  _FakeDocuments(this.wallet);
  final _Wallet wallet;

  @override
  Future<List<String>> replaceSessionDocuments({
    required String sessionId,
    required List<String> filePaths,
    required String patientId,
    Encounter? encounter,
    required String sourceId,
    String? title,
  }) async {
    wallet.documents.add((sessionId: sessionId, encounterId: encounter?.id));
    return const [];
  }
}

class _FakeSelection extends Fake implements HolderSelection {
  @override
  Future<void> select(String holderId) async {}
}

/// No AI model on the device unless [modelExists]; an AI call is recorded
/// and fails.
class _NoModel extends Fake implements ProcessingRepository {
  bool modelExists = false;
  int aiCalls = 0;
  int containerOnlyCalls = 0;

  @override
  Future<MappingResource> mapContainerOnly(
    String ocrText, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    containerOnlyCalls++;
    throw Exception('no AI in this test');
  }

  @override
  Future<bool> checkModelExistence() async => modelExists;

  @override
  Future<(MappingPatient, MappingResource)> mapBasicInfo(
    List<String> imagePaths, {
    int? maxTokens,
    int? gpuLayers,
    int? threads,
    int? contextSize,
    ExtractionOutputMode outputMode = ExtractionOutputMode.defaultMode,
  }) async {
    aiCalls++;
    throw Exception('no AI in this test');
  }

  @override
  Future<int> editProcessingSession(ProcessingSession session) async => 1;

  @override
  bool get shouldCancelGeneration => false;
}

/// Reads the fixture named by the page path.
class _FixtureOcr extends Fake implements OcrProcessingHelper {
  int calls = 0;

  /// The pages of each OCR run, in order.
  final runs = <List<String>>[];

  /// Text of pages that are not a fixture.
  final texts = <String, String>{};

  @override
  Future<String> processOcrForImages(List<String> imagePaths) async {
    calls++;
    runs.add(List.of(imagePaths));
    return [
      for (final path in imagePaths)
        texts[path.split('/').last.split('.').first] ??
            fixture(path.split('/').last.split('.').first),
    ].join('\n');
  }

  @override
  Future<List<String>> prepareAllImages({
    required List<String> filePaths,
    double dpi = 72,
  }) async => filePaths;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Wallet wallet;
  late _FixtureOcr ocr;
  late _NoModel ai;
  late ProcessingBloc bloc;
  var sessions = 0;

  setUpAll(
    () => ProcessingLogBuffer.debugOverrideInstance(
      ProcessingLogBuffer.forTesting(
        enabled: false,
        directory: Directory.systemTemp,
      ),
    ),
  );
  tearDownAll(() => ProcessingLogBuffer.debugOverrideInstance(null));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    wallet = _Wallet();
    ocr = _FixtureOcr();
    final records = _FakeRecords(wallet);
    final sync = _FakeSync(wallet);
    final holderRepository = _FakeHolderRepository(wallet);
    final holders = HolderService(
      HolderLinkingService(holderRepository),
      holderRepository,
      records,
      sync,
    );
    ai = _NoModel();
    bloc = ProcessingBloc(
      ai,
      ocr,
      sync,
      _FakeDocuments(wallet),
      holders,
      _FakeSelection(),
      records,
      await SharedPreferences.getInstance(),
      AppStringsProvider.forLocale(const Locale('en')),
      LayoutExtractionService(
        ai,
        ocr,
        LayoutExtractorRegistry(const [ClearvisIoExtractor()]),
        holders,
        records,
      ),
      FakeDeviceCapabilityService(),
    );
  });

  tearDown(() => bloc.close());

  /// Starts processing [document] (a fixture name, or several pages) and
  /// returns its id.
  String activate(String document, {List<String>? pages}) {
    final id = 's${sessions++}';
    final session = ProcessingSession(
      id: id,
      filePaths: pages ?? ['/imports/$document.png'],
      origin: ProcessingOrigin.import,
      createdAt: DateTime(2026),
    );
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(bloc.state.copyWith(sessions: [session, ...bloc.state.sessions]));
    bloc.add(SessionActivated(sessionId: id));
    return id;
  }

  /// Imports [document] (a fixture name) and waits for its review.
  Future<ProcessingSession> import(String document) async {
    final id = 's${sessions++}';
    final session = ProcessingSession(
      id: id,
      filePaths: ['/imports/$document.png'],
      origin: ProcessingOrigin.import,
      createdAt: DateTime(2026),
    );
    // ignore: invalid_use_of_visible_for_testing_member
    bloc.emit(bloc.state.copyWith(sessions: [session, ...bloc.state.sessions]));
    final review = bloc.stream
        .map((s) => s.sessions.firstWhere((x) => x.id == id))
        .firstWhere((x) => x.status == ProcessingStatus.draft);
    bloc.add(SessionActivated(sessionId: id));
    return review.timeout(const Duration(seconds: 5));
  }

  Future<void> save(ProcessingSession session) async {
    final done = bloc.stream.firstWhere(
      (s) => s.status is Success || s.status is Failure,
    );
    bloc.add(ResourceCreationInitiated(sessionId: session.id));
    final state = await done.timeout(const Duration(seconds: 5));
    expect(state.status, isA<Success>(), reason: '${state.status}');
  }

  List<VisionPrescription> prescriptions() =>
      wallet.of<VisionPrescription>()
        ..sort((a, b) => a.lensType.index.compareTo(b.lensType.index));

  void expectOneCompleteVisit() {
    final visits = wallet.of<Encounter>();
    expect(visits, hasLength(1));
    final visit = visits.single;
    expect(
      (visit.rawResource['identifier'] as List).map((i) => i['value']),
      containsAll([
        'optica-exemplu-1|PA-01234|2024-03-14',
        'EE-0000054321',
      ]),
    );
    final stored = prescriptions();
    expect(stored, hasLength(3));
    expect(stored.map((p) => p.identifier!.single.value!.valueString), [
      'PR-0000012340',
      'PR-0000012341',
      'PR-0000012342',
    ]);
    for (final p in stored) {
      expect(p.encounter!.reference!.valueString, 'Encounter/${visit.id}');
      expect(p.prescriber!.reference!.valueString, startsWith('Practitioner/'));
      expect(p.followUpDate, '2025-03-14');
    }
    expect(wallet.of<Patient>(), hasLength(1));
    expect(wallet.of<Organization>(), hasLength(1));
    expect(wallet.of<Practitioner>(), hasLength(1));
    expect(wallet.documents, hasLength(2));
    expect(wallet.documents.map((d) => d.encounterId), [visit.id, visit.id]);
  }

  test(
    'a recognised document reaches the review without AI or model',
    () async {
      final review = await import('clearvis_prescriptions');

      expect(review.patient.mode, ImportMode.createNew);
      expect(review.patient.draft!.patientIdentifier.value, 'PA-01234');
      expect(review.encounter.mode, ImportMode.createNew);
      expect(review.encounter.draft!.visitKey, isNotNull);
      expect(
        review.resources.whereType<MappingVisionPrescription>(),
        hasLength(3),
      );
      expect(review.resources, [
        isA<MappingOrganization>(),
        isA<MappingPractitioner>(),
        ...List.filled(3, isA<MappingVisionPrescription>()),
      ]);
      expect(ocr.calls, 1, reason: 'the model gate and the pipeline share OCR');
      expect(review.isAlreadyInWallet, isFalse);
    },
  );

  test('prescriptions, then exam: one visit, completed', () async {
    await save(await import('clearvis_prescriptions'));

    final exam = await import('clearvis_exam');
    expect(exam.patient.mode, ImportMode.linkExisting);
    expect(exam.encounter.mode, ImportMode.linkExisting);
    expect(exam.encounter.completesExistingVisit, isTrue);
    expect(
      exam.resources.map(
        (r) => (r as MappingVisionPrescription).existingId.isNotEmpty,
      ),
      [true, true, true],
      reason: 'the clinic is already in the wallet; the prescriptions too',
    );
    expect(
      exam.resources.cast<MappingVisionPrescription>().map(
        (r) => r.completesExisting,
      ),
      [false, false, false],
    );
    await save(exam);

    expectOneCompleteVisit();
  });

  test('exam, then prescriptions: one visit, completed', () async {
    await save(await import('clearvis_exam'));
    expect(prescriptions().map((p) => p.identifier), everyElement(isNull));

    final review = await import('clearvis_prescriptions');
    expect(review.encounter.mode, ImportMode.linkExisting);
    expect(review.encounter.completesExistingVisit, isFalse);
    final staged = review.resources.whereType<MappingVisionPrescription>();
    expect(staged.map((r) => r.completesExisting), [true, true, true]);
    await save(review);

    expectOneCompleteVisit();
    for (final p in prescriptions()) {
      final tags = (p.rawResource['meta']['tag'] as List).map(
        (t) => '${t['system']}#${t['code']}',
      );
      expect(
        tags,
        containsAll([
          'http://healthwallet.me/specialty#ophthalmology',
          'http://healthwallet.me/extractor#clearvis.io@1',
        ]),
      );
    }
  });

  test('importing either document again writes nothing', () async {
    await save(await import('clearvis_prescriptions'));
    await save(await import('clearvis_exam'));
    final writes = wallet.writes;
    final rows = Map.of(wallet.rows);

    for (final document in ['clearvis_exam', 'clearvis_prescriptions']) {
      final again = await import(document);
      expect(again.isAlreadyInWallet, isTrue, reason: document);
      await save(again);
    }

    expect(wallet.writes, writes);
    expect(wallet.rows.keys, rows.keys);
    expect(wallet.documents, hasLength(2));
  });

  test(
    'completing keeps what the user edited and fills only the rest',
    () async {
      await save(await import('clearvis_exam'));
      final multifocal = prescriptions().firstWhere(
        (p) => p.lensType == VisionLensType.multifocal,
      );
      wallet.put(
        multifocal.copyWith(
          rawResource: {
            ...multifocal.rawResource,
            'dateWritten': '2024-03-15',
            'extension': [
              {
                'url': 'http://healthwallet.me/fhir/StructureDefinition/recommended-follow-up',
                'valueDate': '2024-09-01',
              },
            ],
          },
        ),
      );

      await save(await import('clearvis_prescriptions'));

      final completed = wallet.rows[multifocal.id] as VisionPrescription;
      expect(completed.dateWritten!.valueString, '2024-03-15');
      expect(completed.followUpDate, '2024-09-01');
      expect(completed.identifier!.single.value!.valueString, 'PR-0000012340');
      expect(
        completed.prescriber!.reference!.valueString,
        startsWith('Practitioner/'),
      );
      expect(prescriptions(), hasLength(3));
    },
  );

  test('another clinic\'s same patient number is someone else', () async {
    await save(await import('clearvis_prescriptions'));
    final other = await import('clearvis_prescriptions_second_tenant');

    expect(other.patient.mode, ImportMode.createNew);
    expect(other.encounter.mode, ImportMode.createNew);
    await save(other);

    expect(wallet.of<Patient>(), hasLength(2));
    expect(wallet.of<Encounter>(), hasLength(2));
    expect(prescriptions(), hasLength(6));
  });

  group('documents no extractor reads', () {
    test('without a model they still fail as modelNotFound', () async {
      ocr.texts['lab'] = 'BULETIN DE ANALIZE\nHemoglobina 13,5 g/dL';
      final failure = bloc.stream
          .map((s) => s.status)
          .firstWhere((s) => s is Failure);
      activate('lab');
      expect(
        ((await failure.timeout(const Duration(seconds: 5))) as Failure).reason,
        PipelineFailureReason.modelNotFound,
      );
      expect(ai.aiCalls, 0);
    });

    test('a recognised layout missing the patient goes to the AI', () async {
      ai.modelExists = true;
      ocr.texts['nameless'] = fixture('clearvis_prescriptions')
          .split('\n')
          .where((l) => !l.contains('Ioana') && !l.contains('Marinescu'))
          .join('\n');
      final failure = bloc.stream
          .map((s) => s.status)
          .firstWhere((s) => s is Failure);
      activate('nameless');
      await failure.timeout(const Duration(seconds: 5));
      expect(ai.aiCalls, 1);
      expect(wallet.writes, 0);
    });
  });

  List<String> tagsOf(IFhirResource r) => [
    for (final t in (r.rawResource['meta']?['tag'] as List?) ?? const [])
      '${t['system']}#${t['code']}',
  ];
  const extractorTag = 'http://healthwallet.me/extractor#clearvis.io@1';

  test('the person, clinic and examiner carry the extractor tag', () async {
    await save(await import('clearvis_prescriptions'));
    for (final r in [
      ...wallet.of<Patient>(),
      ...wallet.of<Organization>(),
      ...wallet.of<Practitioner>(),
    ]) {
      expect(tagsOf(r), contains(extractorTag), reason: '${r.fhirType}');
    }
  });

  test('filling in the default holder tags what it fills', () async {
    wallet.sources['wallet-default_patient'] = const Source(
      id: 'wallet-default_patient',
      platformType: 'wallet',
      holderId: 'default_patient',
    );
    wallet.put(
      const Patient(
        id: 'dp-row',
        resourceId: 'dp-row',
        sourceId: 'wallet-default_patient',
        rawResource: {
          'resourceType': 'Patient',
          'id': 'dp-row',
          'name': [
            {
              'family': 'Holder',
              'given': ['Health Wallet'],
            },
          ],
          'identifier': [
            {'value': 'default_patient'},
          ],
        },
      ),
    );

    final review = await import('clearvis_prescriptions');
    expect(review.patient.mode, ImportMode.linkExisting);
    expect(review.patient.draft, isNotNull);
    await save(review);

    final filled = wallet.rows['dp-row']!;
    expect(
      ((filled.rawResource['name'] as List).single as Map)['family'],
      'Popescu',
    );
    expect(tagsOf(filled), contains(extractorTag));
  });

  test('a clinic number in another document never pre-matches the person', () async {
    await save(await import('clearvis_prescriptions'));
    ai.modelExists = true;
    ocr.texts['letter'] =
        'Scrisoare medicala\nPacient: Ion Ionescu\nNr. PA-01234\nDiagnostic: X';
    final failure = bloc.stream
        .map((s) => s.status)
        .firstWhere((s) => s is Failure);
    activate('letter');
    await failure.timeout(const Duration(seconds: 5));
    expect(ai.containerOnlyCalls, 0);
    expect(ai.aiCalls, 1);
  });

  test('reordered pages are read again, in their new order', () async {
    ocr.texts['lab1'] = 'BULETIN DE ANALIZE';
    ocr.texts['lab2'] = 'Hemoglobina 13,5 g/dL';
    final pages = ['/imports/lab1.png', '/imports/lab2.png'];
    Future<void> failed() => bloc.stream
        .map((s) => s.status)
        .firstWhere((s) => s is Failure)
        .timeout(const Duration(seconds: 5));

    var failure = failed();
    final id = activate('lab', pages: pages);
    await failure;
    expect(ocr.calls, 1);

    bloc.add(
      PagesReordered(sessionId: id, reorderedPaths: pages.reversed.toList()),
    );
    await pumpEventQueue();
    failure = failed();
    bloc.add(SessionActivated(sessionId: id));
    await failure;

    expect(ocr.calls, 2);
    expect(ocr.runs.last, pages.reversed.toList());
  });
}
