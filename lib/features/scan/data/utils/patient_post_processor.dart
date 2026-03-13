import 'package:health_wallet/features/scan/domain/services/scan_log_buffer.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';

class PatientPostProcessor {
  static String get _ts => DateTime.now().toIso8601String().substring(11, 23);

  static MappingPatient postProcess(MappingPatient patient, String ocrText) {
    ScanLogBuffer.instance.log('[$_ts][PostProcessor] patient: ${patient.givenName.value} ${patient.familyName.value}, mrn=${patient.patientMRN.value}, label=${patient.identifierLabel}');

    var result = patient;

    result = _fixSwappedIdentifierFields(result);
    result = _validateIdentifierLabel(result, ocrText);
    result = _validateCnp(result, ocrText);
    result = _validateNames(result);
    result = _recoverNamesFromOcr(result, ocrText);

    if (result != patient) {
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] corrected: label=${result.identifierLabel}, dob=${result.dateOfBirth.value}, gender=${result.gender.value}');
    }

    return result;
  }

  static final _knownLabels = {'CNP', 'MRN', 'SSN', 'NHS', 'Identifier'};
  static final _numericPattern = RegExp(r'^\d[\d\s\-\.]+$');

  static MappingPatient _fixSwappedIdentifierFields(MappingPatient patient) {
    final label = patient.identifierLabel.trim();
    final mrn = patient.patientMRN.value.trim();

    final labelLooksNumeric = _numericPattern.hasMatch(label);
    final mrnLooksLikeLabel = _knownLabels.contains(mrn) ||
        (mrn.isNotEmpty && RegExp(r'^[A-Za-z]+$').hasMatch(mrn));

    if (labelLooksNumeric && (mrn.isEmpty || mrnLooksLikeLabel)) {
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] swapped fields: moving "$label" from label to MRN box');
      return patient.copyWith(
        patientMRN: MappedProperty(value: label, confidenceLevel: patient.patientMRN.confidenceLevel),
        identifierLabel: mrn.isNotEmpty && _knownLabels.contains(mrn) ? mrn : 'Identifier',
      );
    }

    if (labelLooksNumeric && mrn.isNotEmpty) {
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] label contains number "$label", resetting to Identifier');
      return patient.copyWith(identifierLabel: 'Identifier');
    }

    return patient;
  }

  static MappingPatient _validateIdentifierLabel(
    MappingPatient patient,
    String ocrText,
  ) {
    final mrnValue = patient.patientMRN.value.trim();
    final isValidCnp = _tryParseCnp(mrnValue) != null;

    if (patient.identifierLabel == 'CNP' && !isValidCnp) {
      final realCnp = _findCnpInText(ocrText);
      if (realCnp != null) {
        final parsed = _tryParseCnp(realCnp)!;
        ScanLogBuffer.instance.log('[$_ts][PostProcessor] CNP recovered from OCR: $realCnp (model had wrong value: $mrnValue)');
        return patient.copyWith(
          patientMRN: MappedProperty(value: realCnp, confidenceLevel: 0.9),
          identifierLabel: 'CNP',
          dateOfBirth: MappedProperty(value: parsed.dob, confidenceLevel: 1.0),
          gender: MappedProperty(value: parsed.gender, confidenceLevel: 1.0),
        );
      }
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] label CNP -> Identifier (not a valid CNP, none found in OCR)');
      return patient.copyWith(identifierLabel: 'Identifier');
    }

    if (!isValidCnp) {
      final realCnp = _findCnpInText(ocrText);
      if (realCnp != null) {
        final parsed = _tryParseCnp(realCnp)!;
        ScanLogBuffer.instance.log('[$_ts][PostProcessor] CNP found in OCR: $realCnp (model had: label=${patient.identifierLabel}, mrn=$mrnValue)');
        return patient.copyWith(
          patientMRN: MappedProperty(value: realCnp, confidenceLevel: 0.9),
          identifierLabel: 'CNP',
          dateOfBirth: MappedProperty(value: parsed.dob, confidenceLevel: 1.0),
          gender: MappedProperty(value: parsed.gender, confidenceLevel: 1.0),
        );
      }
    }

    if (isValidCnp && patient.identifierLabel != 'CNP') {
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] label ${patient.identifierLabel} -> CNP (valid 13-digit CNP detected)');
      return patient.copyWith(identifierLabel: 'CNP');
    }

    return patient;
  }

  static MappingPatient _validateCnp(MappingPatient patient, String ocrText) {
    if (patient.identifierLabel != 'CNP') return patient;

    final cnpValue = patient.patientMRN.value.trim();
    final parsed = _tryParseCnp(cnpValue);

    if (parsed == null) {
      final foundCnp = _findCnpInText(ocrText);
      if (foundCnp != null) {
        final foundParsed = _tryParseCnp(foundCnp);
        if (foundParsed != null) {
          ScanLogBuffer.instance.log('[$_ts][PostProcessor] CNP recovered from OCR: $foundCnp');
          return patient.copyWith(
            patientMRN: MappedProperty(value: foundCnp, confidenceLevel: 0.9),
            dateOfBirth: MappedProperty(
              value: foundParsed.dob,
              confidenceLevel: 1.0,
            ),
            gender: MappedProperty(
              value: foundParsed.gender,
              confidenceLevel: 1.0,
            ),
          );
        }
      }
      return patient;
    }

    ScanLogBuffer.instance.log('[$_ts][PostProcessor] CNP derived: dob=${parsed.dob}, gender=${parsed.gender}');
    return patient.copyWith(
      dateOfBirth: MappedProperty(
        value: parsed.dob,
        confidenceLevel: 1.0,
      ),
      gender: MappedProperty(
        value: parsed.gender,
        confidenceLevel: 1.0,
      ),
    );
  }

  static final _placeholderNames = {
    'surname',
    'first',
    'first name',
    'last name',
    'name',
    'patient name',
    'family name',
    'given name',
    'firstname',
    'lastname',
    'familyname',
    'givenname',
  };

  static bool _isPlaceholder(String value) {
    if (value.isEmpty) return false;
    if (value.startsWith('<') && value.endsWith('>')) return true;
    return _placeholderNames.contains(value.toLowerCase().trim());
  }

  static MappingPatient _validateNames(MappingPatient patient) {
    var result = patient;

    if (_isLikelyAddress(result.familyName.value)) {
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] cleared familyName (address detected)');
      result = result.copyWith(
        familyName: const MappedProperty(value: '', confidenceLevel: 0.0),
      );
    }

    if (_isLikelyAddress(result.givenName.value)) {
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] cleared givenName (address detected)');
      result = result.copyWith(
        givenName: const MappedProperty(value: '', confidenceLevel: 0.0),
      );
    }

    final familyIsPlaceholder = _isPlaceholder(result.familyName.value);
    final givenIsPlaceholder = _isPlaceholder(result.givenName.value);

    if (familyIsPlaceholder || givenIsPlaceholder) {
      ScanLogBuffer.instance.log('[$_ts][PostProcessor] placeholder detected: family="${result.familyName.value}", given="${result.givenName.value}"');
      if (familyIsPlaceholder) {
        result = result.copyWith(
          familyName: const MappedProperty(value: '', confidenceLevel: 0.0),
        );
      }
      if (givenIsPlaceholder) {
        result = result.copyWith(
          givenName: const MappedProperty(value: '', confidenceLevel: 0.0),
        );
      }
    }

    return result;
  }

  static CnpResult? _tryParseCnp(String cnp) {
    final digits = cnp.replaceAll(RegExp(r'\s'), '');
    if (digits.length != 13 || !RegExp(r'^\d{13}$').hasMatch(digits)) {
      return null;
    }

    final s = int.parse(digits[0]);
    if (s < 1 || s > 8) return null;

    final yy = int.parse(digits.substring(1, 3));
    final mm = int.parse(digits.substring(3, 5));
    final dd = int.parse(digits.substring(5, 7));

    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    int century;
    switch (s) {
      case 1:
      case 2:
        century = 1900;
      case 3:
      case 4:
        century = 1800;
      case 5:
      case 6:
        century = 2000;
      default:
        century = 1900;
    }

    final year = century + yy;
    final dob =
        '$year-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';

    final gender = (s % 2 == 1) ? 'male' : 'female';

    return CnpResult(dob: dob, gender: gender);
  }

  static bool _isLikelyAddress(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    final patterns = [
      'str.',
      'nr.',
      'bl.',
      'ap.',
      'et.',
      'sc.',
      'mun.',
      'jud.',
      'com.',
      'sat ',
      'loc.',
      'sect.',
      'b-dul',
      'calea ',
      'aleea ',
      'splaiul ',
      'st.',
      'ave.',
      'apt.',
      'suite ',
      'floor ',
      'p.o. box',
      'straße',
      'strasse',
      'plz ',
      'hausnr',
    ];
    final matchCount = patterns.where((p) => lower.contains(p)).length;
    return matchCount >= 2;
  }

  static MappingPatient _recoverNamesFromOcr(
    MappingPatient patient,
    String ocrText,
  ) {
    final needsFamily = patient.familyName.value.isEmpty;
    final needsGiven = patient.givenName.value.isEmpty;
    if (!needsFamily && !needsGiven) return patient;

    final namePatterns = [
      RegExp(r'Nume\s*(?:si|și)\s*[Pp]renume\s*[:=]\s*([A-ZÀ-Ž][A-ZÀ-Ž\-]+)\s+([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-\s]+?)(?:\s*[,;]|\s+CNP|\s+\d|\s*$)', multiLine: true),
      RegExp(r'Nume\s*(?:si|și)\s*[Pp]renume\s*[:=]\s*([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-]+)\s*,\s*([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-\s]+?)(?:\s*[,;]|\s+CNP|\s+\d|\s*$)', multiLine: true),
      RegExp(r'Nume\s*[:=]\s*([A-ZÀ-Ž][A-ZÀ-Ž\-]+)\s+Prenume\s*[:=]\s*([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-\s]+?)(?:\s*[,;]|\s+\d|\s*$)', multiLine: true),
      RegExp(r'(?:Patient|Name)\s*[:=]\s*([A-ZÀ-Ž][A-ZÀ-Ž\-]+)\s*,?\s+([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-\s]+?)(?:\s*[,;]|\s+\d|\s*$)', multiLine: true),
    ];

    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(ocrText);
      if (match != null) {
        final surname = match.group(1)!.trim();
        final firstName = match.group(2)!.trim();
        ScanLogBuffer.instance.log('[$_ts][PostProcessor] names recovered from OCR: "$surname" "$firstName"');
        var result = patient;
        if (needsFamily) {
          result = result.copyWith(
            familyName: MappedProperty(value: surname, confidenceLevel: 0.85),
          );
        }
        if (needsGiven) {
          result = result.copyWith(
            givenName: MappedProperty(value: firstName, confidenceLevel: 0.85),
          );
        }
        return result;
      }
    }

    ScanLogBuffer.instance.log('[$_ts][PostProcessor] could not recover names from OCR');
    return patient;
  }

  static String? _findCnpInText(String ocrText) {
    final matches = RegExp(r'\b\d{13}\b').allMatches(ocrText);
    for (final match in matches) {
      final candidate = match.group(0)!;
      if (_tryParseCnp(candidate) != null) {
        return candidate;
      }
    }
    return null;
  }
}

class CnpResult {
  final String dob;
  final String gender;

  const CnpResult({required this.dob, required this.gender});
}
