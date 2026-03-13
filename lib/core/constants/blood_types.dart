class BloodTypes {
  static const String aboLoincCode = '883-9';
  static const String rhLoincCode = '10331-7';
  static const String combinedLoincCode = '34530-6';

  static const List<String> aboTypes = ['A', 'B', 'AB', 'O'];
  static const List<String> rhTypes = ['+', '-'];
  static const List<String> allBloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  static const Map<String, String> snomedCodes = {
    'A+': '278149003',
    'A-': '278150003',
    'B+': '278151004',
    'B-': '278152006',
    'AB+': '278153001',
    'AB-': '278154007',
    'O+': '278155008',
    'O-': '278156009',
  };

  static const Map<String, String> displayNames = {
    'A+': 'A positive',
    'A-': 'A negative',
    'B+': 'B positive',
    'B-': 'B negative',
    'AB+': 'AB positive',
    'AB-': 'AB negative',
    'O+': 'O positive',
    'O-': 'O negative',
  };

  static const Map<String, String> fhirDisplayMapping = {
    'Blood group A Rh(D) positive': 'A+',
    'Blood group A Rh(D) negative': 'A-',
    'Blood group B Rh(D) positive': 'B+',
    'Blood group B Rh(D) negative': 'B-',
    'Blood group AB Rh(D) positive': 'AB+',
    'Blood group AB Rh(D) negative': 'AB-',
    'Blood group O Rh(D) positive': 'O+',
    'Blood group O Rh(D) negative': 'O-',
    'A Rh(D) positive': 'A+',
    'A Rh(D) negative': 'A-',
    'B Rh(D) positive': 'B+',
    'B Rh(D) negative': 'B-',
    'AB Rh(D) positive': 'AB+',
    'AB Rh(D) negative': 'AB-',
    'O Rh(D) positive': 'O+',
    'O Rh(D) negative': 'O-',
  };

  static List<String> getAllBloodTypes() => allBloodTypes;

  static String getDisplayName(String bloodType) =>
      displayNames[bloodType] ?? bloodType;

  static String getSnomedCode(String bloodType) =>
      snomedCodes[bloodType] ?? '278149003';

  static bool isValidBloodType(String bloodType) =>
      allBloodTypes.contains(bloodType);
}
