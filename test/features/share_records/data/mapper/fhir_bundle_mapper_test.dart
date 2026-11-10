import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/share_records/data/mapper/fhir_bundle_mapper.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';
import '../../share_test_helpers.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Sends [payload] over the "wire" (JSON text) and decodes it again.
SharePayload _roundTrip(SharePayload payload) => SharePayload.fromJson(
  jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>,
);

Future<ParseBundleResult> _parse(
  List<Map<String, dynamic>> entries, {
  String? tempDir,
}) => FhirBundleMapper.parseBundle(
  SharePayloadBundle(entry: entries),
  tempDir: tempDir,
);

Future<IFhirResource> _parseOne(Map<String, dynamic> resource) async {
  final result = await _parse([
    {'resource': resource},
  ]);
  expect(result.resources, hasLength(1));
  return result.resources.single;
}

Map<String, dynamic> _attachment(IFhirResource resource, [int index = 0]) =>
    ((resource.rawResource['content'] as List)[index] as Map)['attachment']
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('toSharePayload', () {
    test('wraps every record with its resource id and metadata', () async {
      final observation = record(
        observationJson(value: {'valueString': 'ok'}),
        id: 'local-obs',
        resourceId: 'server-obs',
      );
      final condition = record(conditionJson(), id: 'local-cond');

      final payload = await FhirBundleMapper.toSharePayload(
        records: [observation, condition],
        deviceName: 'Jane\'s iPhone',
        activeFilters: const ['Observation'],
      );

      expect(payload.id, matches(_uuidPattern));
      expect(payload.senderDeviceName, 'Jane\'s iPhone');
      expect(payload.expiresInSeconds, 300);
      expect(payload.isViewOnly, isTrue);
      expect(payload.activeFilters, ['Observation']);
      expect(payload.bundle.resourceType, 'Bundle');
      expect(payload.bundle.type, 'collection');
      expect(payload.bundle.lastUpdated, isNotNull);
      expect(payload.bundle.entry, hasLength(2));

      final first = payload.bundle.entry.first;
      expect(first['_resourceId'], 'server-obs');
      expect(first['resource'], observationJson(value: {'valueString': 'ok'}));
      expect(first.containsKey('_notes'), isFalse);
      expect(payload.bundle.entry.last['_resourceId'], 'cond-1');
    });

    test('attaches notes keyed by the local record id', () async {
      final observation = record(observationJson(), id: 'local-obs');
      final condition = record(conditionJson(), id: 'local-cond');
      final note = RecordNote(
        id: 7,
        resourceId: 'local-obs',
        content: 'Repeat in 3 months',
        timestamp: DateTime.utc(2024, 3, 20, 8),
      );

      final payload = await FhirBundleMapper.toSharePayload(
        records: [observation, condition],
        deviceName: 'Pixel',
        expiresInSeconds: 60,
        notesMap: {
          'local-obs': [note],
          'local-cond': const [],
        },
      );

      expect(payload.expiresInSeconds, 60);
      expect(payload.bundle.entry.first['_notes'], [
        {
          'content': 'Repeat in 3 months',
          'timestamp': '2024-03-20T08:00:00.000Z',
        },
      ]);
      expect(payload.bundle.entry.last.containsKey('_notes'), isFalse);
    });

    test('creates an empty bundle for no records', () async {
      final payload = await FhirBundleMapper.toSharePayload(
        records: const [],
        deviceName: 'Pixel',
      );
      expect(payload.bundle.entry, isEmpty);
    });

    group('DocumentReference attachments', () {
      late Directory root;
      setUp(() => root = mockPathProvider());

      Future<Map<String, dynamic>> share(String url) async {
        final doc = record(
          documentReferenceJson(
            attachments: [
              {'contentType': 'application/pdf', 'title': 'a.pdf', 'url': url},
            ],
          ),
        );
        final payload = await FhirBundleMapper.toSharePayload(
          records: [doc],
          deviceName: 'Pixel',
        );
        final resource =
            payload.bundle.entry.single['resource'] as Map<String, dynamic>;
        return ((resource['content'] as List).single
                as Map<String, dynamic>)['attachment']
            as Map<String, dynamic>;
      }

      test('embeds an absolute file:// attachment as base64', () async {
        final file = File('${root.path}/report.pdf')
          ..writeAsBytesSync([1, 2, 3, 250]);

        final attachment = await share('file://${file.path}');

        expect(attachment['data'], base64Encode([1, 2, 3, 250]));
        expect(attachment.containsKey('url'), isFalse);
        expect(attachment['title'], 'a.pdf');
      });

      test('resolves paths relative to the documents directory', () async {
        File('${root.path}/Documents/scans/a.pdf')
          ..createSync(recursive: true)
          ..writeAsStringSync('pdf');

        final attachment = await share('file://scans/a.pdf');

        expect(attachment['data'], base64Encode(utf8.encode('pdf')));
      });

      test('embeds a file whose stored name has unencoded accents', () async {
        File('${root.path}/Documents/Scrisoare medicală_1a2b3c4d.pdf')
          ..createSync(recursive: true)
          ..writeAsStringSync('pdf');

        final attachment = await share(
          'file://Scrisoare medicală_1a2b3c4d.pdf',
        );

        expect(attachment['data'], base64Encode(utf8.encode('pdf')));
        expect(attachment.containsKey('url'), isFalse);
      });

      test('keeps the url of a missing relative file', () async {
        final attachment = await share('file://scans/missing.pdf');

        expect(attachment['url'], 'file://scans/missing.pdf');
        expect(attachment.containsKey('data'), isFalse);
      });

      test(
        're-maps stale iOS container paths to the current container',
        () async {
          File('${root.path}/Documents/scans/a.pdf')
            ..createSync(recursive: true)
            ..writeAsStringSync('moved');

          final attachment = await share(
            'file:///var/mobile/Containers/Data/Application/OLD-UUID/'
            'Documents/scans/a.pdf',
          );

          expect(attachment['data'], base64Encode(utf8.encode('moved')));
        },
      );

      for (final dir in ['Documents', 'Library/Caches', 'tmp']) {
        test('finds a stale iOS file by name in $dir', () async {
          File('${root.path}/$dir/scan.jpg')
            ..createSync(recursive: true)
            ..writeAsStringSync(dir);

          final attachment = await share(
            'file:///var/mobile/Containers/Data/Application/OLD-UUID/'
            'Documents/old/folder/scan.jpg',
          );

          expect(attachment['data'], base64Encode(utf8.encode(dir)));
        });
      }

      test('keeps the url when a stale iOS file cannot be found', () async {
        const url =
            'file:///var/mobile/Containers/Data/Application/OLD/Documents/x.pdf';
        final attachment = await share(url);
        expect(attachment['url'], url);
      });

      test('keeps the url of a missing non-container absolute path', () async {
        final attachment = await share('file:///nowhere/x.pdf');
        expect(attachment['url'], 'file:///nowhere/x.pdf');
      });

      test('leaves remote urls untouched', () async {
        final attachment = await share('https://fhir.example.org/Binary/1');
        expect(attachment['url'], 'https://fhir.example.org/Binary/1');
        expect(attachment.containsKey('data'), isFalse);
      });

      test('ignores DocumentReferences without content', () async {
        final json = documentReferenceJson();
        final doc = record(json);
        final raw = Map<String, dynamic>.from(doc.rawResource)
          ..remove('content');
        final payload = await FhirBundleMapper.toSharePayload(
          records: [_RawOnly(doc, raw)],
          deviceName: 'Pixel',
        );
        expect(payload.bundle.entry.single['resource'], raw);
      });

      test(
        'does not mutate the record that is being shared',
        () async {
          final file = File('${root.path}/report.pdf')..writeAsBytesSync([1]);
          final doc = record(
            documentReferenceJson(
              attachments: [
                {'title': 'report.pdf', 'url': 'file://${file.path}'},
              ],
            ),
          );

          await FhirBundleMapper.toSharePayload(
            records: [doc],
            deviceName: 'Pixel',
          );

          expect(_attachment(doc)['url'], 'file://${file.path}');
          expect(_attachment(doc).containsKey('data'), isFalse);
        },
        skip:
            'BUG: rawResource is only shallow-copied, so embedding the '
            'attachment removes `url` and adds base64 `data` on the '
            "sender's in-memory record",
      );
    });
  });

  group('parseBundle', () {
    test('round-trips a payload into new shared records', () async {
      final note = RecordNote(
        content: 'Ask about dosage',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4),
      );
      final records = [
        record(
          observationJson(
            value: {'valueQuantity': quantity(13.5, unit: 'g/dL')},
          ),
          id: 'local-obs',
          resourceId: 'server-obs',
        ),
        record(encounterJson(), id: 'local-enc'),
        record(medicationRequestJson(), id: 'local-med'),
      ];
      final payload = await FhirBundleMapper.toSharePayload(
        records: records,
        deviceName: 'Pixel',
        notesMap: {
          'local-obs': [note],
        },
      );

      final result = await FhirBundleMapper.parseBundle(
        _roundTrip(payload).bundle,
      );

      expect(result.tempFilePaths, isEmpty);
      expect(result.resources.map((r) => r.fhirType), [
        FhirType.Observation,
        FhirType.Encounter,
        FhirType.MedicationRequest,
      ]);
      final observation = result.resources.first as Observation;
      expect(observation.id, matches(_uuidPattern));
      expect(observation.id, isNot('local-obs'));
      expect(observation.sourceId, 'shared');
      expect(observation.resourceId, 'server-obs');
      expect(observation.title, 'Hemoglobin [Mass/volume] in Blood');
      expect(observation.date, DateTime.utc(2024, 3, 15, 10, 30));
      expect(observation.encounterId, 'enc-1');
      expect(observation.subjectId, 'pat-1');
      expect(
        observation.rawResource,
        observationJson(value: {'valueQuantity': quantity(13.5, unit: 'g/dL')}),
      );

      expect(result.notes.keys, [observation.id]);
      final parsedNote = result.notes[observation.id]!.single;
      expect(parsedNote.content, 'Ask about dosage');
      expect(parsedNote.timestamp, DateTime.utc(2024, 1, 2, 3, 4));
    });

    test('skips entries without a resource or resourceType', () async {
      final result = await _parse([
        {'_resourceId': 'x'},
        {
          'resource': {'id': 'no-type'},
        },
        {'resource': conditionJson()},
      ]);
      expect(result.resources.single.fhirType, FhirType.Condition);
    });

    test('drops resources the FHIR parser rejects', () async {
      final result = await _parse([
        {
          'resource': {...observationJson(), 'code': 'not a CodeableConcept'},
        },
        {'resource': conditionJson()},
      ]);
      expect(result.resources.single.fhirType, FhirType.Condition);
    });

    test('keeps the resource but drops malformed notes', () async {
      final result = await _parse([
        {
          'resource': conditionJson(),
          '_notes': ['not a map'],
        },
      ]);
      expect(result.resources, hasLength(1));
      expect(result.notes, isEmpty);
    });

    test('tolerates notes with a bad timestamp', () async {
      final before = DateTime.now();
      final result = await _parse([
        {
          'resource': conditionJson(),
          '_notes': [
            {'content': 'hi', 'timestamp': 'yesterday'},
            <String, dynamic>{},
          ],
          '_resourceId': 42,
        },
      ]);
      final resource = result.resources.single;
      expect(resource.resourceId, '42');
      final notes = result.notes[resource.id]!;
      expect(notes.map((n) => n.content), ['hi', '']);
      expect(notes.first.timestamp.isBefore(before), isFalse);
    });

    test('falls back to the FHIR id, then a random id', () async {
      final withId = await _parseOne(conditionJson(id: 'cond-9'));
      expect(withId.resourceId, 'cond-9');

      final withoutId = await _parseOne(conditionJson()..remove('id'));
      expect(withoutId.resourceId, matches(_uuidPattern));
    });

    group('titles', () {
      final cases = <(String, Map<String, dynamic>, String)>[
        ('Encounter coding display', encounterJson(), 'Encounter for check up'),
        (
          'Encounter type text',
          {
            ...encounterJson(),
            'type': [codeableConcept(text: 'Telehealth')],
          },
          'Telehealth',
        ),
        (
          'Encounter coding without display',
          {
            ...encounterJson(),
            'type': [
              codeableConcept(
                text: 'Telehealth',
                codings: [coding(snomedSystem, '1')],
              ),
            ],
          },
          'Telehealth',
        ),
        (
          'Encounter type without text or coding',
          {
            ...encounterJson(),
            'type': [<String, dynamic>{}],
          },
          '',
        ),
        (
          'Encounter without type',
          encounterJson()..remove('type'),
          '',
        ),
        ('Observation', observationJson(), 'Hemoglobin [Mass/volume] in Blood'),
        (
          'Observation text only',
          {...observationJson(), 'code': codeableConcept(text: 'Glucose')},
          'Glucose',
        ),
        (
          'Observation without readable code',
          {...observationJson(), 'code': <String, dynamic>{}},
          '',
        ),
        ('Condition', conditionJson(), 'Diabetes mellitus type 2'),
        ('Procedure', procedureJson(), 'Colonoscopy'),
        (
          'Immunization',
          immunizationJson(),
          'Influenza, seasonal, injectable, preservative free',
        ),
        (
          'MedicationRequest',
          medicationRequestJson(),
          'metformin hydrochloride 500 MG Oral Tablet',
        ),
        (
          'MedicationRequest by reference',
          {
            ...medicationRequestJson()..remove('medicationCodeableConcept'),
            'medicationReference': {'reference': 'Medication/med-1'},
          },
          '',
        ),
        (
          'DiagnosticReport',
          diagnosticReportJson(),
          'CBC panel - Blood by Automated count',
        ),
        (
          'VisionPrescription lens product text',
          {
            ...visionPrescriptionJson(),
            'lensSpecification': [
              {
                'product': codeableConcept(text: 'Progressive lenses'),
                'eye': 'right',
              },
            ],
          },
          'Progressive lenses',
        ),
        // The coded lens type is not the title the document printed.
        (
          'VisionPrescription lens product without text',
          visionPrescriptionJson(),
          '',
        ),
        // No title of its own: the record names itself (displayTitle).
        ('other types', allergyJson(), ''),
      ];
      for (final (name, json, expected) in cases) {
        test('$name -> $expected', () async {
          expect((await _parseOne(json)).title, expected);
        });
      }

      test(
        'uses code.text when the coding has no display',
        () async {
          final resource = await _parseOne({
            ...observationJson(),
            'code': codeableConcept(
              text: 'Glucose',
              codings: [loinc('2339-0')],
            ),
          });
          expect(resource.title, 'Glucose');
        },
      );

      test('a received allergy is named by its substance', () async {
        final resource = await _parseOne(allergyJson());
        expect(resource.displayTitle, isNot('AllergyIntolerance'));
        expect(resource.displayTitle, isNotEmpty);
      });
    });

    group('dates', () {
      final cases = <(String, Map<String, dynamic>, DateTime?)>[
        (
          'Encounter period.start',
          encounterJson(),
          DateTime.utc(2024, 1, 10, 9),
        ),
        (
          'Observation effectiveDateTime',
          observationJson(),
          DateTime.utc(2024, 3, 15, 10, 30),
        ),
        (
          'Observation issued',
          observationJson(effectiveDateTime: null),
          DateTime.utc(2024, 3, 15, 12),
        ),
        (
          'Observation partial date',
          observationJson(effectiveDateTime: '2024-03'),
          null,
        ),
        ('Condition onset', conditionJson(), DateTime(2019, 2, 1)),
        (
          'Condition recordedDate',
          conditionJson(onset: const {'onsetString': 'childhood'}),
          DateTime(2019, 2, 3),
        ),
        (
          'Procedure performedPeriod',
          procedureJson(),
          DateTime.utc(2022, 5, 4, 8),
        ),
        (
          'Procedure performedDateTime',
          {
            ...procedureJson()..remove('performedPeriod'),
            'performedDateTime': '2022-05-05',
          },
          DateTime(2022, 5, 5),
        ),
        ('Immunization', immunizationJson(), DateTime.utc(2023, 10, 1, 8)),
        (
          'MedicationRequest',
          medicationRequestJson(),
          DateTime.utc(2024, 1, 10, 9, 20),
        ),
        (
          'DiagnosticReport',
          diagnosticReportJson(),
          DateTime.utc(2024, 3, 15, 10, 30),
        ),
        (
          'DiagnosticReport issued',
          diagnosticReportJson()..remove('effectiveDateTime'),
          DateTime.utc(2024, 3, 15, 12),
        ),
        (
          'DocumentReference date',
          documentReferenceJson(),
          DateTime.utc(2024, 2, 2, 14),
        ),
        (
          'VisionPrescription dateWritten',
          {...visionPrescriptionJson(), 'dateWritten': '2024-03-15'},
          DateTime(2024, 3, 15),
        ),
        (
          'VisionPrescription created',
          visionPrescriptionJson()..remove('dateWritten'),
          DateTime(2024, 3, 14),
        ),
        ('AllergyIntolerance recordedDate', allergyJson(), DateTime(2015, 6)),
        (
          'Organization without date',
          minimalResources()['Organization']!,
          null,
        ),
      ];
      for (final (name, json, expected) in cases) {
        test('$name -> $expected', () async {
          expect((await _parseOne(json)).date, expected);
        });
      }
    });

    group('references', () {
      test('read encounter from DocumentReference.context', () async {
        final doc = await _parseOne(
          documentReferenceJson(
            context: {
              'encounter': [
                {'reference': 'Encounter/enc-9'},
              ],
            },
          ),
        );
        expect(doc.encounterId, 'enc-9');
        expect(doc.subjectId, 'pat-1');
      });

      test('context without encounter leaves the encounter empty', () async {
        final doc = await _parseOne(
          documentReferenceJson(
            context: {
              'period': {'start': '2024-01-01'},
            },
          ),
        );
        expect(doc.encounterId, '');
      });

      final referenceCases = <(String, String)>[
        ('Patient/pat-7', 'pat-7'),
        ('https://fhir.example.org/r4/Patient/pat-7', 'pat-7'),
        (
          'urn:uuid:8f0e9c1a-3c2b-4d4e-9a8b-7c6d5e4f3a2b',
          '8f0e9c1a-3c2b-4d4e-9a8b-7c6d5e4f3a2b',
        ),
        ('#contained-1', 'contained-1'),
        ('pat-7', 'pat-7'),
      ];
      for (final (reference, expected) in referenceCases) {
        test('subject $reference -> $expected', () async {
          final resource = await _parseOne({
            ...conditionJson(),
            'subject': {'reference': reference},
          });
          expect(resource.subjectId, expected);
        });
      }

      test(
        'versioned references resolve to the resource id',
        () async {
          final resource = await _parseOne({
            ...conditionJson(),
            'subject': {'reference': 'Patient/pat-7/_history/3'},
          });
          expect(resource.subjectId, 'pat-7');
        },
        skip: 'BUG: "Patient/pat-7/_history/3" yields the version id "3"',
      );

      test(
        'an empty context.encounter does not drop the document',
        () async {
          final result = await _parse([
            {
              'resource': documentReferenceJson(context: {'encounter': []}),
            },
          ]);
          expect(result.resources, hasLength(1));
        },
        skip:
            'BUG: falls through to `context["encounter"]?["reference"]` on a '
            'List, which throws, so the shared document is silently dropped',
      );
    });

    group('attachments', () {
      late Directory tempDir;
      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('hw_bundle_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
      });

      Map<String, dynamic> docWithData(
        List<Map<String, dynamic>> attachments,
      ) => documentReferenceJson(attachments: attachments);

      test('writes embedded data to the temp dir and links it', () async {
        final result = await _parse([
          {
            'resource': docWithData([
              {
                'contentType': 'application/pdf',
                'title': 'Lab report (1).pdf',
                'data': base64Encode(utf8.encode('%PDF')),
              },
              {
                'contentType': 'text/plain',
                'data': base64Encode(utf8.encode('note')),
              },
              {'contentType': 'text/plain', 'url': 'https://example.org/x'},
            ]),
          },
        ], tempDir: tempDir.path);

        final doc = result.resources.single;
        expect(result.tempFilePaths, hasLength(2));

        final first = _attachment(doc);
        expect(first['url'], 'file://${tempDir.path}/Lab_report__1_.pdf');
        expect(first.containsKey('data'), isFalse);
        expect(
          File('${tempDir.path}/Lab_report__1_.pdf').readAsStringSync(),
          '%PDF',
        );

        final second = _attachment(doc, 1);
        expect(
          second['url'],
          matches(RegExp(r'^file://.*/[0-9a-f-]{36}\.bin$')),
        );
        expect(File(result.tempFilePaths[1]).readAsStringSync(), 'note');

        expect(_attachment(doc, 2)['url'], 'https://example.org/x');
      });

      test('sanitises titles so files stay inside the temp dir', () async {
        final result = await _parse([
          {
            'resource': docWithData([
              {
                'title': '../../etc/passwd',
                'data': base64Encode([0]),
              },
            ]),
          },
        ], tempDir: tempDir.path);

        expect(result.tempFilePaths.single, '${tempDir.path}/.._.._etc_passwd');
        expect(File(result.tempFilePaths.single).existsSync(), isTrue);
      });

      test('keeps embedded data when no temp dir is given', () async {
        final result = await _parse([
          {
            'resource': docWithData([
              {
                'title': 'a.pdf',
                'data': base64Encode([1, 2]),
              },
            ]),
          },
        ]);
        expect(result.tempFilePaths, isEmpty);
        expect(_attachment(result.resources.single)['data'], 'AQI=');
      });

      test('drops a document whose data is not valid base64', () async {
        final result = await _parse([
          {
            'resource': docWithData([
              {'title': 'a.pdf', 'data': '%%%not-base64'},
            ]),
          },
          {'resource': conditionJson()},
        ], tempDir: tempDir.path);
        expect(result.resources.single.fhirType, FhirType.Condition);
      });

      test('writes nothing for DocumentReferences without content', () async {
        final result = await _parse([
          {'resource': documentReferenceJson()..remove('content')},
        ], tempDir: tempDir.path);
        expect(result.tempFilePaths, isEmpty);
        // content is required in R4, so the FHIR parser rejects it.
        expect(result.resources, isEmpty);
        expect(tempDir.listSync(), isEmpty);
      });
    });

    test(
      'one malformed entry does not discard the whole bundle',
      () async {
        final result = await _parse([
          {'resource': 'not a map'},
          {'resource': conditionJson()},
        ]);
        expect(result.resources, hasLength(1));
      },
      skip:
          'BUG: the `entry["resource"] as Map` cast is outside the try, so '
          'one bad entry throws and the receiver discards the whole share',
    );
  });

  group('estimatePayloadSize', () {
    test('adds a fixed envelope to the raw resource sizes', () {
      expect(FhirBundleMapper.estimatePayloadSize(const []), 500);
      final condition = record(conditionJson());
      expect(
        FhirBundleMapper.estimatePayloadSize([condition, condition]),
        condition.rawResource.toString().length * 2 + 500,
      );
    });
  });
}

/// Wraps a record but exposes a hand-crafted raw resource, for shapes the
/// FHIR parser would reject.
class _RawOnly implements IFhirResource {
  _RawOnly(this._inner, this.rawResource);

  final IFhirResource _inner;

  @override
  final Map<String, dynamic> rawResource;

  @override
  String get id => _inner.id;

  @override
  String get resourceId => _inner.resourceId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
