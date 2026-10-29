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

/// Glucose observations, in mass (mg/dL) or molar (mmol/L) units. Only these
/// convert between mg/dL and mmol/L: the factor is glucose's molar mass and
/// is wrong for every other analyte.
const Set<String> kGlucoseLoincCodes = {
  kLoincBloodGlucose, // Glucose [Mass/volume] in Blood
  '2345-7', // Glucose [Mass/volume] in Serum or Plasma
  '2340-8', // Glucose [Mass/volume] in Blood by Automated test strip
  '2341-6', // Glucose [Mass/volume] in Blood by Test strip manual
  '41653-7', // Glucose [Mass/volume] in Capillary blood by Glucometer
  '1558-6', // Fasting glucose [Mass/volume] in Serum or Plasma
  '41604-0', // Fasting glucose [Mass/volume] in Capillary blood by Glucometer
  '14749-6', // Glucose [Moles/volume] in Serum or Plasma
  '15074-8', // Glucose [Moles/volume] in Blood
  '14743-9', // Glucose [Moles/volume] in Capillary blood by Glucometer
  '14771-0', // Fasting glucose [Moles/volume] in Serum or Plasma
};

/// Body height observations, the only lengths shown in feet and inches.
const Set<String> kBodyHeightLoincCodes = {
  kLoincHeight, // Body height
  '8306-3', // Body height --lying
  '8308-9', // Body height --standing
  '3137-7', // Body height Measured
};
