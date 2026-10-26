// Realistic FHIR R4 JSON fixtures shared by the records and share_records
// tests. Every builder returns a fresh, mutable map so tests can tweak fields
// without leaking state into other tests.

const String loincSystem = 'http://loinc.org';
const String snomedSystem = 'http://snomed.info/sct';
const String ucumSystem = 'http://unitsofmeasure.org';
const String identifierTypeSystem =
    'http://terminology.hl7.org/CodeSystem/v2-0203';
const String usCoreRaceUrl =
    'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race';
const String usCoreEthnicityUrl =
    'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity';
const String usCoreBirthSexUrl =
    'http://hl7.org/fhir/us/core/StructureDefinition/us-core-birthsex';
const String birthPlaceUrl =
    'http://hl7.org/fhir/StructureDefinition/patient-birthPlace';

Map<String, dynamic> coding(String system, String code, [String? display]) => {
  'system': system,
  'code': code,
  'display': ?display,
};

Map<String, dynamic> loinc(String code, [String? display]) =>
    coding(loincSystem, code, display);

Map<String, dynamic> codeableConcept({
  String? text,
  List<Map<String, dynamic>> codings = const [],
}) => {
  'text': ?text,
  if (codings.isNotEmpty) 'coding': codings,
};

Map<String, dynamic> quantity(num? value, {String? unit, String? code}) => {
  'value': ?value,
  'unit': ?unit,
  if (code != null) 'system': ucumSystem,
  'code': ?code,
};

Map<String, dynamic> identifier({
  required String value,
  String? typeCode,
  String? typeDisplay,
  String? typeText,
  String? system,
}) => {
  'system': ?system,
  if (typeCode != null || typeText != null)
    'type': {
      'text': ?typeText,
      if (typeCode != null)
        'coding': [coding(identifierTypeSystem, typeCode, typeDisplay)],
    },
  'value': value,
};

/// A Synthea-style US patient with the US Core race/ethnicity extensions.
Map<String, dynamic> patientJson({
  String id = 'pat-1',
  String? birthDate = '1985-07-14',
  List<Map<String, dynamic>>? identifiers,
  List<Map<String, dynamic>>? names,
  String? gender = 'female',
}) => {
  'resourceType': 'Patient',
  'id': id,
  'extension': [
    {
      'url': usCoreRaceUrl,
      'extension': [
        {
          'url': 'ombCategory',
          'valueCoding': coding(
            'urn:oid:2.16.840.1.113883.6.238',
            '2106-3',
            'White',
          ),
        },
        {'url': 'text', 'valueString': 'White'},
      ],
    },
    {
      'url': usCoreEthnicityUrl,
      'extension': [
        {
          'url': 'ombCategory',
          'valueCoding': coding(
            'urn:oid:2.16.840.1.113883.6.238',
            '2186-5',
            'Not Hispanic or Latino',
          ),
        },
      ],
    },
    {'url': usCoreBirthSexUrl, 'valueCode': 'F'},
    {
      'url': birthPlaceUrl,
      'valueAddress': {
        'city': 'Boston',
        'state': 'Massachusetts',
        'country': 'US',
      },
    },
  ],
  'identifier':
      identifiers ??
      [
        {
          'system': 'https://github.com/synthetichealth/synthea',
          'value': 'syn-1',
        },
        identifier(
          value: 'MRN-0042',
          typeCode: 'MR',
          typeDisplay: 'Medical Record Number',
          typeText: 'Medical Record Number',
          system: 'http://hospital.smarthealthit.org',
        ),
      ],
  'name':
      names ??
      [
        {
          'use': 'official',
          'family': 'Doe',
          'given': ['Jane', 'Marie'],
          'prefix': ['Mrs.'],
        },
      ],
  'telecom': [
    {'system': 'phone', 'value': '555-0100', 'use': 'home'},
    {'system': 'phone', 'value': '555-0199', 'use': 'mobile'},
    {'system': 'email', 'value': 'jane@example.org'},
  ],
  'gender': ?gender,
  'birthDate': ?birthDate,
  'address': [
    {
      'line': ['12 Main St', 'Apt 3'],
      'city': 'Springfield',
      'state': 'MA',
      'postalCode': '01101',
      'country': 'US',
    },
  ],
  'communication': [
    {
      'language': codeableConcept(
        text: 'English',
        codings: [coding('urn:ietf:bcp:47', 'en-US', 'English (US)')],
      ),
    },
    {
      'language': codeableConcept(
        codings: [coding('urn:ietf:bcp:47', 'es', 'Spanish')],
      ),
    },
  ],
};

/// Observation with a LOINC code and the given `value[x]` entry.
Map<String, dynamic> observationJson({
  String id = 'obs-1',
  String code = '718-7',
  String? codeDisplay = 'Hemoglobin [Mass/volume] in Blood',
  String? codeText,
  Map<String, dynamic> value = const {},
  String? effectiveDateTime = '2024-03-15T10:30:00Z',
  List<Map<String, dynamic>>? components,
  List<Map<String, dynamic>>? interpretation,
}) => {
  'resourceType': 'Observation',
  'id': id,
  'status': 'final',
  'category': [
    codeableConcept(
      codings: [
        coding(
          'http://terminology.hl7.org/CodeSystem/observation-category',
          'laboratory',
          'Laboratory',
        ),
      ],
    ),
  ],
  'code': codeableConcept(text: codeText, codings: [loinc(code, codeDisplay)]),
  'subject': {'reference': 'Patient/pat-1'},
  'encounter': {'reference': 'Encounter/enc-1'},
  'effectiveDateTime': ?effectiveDateTime,
  'issued': '2024-03-15T12:00:00.000Z',
  ...value,
  'component': ?components,
  'interpretation': ?interpretation,
};

/// Blood pressure panel with systolic/diastolic components and no value[x].
Map<String, dynamic> bloodPressureJson() => observationJson(
  id: 'bp-1',
  code: '85354-9',
  codeDisplay: 'Blood pressure panel with all children optional',
  components: [
    {
      'code': codeableConcept(codings: [loinc('8480-6', 'Systolic')]),
      'valueQuantity': quantity(128, unit: 'mmHg', code: 'mm[Hg]'),
    },
    {
      'code': codeableConcept(codings: [loinc('8462-4', 'Diastolic')]),
      'valueQuantity': quantity(82, unit: 'mmHg', code: 'mm[Hg]'),
    },
  ],
);

Map<String, dynamic> conditionJson({
  String id = 'cond-1',
  Map<String, dynamic> onset = const {'onsetDateTime': '2019-02-01'},
  Map<String, dynamic> abatement = const {},
}) => {
  'resourceType': 'Condition',
  'id': id,
  'clinicalStatus': codeableConcept(
    codings: [
      coding(
        'http://terminology.hl7.org/CodeSystem/condition-clinical',
        'active',
      ),
    ],
  ),
  'code': codeableConcept(
    text: 'Type 2 diabetes mellitus',
    codings: [coding(snomedSystem, '44054006', 'Diabetes mellitus type 2')],
  ),
  'subject': {'reference': 'Patient/pat-1'},
  ...onset,
  ...abatement,
  'recordedDate': '2019-02-03',
};

Map<String, dynamic> encounterJson({String id = 'enc-1'}) => {
  'resourceType': 'Encounter',
  'id': id,
  'status': 'finished',
  'class': coding(
    'http://terminology.hl7.org/CodeSystem/v3-ActCode',
    'AMB',
    'ambulatory',
  ),
  'type': [
    codeableConcept(
      text: 'Checkup',
      codings: [coding(snomedSystem, '185349003', 'Encounter for check up')],
    ),
  ],
  'subject': {'reference': 'Patient/pat-1'},
  'participant': [
    {
      'individual': {
        'reference': 'Practitioner/pr-1',
        'display': 'Dr. Gregory House',
      },
    },
    {
      'individual': {'reference': 'Practitioner/pr-2'},
    },
  ],
  'period': {'start': '2024-01-10T09:00:00Z', 'end': '2024-01-10T09:30:00Z'},
  'diagnosis': [
    {
      'condition': {'reference': 'Condition/cond-1', 'display': 'Diabetes'},
    },
  ],
  'location': [
    {
      'location': {
        'reference': 'Location/loc-1',
        'display': 'Springfield Clinic',
      },
    },
  ],
};

Map<String, dynamic> medicationRequestJson({String id = 'medreq-1'}) => {
  'resourceType': 'MedicationRequest',
  'id': id,
  'status': 'active',
  'intent': 'order',
  'priority': 'urgent',
  'medicationCodeableConcept': codeableConcept(
    text: 'Metformin 500 MG Oral Tablet',
    codings: [
      coding(
        'http://www.nlm.nih.gov/research/umls/rxnorm',
        '860975',
        'metformin hydrochloride 500 MG Oral Tablet',
      ),
    ],
  ),
  'subject': {'reference': 'Patient/pat-1'},
  'encounter': {'reference': 'Encounter/enc-1'},
  'authoredOn': '2024-01-10T09:20:00Z',
  'dosageInstruction': [
    {
      'timing': {'code': codeableConcept(text: 'Twice a day')},
      'route': codeableConcept(
        codings: [coding(snomedSystem, '26643006', 'Oral route')],
      ),
      'doseAndRate': [
        {'doseQuantity': quantity(500, unit: 'mg', code: 'mg')},
      ],
    },
  ],
};

Map<String, dynamic> medicationStatementJson({String id = 'medstmt-1'}) => {
  'resourceType': 'MedicationStatement',
  'id': id,
  'status': 'active',
  'medicationCodeableConcept': codeableConcept(text: 'Lisinopril 10 MG'),
  'subject': {'reference': 'Patient/pat-1'},
  'dateAsserted': '2023-11-05',
  'dosage': [
    {'text': 'Take one tablet by mouth daily'},
  ],
};

Map<String, dynamic> allergyJson({String id = 'allergy-1'}) => {
  'resourceType': 'AllergyIntolerance',
  'id': id,
  'clinicalStatus': codeableConcept(
    codings: [
      coding(
        'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical',
        'active',
      ),
    ],
  ),
  'code': codeableConcept(
    codings: [coding(snomedSystem, '91936005', 'Allergy to penicillin')],
  ),
  'patient': {'reference': 'Patient/pat-1'},
  'recordedDate': '2015-06-01',
};

Map<String, dynamic> immunizationJson({String id = 'imm-1'}) => {
  'resourceType': 'Immunization',
  'id': id,
  'status': 'completed',
  'vaccineCode': codeableConcept(
    codings: [
      coding(
        'http://hl7.org/fhir/sid/cvx',
        '140',
        'Influenza, seasonal, injectable, preservative free',
      ),
    ],
  ),
  'patient': {'reference': 'Patient/pat-1'},
  'encounter': {'reference': 'Encounter/enc-1'},
  'occurrenceDateTime': '2023-10-01T08:00:00Z',
};

Map<String, dynamic> procedureJson({String id = 'proc-1'}) => {
  'resourceType': 'Procedure',
  'id': id,
  'status': 'completed',
  'code': codeableConcept(
    codings: [coding(snomedSystem, '73761001', 'Colonoscopy')],
  ),
  'subject': {'reference': 'Patient/pat-1'},
  'performedPeriod': {
    'start': '2022-05-04T08:00:00Z',
    'end': '2022-05-04T09:00:00Z',
  },
  'performer': [
    {
      'actor': {'reference': 'Practitioner/pr-1', 'display': 'Dr. Who'},
    },
  ],
};

Map<String, dynamic> diagnosticReportJson({String id = 'dr-1'}) => {
  'resourceType': 'DiagnosticReport',
  'id': id,
  'status': 'final',
  'code': codeableConcept(
    text: 'CBC panel',
    codings: [loinc('58410-2', 'CBC panel - Blood by Automated count')],
  ),
  'subject': {'reference': 'Patient/pat-1'},
  'encounter': {'reference': 'Encounter/enc-1'},
  'effectiveDateTime': '2024-03-15T10:30:00Z',
  'issued': '2024-03-15T12:00:00.000Z',
};

Map<String, dynamic> documentReferenceJson({
  String id = 'doc-1',
  List<Map<String, dynamic>>? attachments,
  Map<String, dynamic>? context,
}) => {
  'resourceType': 'DocumentReference',
  'id': id,
  'status': 'current',
  'type': codeableConcept(
    codings: [loinc('34133-9', 'Summary of episode note')],
  ),
  'subject': {'reference': 'Patient/pat-1'},
  'date': '2024-02-02T14:00:00Z',
  'content':
      (attachments ??
              [
                {'contentType': 'application/pdf', 'title': 'discharge.pdf'},
              ])
          .map((a) => {'attachment': a})
          .toList(),
  'context': ?context,
};

/// Minimal valid JSON for the less common resource types handled by the
/// entity factories.
Map<String, Map<String, dynamic>> minimalResources() => {
  'Patient': patientJson(),
  'Observation': observationJson(value: {'valueString': 'ok'}),
  'Encounter': encounterJson(),
  'Condition': conditionJson(),
  'AllergyIntolerance': allergyJson(),
  'Medication': {'resourceType': 'Medication', 'id': 'med-1'},
  'MedicationRequest': medicationRequestJson(),
  'MedicationStatement': medicationStatementJson(),
  'MedicationAdministration': {
    'resourceType': 'MedicationAdministration',
    'id': 'ma-1',
    'status': 'completed',
    'medicationCodeableConcept': codeableConcept(text: 'Aspirin'),
    'subject': {'reference': 'Patient/pat-1'},
    'effectiveDateTime': '2024-01-01T08:00:00Z',
  },
  'MedicationDispense': {
    'resourceType': 'MedicationDispense',
    'id': 'md-1',
    'status': 'completed',
    'medicationCodeableConcept': codeableConcept(text: 'Aspirin'),
  },
  'Procedure': procedureJson(),
  'DiagnosticReport': diagnosticReportJson(),
  'DocumentReference': documentReferenceJson(),
  'Immunization': immunizationJson(),
  'CareTeam': {'resourceType': 'CareTeam', 'id': 'ct-1'},
  'Goal': {
    'resourceType': 'Goal',
    'id': 'goal-1',
    'lifecycleStatus': 'active',
    'description': codeableConcept(text: 'Lose weight'),
    'subject': {'reference': 'Patient/pat-1'},
  },
  'Location': {'resourceType': 'Location', 'id': 'loc-1', 'name': 'Clinic'},
  'Organization': {
    'resourceType': 'Organization',
    'id': 'org-1',
    'name': 'General Hospital',
  },
  'Practitioner': {'resourceType': 'Practitioner', 'id': 'pr-1'},
  'PractitionerRole': {'resourceType': 'PractitionerRole', 'id': 'prr-1'},
  'RelatedPerson': {
    'resourceType': 'RelatedPerson',
    'id': 'rp-1',
    'patient': {'reference': 'Patient/pat-1'},
  },
  'ServiceRequest': {
    'resourceType': 'ServiceRequest',
    'id': 'sr-1',
    'status': 'active',
    'intent': 'order',
    'subject': {'reference': 'Patient/pat-1'},
  },
  'Specimen': {'resourceType': 'Specimen', 'id': 'sp-1'},
  'Binary': {
    'resourceType': 'Binary',
    'id': 'bin-1',
    'contentType': 'text/plain',
  },
  'Media': {
    'resourceType': 'Media',
    'id': 'media-1',
    'status': 'completed',
    'content': {'contentType': 'image/png'},
  },
  'AdverseEvent': {
    'resourceType': 'AdverseEvent',
    'id': 'ae-1',
    'actuality': 'actual',
    'subject': {'reference': 'Patient/pat-1'},
  },
  'Claim': {
    'resourceType': 'Claim',
    'id': 'claim-1',
    'status': 'active',
    'type': codeableConcept(text: 'professional'),
    'use': 'claim',
    'patient': {'reference': 'Patient/pat-1'},
    'created': '2024-01-11',
    'provider': {'reference': 'Organization/org-1'},
    'priority': codeableConcept(text: 'normal'),
    'insurance': [
      {
        'sequence': 1,
        'focal': true,
        'coverage': {'reference': 'Coverage/cov-1'},
      },
    ],
  },
  'ExplanationOfBenefit': {
    'resourceType': 'ExplanationOfBenefit',
    'id': 'eob-1',
    'status': 'active',
    'type': codeableConcept(text: 'professional'),
    'use': 'claim',
    'patient': {'reference': 'Patient/pat-1'},
    'created': '2024-01-11',
    'insurer': {'reference': 'Organization/org-1'},
    'provider': {'reference': 'Organization/org-1'},
    'outcome': 'complete',
    'insurance': [
      {
        'focal': true,
        'coverage': {'reference': 'Coverage/cov-1'},
      },
    ],
  },
  'Coverage': {
    'resourceType': 'Coverage',
    'id': 'cov-1',
    'status': 'active',
    'beneficiary': {'reference': 'Patient/pat-1'},
    'payor': [
      {'reference': 'Organization/org-1'},
    ],
  },
};
