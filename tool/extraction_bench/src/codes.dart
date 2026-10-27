/// Curated terminology and vocabulary for the synthetic documents.
///
/// Codes were picked by hand for the benchmark; they are the gold answer for
/// the concept comparator, so check them against a terminology server before
/// reusing them anywhere else. Names, addresses and organisations are
/// invented. UK and German phone numbers come from the ranges reserved for
/// drama; Spanish and Romanian ones are random digits and may exist.
library;

import 'rng.dart';

const loincSystem = 'http://loinc.org';
const snomedSystem = 'http://snomed.info/sct';
const icd10System = 'http://hl7.org/fhir/sid/icd-10';
const atcSystem = 'http://www.whocc.no/atc';
const rxnormSystem = 'http://www.nlm.nih.gov/research/umls/rxnorm';
const ucumSystem = 'http://unitsofmeasure.org';
const v20203System = 'http://terminology.hl7.org/CodeSystem/v2-0203';

/// Extension on a gold CodeableConcept listing codes that earn partial credit.
const alternativeCodingUrl =
    'https://healthwallet.me/fhir/extraction-bench/alternative-coding';

/// A string in each benchmark language.
class L4 {
  const L4(this.en, this.es, this.de, this.ro);
  const L4.all(String v) : en = v, es = v, de = v, ro = v;

  final String en;
  final String es;
  final String de;
  final String ro;

  String of(String lang) => switch (lang) {
    'en' => en,
    'es' => es,
    'de' => de,
    'ro' => ro,
    _ => throw ArgumentError.value(lang, 'lang'),
  };
}

class Code {
  const Code(this.system, this.code, this.display);
  final String system;
  final String code;
  final String display;

  Map<String, dynamic> toJson() => {
    'system': system,
    'code': code,
    'display': display,
  };
}

// ---------------------------------------------------------------------------
// Laboratory tests
// ---------------------------------------------------------------------------

class LabTest {
  const LabTest({
    required this.code,
    required this.name,
    required this.ucum,
    required this.printUnit,
    required this.low,
    required this.high,
    required this.decimals,
    this.alternatives = const [],
  });

  final Code code;
  final L4 name;
  final String ucum;
  final L4 printUnit;
  final double low;
  final double high;
  final int decimals;
  final List<Code> alternatives;
}

const labTests = <LabTest>[
  LabTest(
    code: Code(loincSystem, '718-7', 'Hemoglobin [Mass/volume] in Blood'),
    name: L4('Hemoglobin', 'Hemoglobina', 'Hämoglobin', 'Hemoglobină'),
    ucum: 'g/dL',
    printUnit: L4('g/dL', 'g/dL', 'g/dl', 'g/dL'),
    low: 12.0,
    high: 17.5,
    decimals: 1,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '4544-3',
      'Hematocrit [Volume Fraction] of Blood by Automated count',
    ),
    name: L4('Hematocrit', 'Hematocrito', 'Hämatokrit', 'Hematocrit'),
    ucum: '%',
    printUnit: L4.all('%'),
    low: 36,
    high: 52,
    decimals: 1,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '6690-2',
      'Leukocytes [#/volume] in Blood by Automated count',
    ),
    name: L4('Leukocytes', 'Leucocitos', 'Leukozyten', 'Leucocite'),
    ucum: '10*9/L',
    printUnit: L4('x10^9/L', 'x10^9/L', '10^9/l', 'x10^9/L'),
    low: 4.0,
    high: 10.0,
    decimals: 1,
    alternatives: [
      Code(loincSystem, '26464-8', 'Leukocytes [#/volume] in Blood'),
    ],
  ),
  LabTest(
    code: Code(
      loincSystem,
      '789-8',
      'Erythrocytes [#/volume] in Blood by Automated count',
    ),
    name: L4('Erythrocytes', 'Eritrocitos', 'Erythrozyten', 'Eritrocite'),
    ucum: '10*12/L',
    printUnit: L4('x10^12/L', 'x10^12/L', '10^12/l', 'x10^12/L'),
    low: 4.2,
    high: 5.9,
    decimals: 2,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '777-3',
      'Platelets [#/volume] in Blood by Automated count',
    ),
    name: L4('Platelets', 'Plaquetas', 'Thrombozyten', 'Trombocite'),
    ucum: '10*9/L',
    printUnit: L4('x10^9/L', 'x10^9/L', '10^9/l', 'x10^9/L'),
    low: 150,
    high: 400,
    decimals: 0,
    alternatives: [
      Code(loincSystem, '26515-7', 'Platelets [#/volume] in Blood'),
    ],
  ),
  LabTest(
    code: Code(loincSystem, '787-2', 'MCV [Entitic volume] by Automated count'),
    name: L4('MCV', 'VCM', 'MCV', 'VEM'),
    ucum: 'fL',
    printUnit: L4('fL', 'fL', 'fl', 'fL'),
    low: 80,
    high: 100,
    decimals: 1,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2345-7',
      'Glucose [Mass/volume] in Serum or Plasma',
    ),
    name: L4('Glucose', 'Glucosa', 'Glukose', 'Glicemie'),
    ucum: 'mg/dL',
    printUnit: L4('mg/dL', 'mg/dL', 'mg/dl', 'mg/dL'),
    low: 70,
    high: 100,
    decimals: 0,
    alternatives: [
      Code(loincSystem, '2339-0', 'Glucose [Mass/volume] in Blood'),
    ],
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2160-0',
      'Creatinine [Mass/volume] in Serum or Plasma',
    ),
    name: L4('Creatinine', 'Creatinina', 'Kreatinin', 'Creatinină'),
    ucum: 'mg/dL',
    printUnit: L4('mg/dL', 'mg/dL', 'mg/dl', 'mg/dL'),
    low: 0.6,
    high: 1.3,
    decimals: 2,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '3094-0',
      'Urea nitrogen [Mass/volume] in Serum or Plasma',
    ),
    name: L4('Urea nitrogen', 'Nitrógeno ureico', 'Harnstoff-N', 'Azot ureic'),
    ucum: 'mg/dL',
    printUnit: L4('mg/dL', 'mg/dL', 'mg/dl', 'mg/dL'),
    low: 7,
    high: 20,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2951-2',
      'Sodium [Moles/volume] in Serum or Plasma',
    ),
    name: L4('Sodium', 'Sodio', 'Natrium', 'Sodiu'),
    ucum: 'mmol/L',
    printUnit: L4('mmol/L', 'mmol/L', 'mmol/l', 'mmol/L'),
    low: 135,
    high: 145,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2823-3',
      'Potassium [Moles/volume] in Serum or Plasma',
    ),
    name: L4('Potassium', 'Potasio', 'Kalium', 'Potasiu'),
    ucum: 'mmol/L',
    printUnit: L4('mmol/L', 'mmol/L', 'mmol/l', 'mmol/L'),
    low: 3.5,
    high: 5.1,
    decimals: 1,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2093-3',
      'Cholesterol [Mass/volume] in Serum or Plasma',
    ),
    name: L4(
      'Total cholesterol',
      'Colesterol total',
      'Gesamtcholesterin',
      'Colesterol total',
    ),
    ucum: 'mg/dL',
    printUnit: L4('mg/dL', 'mg/dL', 'mg/dl', 'mg/dL'),
    low: 125,
    high: 200,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2085-9',
      'Cholesterol in HDL [Mass/volume] in Serum or Plasma',
    ),
    name: L4(
      'HDL cholesterol',
      'Colesterol HDL',
      'HDL-Cholesterin',
      'HDL colesterol',
    ),
    ucum: 'mg/dL',
    printUnit: L4('mg/dL', 'mg/dL', 'mg/dl', 'mg/dL'),
    low: 40,
    high: 60,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '13457-7',
      'Cholesterol in LDL [Mass/volume] in Serum or Plasma by calculation',
    ),
    name: L4(
      'LDL cholesterol',
      'Colesterol LDL',
      'LDL-Cholesterin',
      'LDL colesterol',
    ),
    ucum: 'mg/dL',
    printUnit: L4('mg/dL', 'mg/dL', 'mg/dl', 'mg/dL'),
    low: 50,
    high: 130,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2571-8',
      'Triglyceride [Mass/volume] in Serum or Plasma',
    ),
    name: L4('Triglycerides', 'Triglicéridos', 'Triglyceride', 'Trigliceride'),
    ucum: 'mg/dL',
    printUnit: L4('mg/dL', 'mg/dL', 'mg/dl', 'mg/dL'),
    low: 50,
    high: 150,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '1742-6',
      'Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma',
    ),
    name: L4('ALT', 'ALT (GPT)', 'ALT (GPT)', 'ALT (TGP)'),
    ucum: 'U/L',
    printUnit: L4('U/L', 'U/L', 'U/l', 'U/L'),
    low: 7,
    high: 56,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '1920-8',
      'Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma',
    ),
    name: L4('AST', 'AST (GOT)', 'AST (GOT)', 'AST (TGO)'),
    ucum: 'U/L',
    printUnit: L4('U/L', 'U/L', 'U/l', 'U/L'),
    low: 10,
    high: 40,
    decimals: 0,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '4548-4',
      'Hemoglobin A1c/Hemoglobin.total in Blood',
    ),
    name: L4('HbA1c', 'HbA1c', 'HbA1c', 'HbA1c'),
    ucum: '%',
    printUnit: L4.all('%'),
    low: 4.0,
    high: 5.6,
    decimals: 1,
    alternatives: [
      Code(
        loincSystem,
        '17856-6',
        'Hemoglobin A1c/Hemoglobin.total in Blood by HPLC',
      ),
    ],
  ),
  LabTest(
    code: Code(
      loincSystem,
      '3016-3',
      'Thyrotropin [Units/volume] in Serum or Plasma',
    ),
    name: L4('TSH', 'TSH', 'TSH', 'TSH'),
    ucum: 'm[IU]/L',
    printUnit: L4('mIU/L', 'mUI/L', 'mU/l', 'mUI/L'),
    low: 0.4,
    high: 4.0,
    decimals: 2,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '1988-5',
      'C reactive protein [Mass/volume] in Serum or Plasma',
    ),
    name: L4(
      'C-reactive protein',
      'Proteína C reactiva',
      'C-reaktives Protein',
      'Proteina C reactivă',
    ),
    ucum: 'mg/L',
    printUnit: L4('mg/L', 'mg/L', 'mg/l', 'mg/L'),
    low: 0,
    high: 5,
    decimals: 1,
  ),
  LabTest(
    code: Code(
      loincSystem,
      '2276-4',
      'Ferritin [Mass/volume] in Serum or Plasma',
    ),
    name: L4('Ferritin', 'Ferritina', 'Ferritin', 'Feritină'),
    ucum: 'ng/mL',
    printUnit: L4('ng/mL', 'ng/mL', 'ng/ml', 'ng/mL'),
    low: 30,
    high: 400,
    decimals: 0,
  ),
];

const labReportCode = Code(loincSystem, '11502-2', 'Laboratory report');

// ---------------------------------------------------------------------------
// Vital signs (printed on discharge letters)
// ---------------------------------------------------------------------------

class VitalSign {
  const VitalSign({
    required this.codes,
    required this.name,
    required this.ucum,
    required this.printUnit,
    required this.low,
    required this.high,
    required this.decimals,
  });

  /// Equivalent codings; any one of them earns full credit.
  final List<Code> codes;
  final L4 name;
  final String ucum;
  final L4 printUnit;
  final double low;
  final double high;
  final int decimals;
}

const vitalSigns = <VitalSign>[
  VitalSign(
    codes: [Code(loincSystem, '8867-4', 'Heart rate')],
    name: L4(
      'Heart rate',
      'Frecuencia cardíaca',
      'Herzfrequenz',
      'Frecvență cardiacă',
    ),
    ucum: '/min',
    printUnit: L4('bpm', '/min', '/min', 'bpm'),
    low: 58,
    high: 104,
    decimals: 0,
  ),
  VitalSign(
    codes: [Code(loincSystem, '8310-5', 'Body temperature')],
    name: L4('Temperature', 'Temperatura', 'Körpertemperatur', 'Temperatură'),
    ucum: 'Cel',
    printUnit: L4.all('°C'),
    low: 36.0,
    high: 38.6,
    decimals: 1,
  ),
  VitalSign(
    codes: [Code(loincSystem, '29463-7', 'Body weight')],
    name: L4('Weight', 'Peso', 'Körpergewicht', 'Greutate'),
    ucum: 'kg',
    printUnit: L4.all('kg'),
    low: 52,
    high: 112,
    decimals: 0,
  ),
  VitalSign(
    codes: [Code(loincSystem, '8302-2', 'Body height')],
    name: L4('Height', 'Talla', 'Körpergröße', 'Înălțime'),
    ucum: 'cm',
    printUnit: L4.all('cm'),
    low: 152,
    high: 194,
    decimals: 0,
  ),
  VitalSign(
    codes: [
      Code(
        loincSystem,
        '59408-5',
        'Oxygen saturation in Arterial blood by Pulse oximetry',
      ),
      Code(loincSystem, '2708-6', 'Oxygen saturation in Arterial blood'),
    ],
    name: L4(
      'Oxygen saturation (SpO2)',
      'Saturación de oxígeno (SpO2)',
      'Sauerstoffsättigung (SpO2)',
      'Saturație oxigen (SpO2)',
    ),
    ucum: '%',
    printUnit: L4.all('%'),
    low: 91,
    high: 99,
    decimals: 0,
  ),
  VitalSign(
    codes: [Code(loincSystem, '9279-1', 'Respiratory rate')],
    name: L4(
      'Respiratory rate',
      'Frecuencia respiratoria',
      'Atemfrequenz',
      'Frecvență respiratorie',
    ),
    ucum: '/min',
    printUnit: L4.all('/min'),
    low: 12,
    high: 22,
    decimals: 0,
  ),
];

// ---------------------------------------------------------------------------
// Specialties (Encounter.serviceType); codes match lib's MedicalSpecialty
// ---------------------------------------------------------------------------

class Specialty {
  const Specialty(this.key, this.code, this.name);
  final String key;
  final Code code;
  final L4 name;
}

const specialties = <String, Specialty>{
  'cardiology': Specialty(
    'cardiology',
    Code(snomedSystem, '394579002', 'Cardiology'),
    L4('Cardiology', 'Cardiología', 'Kardiologie', 'Cardiologie'),
  ),
  'endocrinology': Specialty(
    'endocrinology',
    Code(snomedSystem, '394583002', 'Endocrinology'),
    L4('Endocrinology', 'Endocrinología', 'Endokrinologie', 'Endocrinologie'),
  ),
  'gastroenterology': Specialty(
    'gastroenterology',
    Code(snomedSystem, '394584008', 'Gastroenterology'),
    L4(
      'Gastroenterology',
      'Gastroenterología',
      'Gastroenterologie',
      'Gastroenterologie',
    ),
  ),
  'nephrology': Specialty(
    'nephrology',
    Code(snomedSystem, '394589003', 'Nephrology'),
    L4('Nephrology', 'Nefrología', 'Nephrologie', 'Nefrologie'),
  ),
  'neurology': Specialty(
    'neurology',
    Code(snomedSystem, '394591006', 'Neurology'),
    L4('Neurology', 'Neurología', 'Neurologie', 'Neurologie'),
  ),
  'pulmonology': Specialty(
    'pulmonology',
    Code(snomedSystem, '418112009', 'Pulmonary medicine'),
    L4('Pulmonology', 'Neumología', 'Pneumologie', 'Pneumologie'),
  ),
  'orthopedics': Specialty(
    'orthopedics',
    Code(snomedSystem, '394801008', 'Trauma and orthopedics'),
    L4('Orthopedics', 'Traumatología', 'Orthopädie', 'Ortopedie'),
  ),
};

const labMedicine = L4(
  'Laboratory medicine',
  'Análisis clínicos',
  'Laboratoriumsmedizin',
  'Medicină de laborator',
);

// ---------------------------------------------------------------------------
// Conditions
// ---------------------------------------------------------------------------

class ConditionDef {
  const ConditionDef({
    required this.snomed,
    required this.icd10,
    required this.name,
    required this.specialty,
    this.alternatives = const [],
  });

  final Code snomed;
  final Code icd10;
  final L4 name;
  final String specialty;

  /// Broader codes that earn partial credit.
  final List<Code> alternatives;
}

const conditions = <ConditionDef>[
  ConditionDef(
    snomed: Code(snomedSystem, '44054006', 'Diabetes mellitus type 2'),
    icd10: Code(
      icd10System,
      'E11.9',
      'Type 2 diabetes mellitus without complications',
    ),
    name: L4(
      'Type 2 diabetes mellitus',
      'Diabetes mellitus tipo 2',
      'Diabetes mellitus Typ 2',
      'Diabet zaharat tip 2',
    ),
    specialty: 'endocrinology',
    alternatives: [Code(icd10System, 'E11', 'Type 2 diabetes mellitus')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '59621000', 'Essential hypertension'),
    icd10: Code(icd10System, 'I10', 'Essential (primary) hypertension'),
    name: L4(
      'Essential hypertension',
      'Hipertensión arterial esencial',
      'Essentielle Hypertonie',
      'Hipertensiune arterială esențială',
    ),
    specialty: 'cardiology',
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '49436004', 'Atrial fibrillation'),
    icd10: Code(
      icd10System,
      'I48.9',
      'Atrial fibrillation and atrial flutter, unspecified',
    ),
    name: L4(
      'Atrial fibrillation',
      'Fibrilación auricular',
      'Vorhofflimmern',
      'Fibrilație atrială',
    ),
    specialty: 'cardiology',
    alternatives: [Code(icd10System, 'I48', 'Atrial fibrillation and flutter')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '84114007', 'Heart failure'),
    icd10: Code(icd10System, 'I50.9', 'Heart failure, unspecified'),
    name: L4(
      'Heart failure',
      'Insuficiencia cardíaca',
      'Herzinsuffizienz',
      'Insuficiență cardiacă',
    ),
    specialty: 'cardiology',
    alternatives: [Code(icd10System, 'I50', 'Heart failure')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '57054005', 'Acute myocardial infarction'),
    icd10: Code(
      icd10System,
      'I21.9',
      'Acute myocardial infarction, unspecified',
    ),
    name: L4(
      'Acute myocardial infarction',
      'Infarto agudo de miocardio',
      'Akuter Myokardinfarkt',
      'Infarct miocardic acut',
    ),
    specialty: 'cardiology',
    alternatives: [Code(icd10System, 'I21', 'Acute myocardial infarction')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '385093006', 'Community acquired pneumonia'),
    icd10: Code(icd10System, 'J18.9', 'Pneumonia, unspecified'),
    name: L4(
      'Community-acquired pneumonia',
      'Neumonía adquirida en la comunidad',
      'Ambulant erworbene Pneumonie',
      'Pneumonie comunitară',
    ),
    specialty: 'pulmonology',
    alternatives: [Code(icd10System, 'J18', 'Pneumonia, organism unspecified')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '13645005', 'Chronic obstructive lung disease'),
    icd10: Code(
      icd10System,
      'J44.9',
      'Chronic obstructive pulmonary disease, unspecified',
    ),
    name: L4(
      'Chronic obstructive pulmonary disease',
      'Enfermedad pulmonar obstructiva crónica',
      'Chronisch obstruktive Lungenerkrankung',
      'Bronhopneumopatie obstructivă cronică',
    ),
    specialty: 'pulmonology',
    alternatives: [
      Code(icd10System, 'J44', 'Other chronic obstructive pulmonary disease'),
    ],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '195967001', 'Asthma'),
    icd10: Code(icd10System, 'J45.9', 'Asthma, unspecified'),
    name: L4('Asthma', 'Asma bronquial', 'Asthma bronchiale', 'Astm bronșic'),
    specialty: 'pulmonology',
    alternatives: [Code(icd10System, 'J45', 'Asthma')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '433144002', 'Chronic kidney disease stage 3'),
    icd10: Code(icd10System, 'N18.3', 'Chronic kidney disease, stage 3'),
    name: L4(
      'Chronic kidney disease stage 3',
      'Enfermedad renal crónica estadio 3',
      'Chronische Nierenkrankheit Stadium 3',
      'Boală cronică de rinichi stadiul 3',
    ),
    specialty: 'nephrology',
    alternatives: [Code(icd10System, 'N18', 'Chronic kidney disease')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '68566005', 'Urinary tract infectious disease'),
    icd10: Code(
      icd10System,
      'N39.0',
      'Urinary tract infection, site not specified',
    ),
    name: L4(
      'Urinary tract infection',
      'Infección del tracto urinario',
      'Harnwegsinfektion',
      'Infecție de tract urinar',
    ),
    specialty: 'nephrology',
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '40930008', 'Hypothyroidism'),
    icd10: Code(icd10System, 'E03.9', 'Hypothyroidism, unspecified'),
    name: L4(
      'Hypothyroidism',
      'Hipotiroidismo',
      'Hypothyreose',
      'Hipotiroidism',
    ),
    specialty: 'endocrinology',
    alternatives: [Code(icd10System, 'E03', 'Other hypothyroidism')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '55822004', 'Hyperlipidemia'),
    icd10: Code(icd10System, 'E78.5', 'Hyperlipidaemia, unspecified'),
    name: L4(
      'Hyperlipidemia',
      'Hiperlipidemia',
      'Hyperlipidämie',
      'Hiperlipidemie',
    ),
    specialty: 'cardiology',
    alternatives: [
      Code(
        icd10System,
        'E78',
        'Disorders of lipoprotein metabolism and other lipidaemias',
      ),
    ],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '87522002', 'Iron deficiency anemia'),
    icd10: Code(icd10System, 'D50.9', 'Iron deficiency anaemia, unspecified'),
    name: L4(
      'Iron deficiency anemia',
      'Anemia ferropénica',
      'Eisenmangelanämie',
      'Anemie feriprivă',
    ),
    specialty: 'gastroenterology',
    alternatives: [Code(icd10System, 'D50', 'Iron deficiency anaemia')],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '235595009', 'Gastroesophageal reflux disease'),
    icd10: Code(
      icd10System,
      'K21.9',
      'Gastro-oesophageal reflux disease without oesophagitis',
    ),
    name: L4(
      'Gastroesophageal reflux disease',
      'Enfermedad por reflujo gastroesofágico',
      'Gastroösophageale Refluxkrankheit',
      'Boală de reflux gastroesofagian',
    ),
    specialty: 'gastroenterology',
    alternatives: [
      Code(icd10System, 'K21', 'Gastro-oesophageal reflux disease'),
    ],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '239873007', 'Osteoarthritis of knee'),
    icd10: Code(icd10System, 'M17.9', 'Gonarthrosis, unspecified'),
    name: L4(
      'Osteoarthritis of the knee',
      'Artrosis de rodilla',
      'Gonarthrose',
      'Gonartroză',
    ),
    specialty: 'orthopedics',
    alternatives: [
      Code(icd10System, 'M17', 'Gonarthrosis [arthrosis of knee]'),
    ],
  ),
  ConditionDef(
    snomed: Code(snomedSystem, '422504002', 'Ischemic stroke'),
    icd10: Code(icd10System, 'I63.9', 'Cerebral infarction, unspecified'),
    name: L4(
      'Ischemic stroke',
      'Ictus isquémico',
      'Ischämischer Schlaganfall',
      'Accident vascular cerebral ischemic',
    ),
    specialty: 'neurology',
    alternatives: [Code(icd10System, 'I63', 'Cerebral infarction')],
  ),
];

// ---------------------------------------------------------------------------
// Medications
// ---------------------------------------------------------------------------

enum DoseForm { tablet, inhaler, injection }

class Strength {
  const Strength(this.value, this.unit);
  final num value;
  final String unit;
}

class MedicationDef {
  const MedicationDef({
    required this.atc,
    required this.rxnorm,
    required this.name,
    required this.strengths,
    this.form = DoseForm.tablet,
    this.alternatives = const [],
  });

  final Code atc;

  /// RxNorm ingredient.
  final Code rxnorm;
  final L4 name;
  final List<Strength> strengths;
  final DoseForm form;

  /// The ATC chemical subgroup; partial credit.
  final List<Code> alternatives;
}

const medications = <MedicationDef>[
  MedicationDef(
    atc: Code(atcSystem, 'A10BA02', 'metformin'),
    rxnorm: Code(rxnormSystem, '6809', 'metformin'),
    name: L4('Metformin', 'Metformina', 'Metformin', 'Metformină'),
    strengths: [Strength(850, 'mg'), Strength(1000, 'mg')],
    alternatives: [Code(atcSystem, 'A10BA', 'Biguanides')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'C09AA05', 'ramipril'),
    rxnorm: Code(rxnormSystem, '35296', 'ramipril'),
    name: L4('Ramipril', 'Ramipril', 'Ramipril', 'Ramipril'),
    strengths: [Strength(2.5, 'mg'), Strength(5, 'mg')],
    alternatives: [Code(atcSystem, 'C09AA', 'ACE inhibitors, plain')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'C09AA02', 'enalapril'),
    rxnorm: Code(rxnormSystem, '3827', 'enalapril'),
    name: L4('Enalapril', 'Enalapril', 'Enalapril', 'Enalapril'),
    strengths: [Strength(10, 'mg'), Strength(20, 'mg')],
    alternatives: [Code(atcSystem, 'C09AA', 'ACE inhibitors, plain')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'C08CA01', 'amlodipine'),
    rxnorm: Code(rxnormSystem, '17767', 'amlodipine'),
    name: L4('Amlodipine', 'Amlodipino', 'Amlodipin', 'Amlodipină'),
    strengths: [Strength(5, 'mg'), Strength(10, 'mg')],
    alternatives: [Code(atcSystem, 'C08CA', 'Dihydropyridine derivatives')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'C07AB07', 'bisoprolol'),
    rxnorm: Code(rxnormSystem, '19484', 'bisoprolol'),
    name: L4('Bisoprolol', 'Bisoprolol', 'Bisoprolol', 'Bisoprolol'),
    strengths: [Strength(2.5, 'mg'), Strength(5, 'mg')],
    alternatives: [Code(atcSystem, 'C07AB', 'Beta blocking agents, selective')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'C10AA05', 'atorvastatin'),
    rxnorm: Code(rxnormSystem, '83367', 'atorvastatin'),
    name: L4('Atorvastatin', 'Atorvastatina', 'Atorvastatin', 'Atorvastatină'),
    strengths: [Strength(20, 'mg'), Strength(40, 'mg')],
    alternatives: [Code(atcSystem, 'C10AA', 'HMG CoA reductase inhibitors')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'C10AA01', 'simvastatin'),
    rxnorm: Code(rxnormSystem, '36567', 'simvastatin'),
    name: L4('Simvastatin', 'Simvastatina', 'Simvastatin', 'Simvastatină'),
    strengths: [Strength(20, 'mg'), Strength(40, 'mg')],
    alternatives: [Code(atcSystem, 'C10AA', 'HMG CoA reductase inhibitors')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'B01AF02', 'apixaban'),
    rxnorm: Code(rxnormSystem, '1364430', 'apixaban'),
    name: L4('Apixaban', 'Apixabán', 'Apixaban', 'Apixaban'),
    strengths: [Strength(2.5, 'mg'), Strength(5, 'mg')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'B01AC06', 'acetylsalicylic acid'),
    rxnorm: Code(rxnormSystem, '1191', 'aspirin'),
    name: L4(
      'Acetylsalicylic acid',
      'Ácido acetilsalicílico',
      'Acetylsalicylsäure',
      'Acid acetilsalicilic',
    ),
    strengths: [Strength(100, 'mg')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'C03CA01', 'furosemide'),
    rxnorm: Code(rxnormSystem, '4603', 'furosemide'),
    name: L4('Furosemide', 'Furosemida', 'Furosemid', 'Furosemid'),
    strengths: [Strength(20, 'mg'), Strength(40, 'mg')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'H03AA01', 'levothyroxine sodium'),
    rxnorm: Code(rxnormSystem, '10582', 'levothyroxine'),
    name: L4('Levothyroxine', 'Levotiroxina', 'Levothyroxin', 'Levotiroxină'),
    strengths: [Strength(50, 'µg'), Strength(75, 'µg'), Strength(100, 'µg')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'A02BC02', 'pantoprazole'),
    rxnorm: Code(rxnormSystem, '40790', 'pantoprazole'),
    name: L4('Pantoprazole', 'Pantoprazol', 'Pantoprazol', 'Pantoprazol'),
    strengths: [Strength(20, 'mg'), Strength(40, 'mg')],
    alternatives: [Code(atcSystem, 'A02BC', 'Proton pump inhibitors')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'A02BC01', 'omeprazole'),
    rxnorm: Code(rxnormSystem, '7646', 'omeprazole'),
    name: L4('Omeprazole', 'Omeprazol', 'Omeprazol', 'Omeprazol'),
    strengths: [Strength(20, 'mg')],
    alternatives: [Code(atcSystem, 'A02BC', 'Proton pump inhibitors')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'J01CA04', 'amoxicillin'),
    rxnorm: Code(rxnormSystem, '723', 'amoxicillin'),
    name: L4('Amoxicillin', 'Amoxicilina', 'Amoxicillin', 'Amoxicilină'),
    strengths: [Strength(500, 'mg'), Strength(1000, 'mg')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'N02BE01', 'paracetamol'),
    rxnorm: Code(rxnormSystem, '161', 'acetaminophen'),
    name: L4('Paracetamol', 'Paracetamol', 'Paracetamol', 'Paracetamol'),
    strengths: [Strength(500, 'mg'), Strength(1000, 'mg')],
  ),
  MedicationDef(
    atc: Code(atcSystem, 'R03AC02', 'salbutamol'),
    rxnorm: Code(rxnormSystem, '435', 'albuterol'),
    name: L4('Salbutamol', 'Salbutamol', 'Salbutamol', 'Salbutamol'),
    strengths: [Strength(100, 'µg')],
    form: DoseForm.inhaler,
  ),
  MedicationDef(
    atc: Code(atcSystem, 'A10AE04', 'insulin glargine'),
    rxnorm: Code(rxnormSystem, '274783', 'insulin glargine'),
    name: L4(
      'Insulin glargine',
      'Insulina glargina',
      'Insulin glargin',
      'Insulină glargin',
    ),
    strengths: [Strength(100, 'U/mL')],
    form: DoseForm.injection,
  ),
];

/// Dosage instructions per dose form, as printed in each language.
const dosagePatterns = <DoseForm, List<L4>>{
  DoseForm.tablet: [
    L4(
      '1 tablet once daily in the morning',
      '1 comprimido al día por la mañana',
      '1-0-0',
      '1 cp. dimineața',
    ),
    L4('1 tablet twice daily', '1 comprimido cada 12 horas', '1-0-1', '1-0-1'),
    L4(
      '1 tablet in the evening',
      '1 comprimido por la noche',
      '0-0-1',
      '1 cp. seara',
    ),
    L4(
      '1 tablet three times daily',
      '1 comprimido cada 8 horas',
      '1-1-1',
      '1 cp. de 3 ori pe zi',
    ),
  ],
  DoseForm.inhaler: [
    L4(
      '2 puffs as needed',
      '2 inhalaciones si precisa',
      '2 Hübe bei Bedarf',
      '2 pufuri la nevoie',
    ),
  ],
  DoseForm.injection: [
    L4(
      '20 units at bedtime',
      '20 UI por la noche',
      '20 IE zur Nacht',
      '20 UI seara',
    ),
    L4(
      '14 units in the morning',
      '14 UI por la mañana',
      '14 IE morgens',
      '14 UI dimineața',
    ),
  ],
};

// ---------------------------------------------------------------------------
// Allergies and procedures
// ---------------------------------------------------------------------------

class AllergenDef {
  const AllergenDef(this.code, this.name, this.category);
  final Code code;
  final L4 name;

  /// FHIR AllergyIntolerance.category code.
  final String category;
}

const allergens = <AllergenDef>[
  AllergenDef(
    Code(snomedSystem, '764146007', 'Penicillin'),
    L4('Penicillin', 'Penicilina', 'Penicillin', 'Penicilină'),
    'medication',
  ),
  AllergenDef(
    Code(snomedSystem, '387207008', 'Ibuprofen'),
    L4('Ibuprofen', 'Ibuprofeno', 'Ibuprofen', 'Ibuprofen'),
    'medication',
  ),
  AllergenDef(
    Code(snomedSystem, '387406002', 'Sulfonamide'),
    L4('Sulfonamides', 'Sulfonamidas', 'Sulfonamide', 'Sulfamide'),
    'medication',
  ),
  AllergenDef(
    Code(snomedSystem, '256349002', 'Peanut - dietary'),
    L4('Peanuts', 'Cacahuetes', 'Erdnüsse', 'Arahide'),
    'food',
  ),
  AllergenDef(
    Code(snomedSystem, '111088007', 'Latex'),
    L4('Latex', 'Látex', 'Latex', 'Latex'),
    'environment',
  ),
  AllergenDef(
    Code(snomedSystem, '288328004', 'Bee venom'),
    L4('Bee venom', 'Veneno de abeja', 'Bienengift', 'Venin de albină'),
    'environment',
  ),
];

const manifestations = <(Code, L4)>[
  (
    Code(snomedSystem, '271807003', 'Eruption of skin'),
    L4('Rash', 'Exantema', 'Hautausschlag', 'Erupție cutanată'),
  ),
  (
    Code(snomedSystem, '126485001', 'Urticaria'),
    L4('Urticaria', 'Urticaria', 'Urtikaria', 'Urticarie'),
  ),
  (
    Code(snomedSystem, '39579001', 'Anaphylaxis'),
    L4('Anaphylaxis', 'Anafilaxia', 'Anaphylaxie', 'Anafilaxie'),
  ),
  (
    Code(snomedSystem, '4386001', 'Bronchospasm'),
    L4('Bronchospasm', 'Broncoespasmo', 'Bronchospasmus', 'Bronhospasm'),
  ),
  (
    Code(snomedSystem, '41291007', 'Angioedema'),
    L4('Angioedema', 'Angioedema', 'Angioödem', 'Angioedem'),
  ),
];

const allergyCategoryLabels = <String, L4>{
  'medication': L4('medication', 'medicamento', 'Medikament', 'medicament'),
  'food': L4('food', 'alimento', 'Nahrungsmittel', 'aliment'),
  'environment': L4('environment', 'ambiental', 'Umwelt', 'mediu'),
};

const procedures = <(Code, L4)>[
  (
    Code(snomedSystem, '73761001', 'Colonoscopy'),
    L4('Colonoscopy', 'Colonoscopia', 'Koloskopie', 'Colonoscopie'),
  ),
  (
    Code(snomedSystem, '76009000', 'Esophagogastroduodenoscopy'),
    L4(
      'Upper GI endoscopy',
      'Gastroscopia',
      'Gastroskopie',
      'Endoscopie digestivă superioară',
    ),
  ),
  (
    Code(snomedSystem, '40701008', 'Echocardiography'),
    L4(
      'Echocardiography',
      'Ecocardiografía',
      'Echokardiographie',
      'Ecocardiografie',
    ),
  ),
  (
    Code(snomedSystem, '33367005', 'Coronary angiography'),
    L4(
      'Coronary angiography',
      'Coronariografía',
      'Koronarangiographie',
      'Coronarografie',
    ),
  ),
  (
    Code(snomedSystem, '399208008', 'Plain chest X-ray'),
    L4(
      'Chest X-ray',
      'Radiografía de tórax',
      'Röntgen-Thorax',
      'Radiografie toracică',
    ),
  ),
  (
    Code(snomedSystem, '45036003', 'Ultrasonography of abdomen'),
    L4(
      'Abdominal ultrasound',
      'Ecografía abdominal',
      'Abdomensonographie',
      'Ecografie abdominală',
    ),
  ),
];

// ---------------------------------------------------------------------------
// Document vocabulary
// ---------------------------------------------------------------------------

const labels = <String, L4>{
  'labReportTitle': L4(
    'Laboratory report',
    'Informe de laboratorio',
    'Laborbefund',
    'Buletin de analize medicale',
  ),
  'dischargeTitle': L4(
    'Discharge letter',
    'Informe de alta',
    'Entlassungsbrief',
    'Bilet de ieșire din spital',
  ),
  'patient': L4('Patient', 'Paciente', 'Patient', 'Pacient'),
  'dob': L4(
    'Date of birth',
    'Fecha de nacimiento',
    'Geburtsdatum',
    'Data nașterii',
  ),
  'sex': L4('Sex', 'Sexo', 'Geschlecht', 'Sex'),
  'reportDate': L4(
    'Report date',
    'Fecha del informe',
    'Befunddatum',
    'Data buletinului',
  ),
  'physician': L4('Physician', 'Médico', 'Arzt', 'Medic'),
  'test': L4('Test', 'Prueba', 'Untersuchung', 'Analiză'),
  'result': L4('Result', 'Resultado', 'Ergebnis', 'Rezultat'),
  'unit': L4('Unit', 'Unidad', 'Einheit', 'UM'),
  'range': L4(
    'Reference range',
    'Valores de referencia',
    'Referenzbereich',
    'Interval de referință',
  ),
  'flag': L4('Flag', 'Ind.', 'Kz.', 'Ind.'),
  'conclusion': L4('Conclusion', 'Conclusión', 'Beurteilung', 'Concluzie'),
  'department': L4('Department', 'Servicio', 'Abteilung', 'Secția'),
  'admission': L4(
    'Admission',
    'Fecha de ingreso',
    'Aufnahme',
    'Data internării',
  ),
  'discharge': L4(
    'Discharge',
    'Fecha de alta',
    'Entlassung',
    'Data externării',
  ),
  'diagnoses': L4('Diagnoses', 'Diagnósticos', 'Diagnosen', 'Diagnostice'),
  'since': L4('since', 'desde', 'seit', 'din'),
  'vitals': L4(
    'Vital signs on admission',
    'Constantes vitales al ingreso',
    'Vitalparameter bei Aufnahme',
    'Parametri vitali la internare',
  ),
  'medication': L4(
    'Discharge medication',
    'Tratamiento al alta',
    'Entlassmedikation',
    'Tratament la externare',
  ),
  'allergies': L4('Allergies', 'Alergias', 'Allergien', 'Alergii'),
  'noAllergies': L4(
    'No known allergies',
    'No se conocen alergias',
    'Keine bekannten Allergien',
    'Fără alergii cunoscute',
  ),
  'procedures': L4('Procedures', 'Procedimientos', 'Prozeduren', 'Proceduri'),
  'on': L4('on', 'el', 'am', 'în data de'),
  'phone': L4.all('Tel.'),
  'license': L4('GMC No.', 'Nº colegiado', 'LANR', 'Cod parafă'),
  'allNormal': L4(
    'All values within reference ranges.',
    'Todos los valores dentro de los rangos de referencia.',
    'Alle Werte im Referenzbereich.',
    'Toate valorile în limite normale.',
  ),
  'elevated': L4('Elevated', 'Valores elevados', 'Erhöht', 'Valori crescute'),
  'decreased': L4(
    'Decreased',
    'Valores disminuidos',
    'Erniedrigt',
    'Valori scăzute',
  ),
  'footer': L4.all('SYNTHETIC TEST DOCUMENT - extraction_bench'),
  'men': L4('Men', 'Hombres', 'Männer', 'Bărbați'),
  'women': L4('Women', 'Mujeres', 'Frauen', 'Femei'),
  'children': L4('Children', 'Niños', 'Kinder', 'Copii'),
  'years': L4('years', 'años', 'Jahre', 'ani'),
};

const genderLabels = <String, L4>{
  'male': L4('Male', 'Masculino', 'männlich', 'Masculin'),
  'female': L4('Female', 'Femenino', 'weiblich', 'Feminin'),
};

const practitionerPrefix = L4('Dr.', 'Dr.', 'Dr. med.', 'Dr.');

// ---------------------------------------------------------------------------
// Synthetic people, places and identifiers
// ---------------------------------------------------------------------------

class NamePool {
  const NamePool(
    this.male,
    this.female,
    this.family, {
    this.doubleSurname = false,
  });
  final List<String> male;
  final List<String> female;
  final List<String> family;

  /// Spanish names carry two surnames.
  final bool doubleSurname;
}

const namePools = <String, NamePool>{
  'en': NamePool(
    ['James', 'Oliver', 'Thomas', 'George', 'William', 'Daniel', 'Samuel'],
    ['Emily', 'Charlotte', 'Sophie', 'Hannah', 'Grace', 'Lucy', 'Olivia'],
    [
      'Turner',
      'Hughes',
      'Bennett',
      'Clarke',
      'Walsh',
      'Fletcher',
      'Marsh',
      'Holloway',
    ],
  ),
  'es': NamePool(
    ['José', 'Javier', 'Alejandro', 'Miguel', 'Sergio', 'Andrés'],
    ['María', 'Lucía', 'Carmen', 'Elena', 'Inés', 'Sofía'],
    [
      'García',
      'Fernández',
      'Martín',
      'Sánchez',
      'Romero',
      'Navarro',
      'Ibáñez',
      'Muñoz',
    ],
    doubleSurname: true,
  ),
  'de': NamePool(
    ['Lukas', 'Jonas', 'Stefan', 'Matthias', 'Jürgen', 'Felix'],
    ['Anna', 'Katharina', 'Sabine', 'Lea', 'Mareike', 'Ursula'],
    [
      'Müller',
      'Schröder',
      'Weiß',
      'Becker',
      'Hoffmann',
      'Krämer',
      'Böhm',
      'Groß',
    ],
  ),
  'ro': NamePool(
    ['Andrei', 'Mihai', 'Ionuț', 'Vlad', 'Ștefan', 'Radu'],
    ['Ioana', 'Elena', 'Andreea', 'Mădălina', 'Cristina', 'Ana'],
    [
      'Popescu',
      'Ionescu',
      'Dumitrescu',
      'Stănescu',
      'Țîrlea',
      'Munteanu',
      'Bălan',
      'Constantinescu',
    ],
  ),
};

class City {
  const City(this.name, this.postcode);
  final String name;
  final String postcode;
}

const _streets = <String, List<String>>{
  'en': [
    'Station Road',
    'Park Lane',
    'Mill Street',
    'Church Road',
    'Victoria Street',
  ],
  'es': [
    'Calle Mayor',
    'Avenida de la Constitución',
    'Calle del Prado',
    'Paseo de la Alameda',
  ],
  'de': [
    'Hauptstraße',
    'Bahnhofstraße',
    'Lindenweg',
    'Schillerstraße',
    'Gartenstraße',
  ],
  'ro': [
    'Str. Memorandumului',
    'Bd. Unirii',
    'Str. Republicii',
    'Calea Victoriei',
    'Str. Florilor',
  ],
};

const _cities = <String, List<City>>{
  'en': [
    City('Leeds', 'LS1 4AP'),
    City('York', 'YO1 7HH'),
    City('Bristol', 'BS1 5TR'),
    City('Norwich', 'NR2 1TF'),
  ],
  'es': [
    City('Madrid', '28013'),
    City('Sevilla', '41001'),
    City('Valencia', '46002'),
    City('Zaragoza', '50001'),
  ],
  'de': [
    City('Berlin', '10115'),
    City('München', '80335'),
    City('Köln', '50667'),
    City('Hamburg', '20095'),
  ],
  'ro': [
    City('Cluj-Napoca', '400114'),
    City('București', '030833'),
    City('Iași', '700028'),
    City('Timișoara', '300011'),
  ],
};

/// One-line address as printed: `48 Station Road, Leeds LS1 4AP`.
String randomAddress(String lang, BenchRng rng) {
  final street = rng.pick(_streets[lang]!);
  final number = rng.intBetween(1, 120);
  final city = rng.pick(_cities[lang]!);
  return switch (lang) {
    'en' => '$number $street, ${city.name} ${city.postcode}',
    _ => '$street $number, ${city.postcode} ${city.name}',
  };
}

String _digits(BenchRng rng, int n) =>
    List.generate(n, (_) => rng.nextInt(10)).join();

/// A phone number in the formatting of [lang].
String randomPhone(String lang, BenchRng rng) => switch (lang) {
  'en' => '+44 113 496 0${_digits(rng, 3)}',
  'es' => '+34 91 ${_digits(rng, 3)} ${_digits(rng, 2)} ${_digits(rng, 2)}',
  'de' => '+49 30 23125 ${_digits(rng, 3)}',
  'ro' => '+40 264 ${_digits(rng, 3)} ${_digits(rng, 3)}',
  _ => throw ArgumentError.value(lang, 'lang'),
};

const organizationNames = <String, (List<String>, List<String>)>{
  // (hospitals, laboratories)
  'en': (
    [
      'Northfield General Hospital',
      'Riverside Community Hospital',
      'Ashgrove Royal Infirmary',
    ],
    [
      'Riverside Clinical Laboratory',
      'Northfield Pathology Services',
      'Ashgrove Diagnostics Lab',
    ],
  ),
  'es': (
    [
      'Hospital Comarcal Valle Verde',
      'Hospital General Los Almendros',
      'Hospital Clínico Río Claro',
    ],
    [
      'Laboratorio Clínico Alameda',
      'Laboratorio de Análisis Río Claro',
      'Centro de Análisis Clínicos Mirasol',
    ],
  ),
  'de': (
    [
      'Kreisklinikum Bergheide',
      'St.-Elisabeth-Krankenhaus Waldau',
      'Klinikum am Lindenpark',
    ],
    [
      'Labor Dr. Sonnfeld & Kollegen',
      'Medizinisches Labor Auental',
      'Laborpraxis am Marktplatz',
    ],
  ),
  'ro': (
    [
      'Spitalul Clinic Județean Valea Verde',
      'Spitalul Municipal Dealul Florilor',
      'Spitalul Orășenesc Izvorul Rece',
    ],
    [
      'Laborator Analize Medicale Sanocert',
      'Centrul de Diagnostic Mediva Nord',
      'Laboratorul Clinic Ardealul',
    ],
  ),
};

/// A patient identifier: how it is labelled on the page, its value as printed,
/// and its FHIR type and system.
class PatientIdentifier {
  const PatientIdentifier(this.label, this.value, this.typeCode, this.system);
  final String label;
  final String value;
  final String typeCode;
  final String system;
}

/// MRN (en), DNI (es), Versichertennummer (de) or CNP (ro). The CNP encodes
/// [birthDate] and [gender] the way the app's `PatientPostProcessor` reads it.
PatientIdentifier randomIdentifier(
  String lang,
  BenchRng rng, {
  required DateTime birthDate,
  required String gender,
}) {
  switch (lang) {
    case 'en':
      return PatientIdentifier(
        'MRN',
        _digits(rng, 8),
        'MR',
        'urn:extraction-bench:en:mrn',
      );
    case 'es':
      final n = rng.intBetween(10000000, 99999999);
      const letters = 'TRWAGMYFPDXBNJZSQVHLCKE';
      return PatientIdentifier(
        'DNI',
        '$n${letters[n % 23]}',
        'NI',
        'urn:extraction-bench:es:dni',
      );
    case 'de':
      final letter = String.fromCharCode(65 + rng.nextInt(26));
      final body = _digits(rng, 8);
      final letterNum = (letter.codeUnitAt(0) - 64).toString().padLeft(2, '0');
      final all = '$letterNum$body';
      var sum = 0;
      for (var i = 0; i < all.length; i++) {
        final p = int.parse(all[i]) * (i.isEven ? 1 : 2);
        sum += p ~/ 10 + p % 10;
      }
      return PatientIdentifier(
        'Versichertennummer',
        '$letter$body${sum % 10}',
        'SB',
        'urn:extraction-bench:de:kvnr',
      );
    case 'ro':
      final centuryBase = birthDate.year >= 2000 ? 5 : 1;
      final s = centuryBase + (gender == 'female' ? 1 : 0);
      final yy = (birthDate.year % 100).toString().padLeft(2, '0');
      final mm = birthDate.month.toString().padLeft(2, '0');
      final dd = birthDate.day.toString().padLeft(2, '0');
      final county = rng.intBetween(1, 40).toString().padLeft(2, '0');
      final seq = rng.intBetween(1, 999).toString().padLeft(3, '0');
      final body = '$s$yy$mm$dd$county$seq';
      const weights = '279146358279';
      var sum = 0;
      for (var i = 0; i < 12; i++) {
        sum += int.parse(body[i]) * int.parse(weights[i]);
      }
      final check = sum % 11 == 10 ? 1 : sum % 11;
      return PatientIdentifier(
        'CNP',
        '$body$check',
        'NI',
        'urn:extraction-bench:ro:cnp',
      );
  }
  throw ArgumentError.value(lang, 'lang');
}

/// Practitioner licence number as printed: 7 digits (en), 9 (es, de), 6 (ro).
String randomLicense(String lang, BenchRng rng) => switch (lang) {
  'en' => _digits(rng, 7),
  'es' => _digits(rng, 9),
  'de' => _digits(rng, 9),
  'ro' => _digits(rng, 6),
  _ => throw ArgumentError.value(lang, 'lang'),
};
