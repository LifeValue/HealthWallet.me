enum RegionPreset {
  us(
    dateFormat: 'MM-dd-yyyy',
    dateTimeFormat: 'MM-dd-yyyy, h:mm a',
    weightUnit: 'lbs',
    heightUnit: 'ft/in',
    temperatureUnit: '°F',
    glucoseUnit: 'mg/dL',
    displayName: 'US',
  ),
  europe(
    dateFormat: 'dd-MM-yyyy',
    dateTimeFormat: 'dd-MM-yyyy, HH:mm',
    weightUnit: 'kg',
    heightUnit: 'cm',
    temperatureUnit: '°C',
    glucoseUnit: 'mmol/L',
    displayName: 'Europe',
  ),
  uk(
    dateFormat: 'dd-MM-yyyy',
    dateTimeFormat: 'dd-MM-yyyy, HH:mm',
    weightUnit: 'lbs',
    heightUnit: 'ft/in',
    temperatureUnit: '°C',
    glucoseUnit: 'mmol/L',
    displayName: 'UK',
  );

  final String dateFormat;
  final String dateTimeFormat;
  final String weightUnit;
  final String heightUnit;
  final String temperatureUnit;
  final String glucoseUnit;
  final String displayName;

  const RegionPreset({
    required this.dateFormat,
    required this.dateTimeFormat,
    required this.weightUnit,
    required this.heightUnit,
    required this.temperatureUnit,
    required this.glucoseUnit,
    required this.displayName,
  });

  static RegionPreset fromString(String? value) {
    if (value == null) return RegionPreset.europe;
    return RegionPreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => RegionPreset.europe,
    );
  }
}
