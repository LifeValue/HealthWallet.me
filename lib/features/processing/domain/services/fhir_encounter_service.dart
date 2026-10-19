import 'dart:convert';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';

class FhirEncounterHelper {
  static fhir_r4.Encounter createEncounter({
    required String encounterId,
    required String patientId,
    required String title,
    required String patientName,
  }) {
    final timestamp = DateTime.now();

    return fhir_r4.Encounter(
      id: fhir_r4.FhirString(encounterId),
      status: fhir_r4.EncounterStatus.finished,
      class_: fhir_r4.Coding(
        system: fhir_r4.FhirUri(
          'http://terminology.hl7.org/CodeSystem/v3-ActCode',
        ),
        code: fhir_r4.FhirCode('AMB'),
        display: fhir_r4.FhirString('ambulatory'),
      ),
      type: [
        fhir_r4.CodeableConcept(
          coding: [
            fhir_r4.Coding(
              system: fhir_r4.FhirUri('http://snomed.info/sct'),
              code: fhir_r4.FhirCode('308646001'),
              display: fhir_r4.FhirString('Document processing'),
            ),
          ],
          text: fhir_r4.FhirString(title),
        ),
      ],
      subject: fhir_r4.Reference(
        reference: fhir_r4.FhirString('Patient/$patientId'),
        display: fhir_r4.FhirString(patientName),
      ),
      period: fhir_r4.Period(
        start: fhir_r4.FhirDateTime.fromString(timestamp.toIso8601String()),
      ),
      identifier: [
        fhir_r4.Identifier(
          system: fhir_r4.FhirUri('http://healthwallet.me/encounter-id'),
          value: fhir_r4.FhirString(encounterId),
          use: fhir_r4.IdentifierUse.usual,
        ),
      ],
    );
  }

  static Future<void> saveToDatabase({
    required fhir_r4.Encounter fhirEncounter,
    required String sourceId,
    required String title,
  }) async {
    final database = GetIt.instance.get<AppDatabase>();
    final resourceJson = fhirEncounter.toJson();
    final resourceId = fhirEncounter.id!.valueString!;

    String? subjectId;
    if (fhirEncounter.subject?.reference?.valueString != null) {
      subjectId = FhirReferenceUtils.extractReferenceId(
          fhirEncounter.subject!.reference!.valueString!);
    }

    final dto = FhirResourceCompanion.insert(
      id: '${sourceId}_$resourceId',
      sourceId: Value(sourceId),
      resourceId: Value(resourceId),
      resourceType: Value('Encounter'),
      title: Value(title),
      date: Value(extractDate(fhirEncounter)),
      resourceRaw: jsonEncode(resourceJson),
      encounterId: const Value.absent(),
      subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
    );

    await database.into(database.fhirResource).insertOnConflictUpdate(dto);
  }

  static DateTime extractDate(fhir_r4.Encounter encounter) {
    if (encounter.period?.start != null) {
      try {
        return DateTime.parse(encounter.period!.start!.valueString!);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static String generateEncounterId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
