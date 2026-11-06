import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/extractors/clearvis/clearvis_io_extractor.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_organization.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor.dart';
import 'package:health_wallet/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart';
import 'package:health_wallet/features/processing/domain/services/processing_log_buffer.dart';

import '../../../../tool/extraction_bench/src/formats.dart';
import '../../../../tool/extraction_bench/src/generator.dart';
import 'clearvis_io_extractor_test.dart' show fixture;

/// A made-up layout, "ACME LAB REPORT", added the way a real one is: an
/// implementation and one registry entry, nothing else.
class _AcmeExtractor implements LayoutExtractor {
  const _AcmeExtractor({this.fixed});

  /// Forces a score, for ranking tests.
  final double? fixed;

  @override
  String get id => 'acme.test';

  @override
  int get version => 3;

  @override
  double score(String ocrText) =>
      fixed ?? (ocrText.contains('ACME LAB REPORT') ? 0.9 : 0.0);

  @override
  LayoutExtraction? extract(String ocrText) {
    final date = RegExp(r'Date: (\S+)').firstMatch(ocrText)?.group(1);
    final name = RegExp(r'Patient: (.+)').firstMatch(ocrText)?.group(1);
    if (date == null || name == null) return null;
    const clinic = 'acme';
    return LayoutExtraction(
      extractorId: id,
      version: version,
      clinicKey: clinic,
      patient: MappingPatient(familyName: MappedProperty(value: name)),
      organization: MappingOrganization(
        id: LayoutKeys.stableId(id, [clinic, 'organization']),
        organizationName: const MappedProperty(value: 'ACME'),
      ),
      encounter: MappingEncounter(
        periodStart: MappedProperty(value: date),
        identifiers: [
          LayoutKeys.visitKey(
            extractorId: id,
            clinicKey: clinic,
            patientNumber: '',
            date: date,
          ),
        ],
      ),
    );
  }
}

void main() {
  final clearvis = const ClearvisIoExtractor();

  // The pipeline log is kept out of the documents directory.
  setUpAll(
    () => ProcessingLogBuffer.debugOverrideInstance(
      ProcessingLogBuffer.forTesting(
        enabled: false,
        directory: Directory.systemTemp,
      ),
    ),
  );
  tearDownAll(() => ProcessingLogBuffer.debugOverrideInstance(null));

  group('ranking', () {
    test('the highest score at or above the threshold wins', () {
      final registry = LayoutExtractorRegistry([
        const _AcmeExtractor(fixed: 0.6),
        clearvis,
      ]);
      expect(registry.best(fixture('clearvis_exam')), clearvis);
    });

    test('a tie goes to the extractor registered first', () {
      const first = _AcmeExtractor(fixed: 0.7);
      const second = _AcmeExtractor(fixed: 0.7);
      expect(LayoutExtractorRegistry([first, second]).best('x'), same(first));
      expect(LayoutExtractorRegistry([second, first]).best('x'), same(second));
    });

    test('below the threshold nothing is chosen', () {
      const almost = _AcmeExtractor(fixed: 0.49);
      expect(LayoutExtractorRegistry([almost]).best('x'), isNull);
      const exactly = _AcmeExtractor(fixed: LayoutExtractorRegistry.threshold);
      expect(LayoutExtractorRegistry([exactly]).best('x'), exactly);
    });

    test('an empty registry recognises nothing', () {
      expect(LayoutExtractorRegistry(const []).best('anything'), isNull);
    });
  });

  test('a new layout takes part with one registration entry', () {
    final registry = LayoutExtractorRegistry([
      clearvis,
      const _AcmeExtractor(),
    ]);
    const acme = 'ACME LAB REPORT\nPatient: Doe\nDate: 2024-01-02';

    final chosen = registry.best(acme)!;
    final extraction = chosen.extract(acme)!;

    expect(chosen.id, 'acme.test');
    expect(extraction.provenance, 'acme.test@3');
    expect(
      extraction.visitKey!.system,
      'http://healthwallet.me/visit/acme.test',
    );
    expect(registry.best(fixture('clearvis_prescriptions')), clearvis);
  });

  group('no false matches', () {
    final registry = LayoutExtractorRegistry([clearvis]);

    test('on every synthetic benchmark document', () async {
      final fonts = BenchFonts.load(BenchFonts.defaultDir);
      final docs = buildDocuments(
        const GeneratorOptions(
          seed: 194,
          perCell: 2,
          langs: benchLangs,
          families: benchFamilies,
        ),
      );
      expect(docs, hasLength(benchLangs.length * benchFamilies.length * 2));
      for (final doc in docs) {
        final text = (await renderDocument(doc, fonts)).text;
        expect(
          clearvis.score(text),
          lessThan(LayoutExtractorRegistry.threshold),
          reason: doc.meta.docId,
        );
        expect(registry.best(text), isNull, reason: doc.meta.docId);
      }
    });

    test('on text with no eye-care layout', () {
      const texts = [
        '',
        'BULETIN DE ANALIZE MEDICALE\nPacient: Ion Popescu\nCNP 1800101123456\n'
            'Hemoglobina 13,5 g/dL 12 - 16\nData recoltare: 12.03.2024',
        'Scrisoare medicala\nDiagnostic: Hipertensiune arteriala\n'
            'Tratament: Enalapril 10 mg 1-0-1',
        'Entlassungsbrief\nPatient: Max Mustermann\nDiagnose: Pneumonie',
        'Discharge summary\nPatient Id: PA-01234\nDate / Date 14.03.2024',
      ];
      for (final text in texts) {
        expect(registry.best(text), isNull, reason: text);
      }
    });
  });
}
