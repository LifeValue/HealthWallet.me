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

  /// The id of the patient a resource is about. Resources name it in
  /// `subject`, `patient` (AllergyIntolerance, Immunization, Claim,
  /// ExplanationOfBenefit…) or `beneficiary` (Coverage). Null when none of
  /// them refers to a patient.
  static String? patientIdOf(Map<String, dynamic> resource) {
    for (final field in const ['subject', 'patient', 'beneficiary']) {
      final reference = resource[field];
      if (reference is! Map) continue;
      final value = reference['reference'];
      if (value is! String) continue;
      final isPatient =
          value.startsWith('urn:uuid:') ||
          value.startsWith('Patient/') ||
          value.contains('/Patient/');
      final id = isPatient ? extractReferenceId(value) : null;
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }
}
