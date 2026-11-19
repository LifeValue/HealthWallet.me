enum RegionPreset {
  us(
    dateFormat: 'MM-dd-yyyy',
    dateTimeFormat: 'MM-dd-yyyy, h:mm a',
    weightUnit: 'lbs',
    heightUnit: 'ft/in',
    temperatureUnit: '°F',
    glucoseUnit: 'mg/dL',
  ),
  europe(
    dateFormat: 'dd-MM-yyyy',
    dateTimeFormat: 'dd-MM-yyyy, HH:mm',
    weightUnit: 'kg',
    heightUnit: 'cm',
    temperatureUnit: '°C',
    glucoseUnit: 'mmol/L',
  ),
  uk(
    dateFormat: 'dd-MM-yyyy',
    dateTimeFormat: 'dd-MM-yyyy, HH:mm',
    weightUnit: 'lbs',
    heightUnit: 'ft/in',
    temperatureUnit: '°C',
    glucoseUnit: 'mmol/L',
  );

  final String dateFormat;
  final String dateTimeFormat;
  final String weightUnit;
  final String heightUnit;
  final String temperatureUnit;
  final String glucoseUnit;

  const RegionPreset({
    required this.dateFormat,
    required this.dateTimeFormat,
    required this.weightUnit,
    required this.heightUnit,
    required this.temperatureUnit,
    required this.glucoseUnit,
  });

  String formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    switch (this) {
      case RegionPreset.us:
        return '$m-$d-$y';
      case RegionPreset.europe:
      case RegionPreset.uk:
        return '$d-$m-$y';
    }
  }

  static RegionPreset fromString(String? value) {
    if (value == null) return RegionPreset.europe;
    return RegionPreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => RegionPreset.europe,
    );
  }
}
