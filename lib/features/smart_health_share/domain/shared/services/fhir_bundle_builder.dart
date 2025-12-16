/// Service for building FHIR R4 Bundles from selected resources
abstract class FHIRBundleBuilder {
  /// Build a FHIR Bundle from selected resource IDs
  /// References are resolved automatically.
  /// 
  /// [requirePatient]: If `true`, Patient resource must be included (throws if not found).
  ///                   If `false` (default), Patient is optional. When Patient exists but is not
  ///                   in selected resources, minimal Patient info (Name + Age) is included.
  ///                   This enables granular data sharing for LocalQR and Smart Health Check-In.
  Future<Map<String, dynamic>> buildBundle({
    required List<String> resourceIds,
    String? sourceId,
    bool requirePatient = false,
  });
}

