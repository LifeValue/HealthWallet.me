class FhirReferenceUtils {
  /// Extracts the referenced resource ID from a FHIR reference string.
  static String? extractReferenceId(String? reference) {
    if (reference == null) return null;
    if (reference.startsWith('urn:uuid:')) {
      return reference.substring('urn:uuid:'.length);
    }
    // Handles ResourceType/id or just id; a versioned reference
    // ("Patient/pat-7/_history/3") names the resource before `_history`.
    final history = reference.indexOf('/_history/');
    final unversioned = history == -1
        ? reference
        : reference.substring(0, history);
    final parts = unversioned.split('/');
    return parts.isNotEmpty ? parts.last : reference;
  }
}
