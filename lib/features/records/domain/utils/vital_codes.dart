import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';

const String kLoincHeartRate = '8867-4';
const String kLoincBloodPressurePanel = '85354-9';
const String kLoincBloodPressurePanelAlt = '55284-4';
const String kLoincTemperature = '8310-5';
const String kLoincBloodOxygen = '2708-6';
const String kLoincWeight = '29463-7';
const String kLoincHeight = '8302-2';
const String kLoincBmi = '39156-5';
const String kLoincSystolic = '8480-6';
const String kLoincDiastolic = '8462-4';
const String kLoincRespiratoryRate = '9279-1';
const String kLoincBloodGlucose = '2339-0';

const Set<String> kVitalLoincCodes = {
  kLoincHeartRate,
  kLoincBloodPressurePanel,
  kLoincBloodPressurePanelAlt,
  kLoincTemperature,
  kLoincBloodOxygen,
  kLoincWeight,
  kLoincHeight,
  kLoincBmi,
  kLoincSystolic,
  kLoincDiastolic,
  kLoincRespiratoryRate,
  kLoincBloodGlucose,
};

bool isVitalLoinc(String code) => kVitalLoincCodes.contains(code);

/// LOINC codes of the observations whose unit follows the region (kg or lbs,
/// cm or ft/in, °C or °F, mmol/L or mg/dL), by what they measure. Other
/// observations are shown in the unit they were recorded in: cholesterol and
/// creatinine are reported in mg/dL too, but the glucose factor does not
/// apply to them.
const Map<String, PatientVitalType> _kRegionUnitLoincCodes = {
  // Body weight; measured; stated; with clothes; without clothes.
  kLoincWeight: PatientVitalType.weight,
  '3141-9': PatientVitalType.weight,
  '3142-7': PatientVitalType.weight,
  '8350-1': PatientVitalType.weight,
  '8351-9': PatientVitalType.weight,
  // Body height; measured; stated; lying; standing.
  kLoincHeight: PatientVitalType.height,
  '3137-7': PatientVitalType.height,
  '3138-5': PatientVitalType.height,
  '8306-3': PatientVitalType.height,
  '8308-9': PatientVitalType.height,
  // Body temperature; oral; rectal; axillary; tympanic.
  kLoincTemperature: PatientVitalType.temperature,
  '8331-1': PatientVitalType.temperature,
  '8332-9': PatientVitalType.temperature,
  '8328-7': PatientVitalType.temperature,
  '8333-7': PatientVitalType.temperature,
  // Glucose in blood, serum or plasma, capillary blood, fasting; mass and
  // molar concentration.
  kLoincBloodGlucose: PatientVitalType.bloodGlucose,
  '2345-7': PatientVitalType.bloodGlucose,
  '41653-7': PatientVitalType.bloodGlucose,
  '1558-6': PatientVitalType.bloodGlucose,
  '2340-8': PatientVitalType.bloodGlucose,
  '15074-8': PatientVitalType.bloodGlucose,
  '14749-6': PatientVitalType.bloodGlucose,
  '14771-0': PatientVitalType.bloodGlucose,
  '14743-9': PatientVitalType.bloodGlucose,
};

/// What the observation with LOINC [code] measures when its unit follows the
/// region, otherwise null.
PatientVitalType? regionUnitVital(String code) => _kRegionUnitLoincCodes[code];
