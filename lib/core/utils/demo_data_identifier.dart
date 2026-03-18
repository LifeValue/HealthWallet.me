class DemoDataIdentifier {
  static const String demoSourceId = 'demo_data';

  static bool isDemoData(String? sourceId) {
    return sourceId == demoSourceId;
  }

  static bool isDemoResource(String? sourceId) {
    return isDemoData(sourceId);
  }
}
