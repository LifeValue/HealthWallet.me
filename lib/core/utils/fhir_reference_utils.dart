class FhirReferenceUtils {
  /// Extracts the referenced resource ID from a FHIR reference string.
  static String? extractReferenceId(String? reference) {
    if (reference == null) return null;
    if (reference.startsWith('urn:uuid:')) {
      return reference.substring('urn:uuid:'.length);
    }
    // Handles ResourceType/id or just id
    final parts = reference.split('/');
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
