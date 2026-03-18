import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/utils/extractors/fhir_common_extractor.dart';

class FhirPatientExtractor {
  static String? extractHumanName(dynamic name) {
    if (name == null) return null;

    final given = name.given?.map((g) => g.toString()).join(' ') ?? '';
    final family = name.family?.toString() ?? '';
    final prefix = name.prefix?.map((p) => p.toString()).join(' ') ?? '';

    final title = prefix.isNotEmpty ? '$prefix ' : '';

    if (given.isNotEmpty && family.isNotEmpty) {
      return '$title$given, $family';
    } else if (given.isNotEmpty) {
      return '$title$given';
    } else if (family.isNotEmpty) {
      return '$title$family';
    }

    return null;
  }

  static String? extractHumanNameForHome(dynamic name) {
    if (name == null) return null;

    final given = name.given?.map((g) => g.toString()).join(' ') ?? '';
    final family = name.family?.toString() ?? '';
    final prefix = name.prefix?.map((p) => p.toString()).join(' ') ?? '';

    final title = prefix.isNotEmpty ? '$prefix ' : '';

    if (given.isNotEmpty && family.isNotEmpty) {
      return '$title$given $family';
    } else if (given.isNotEmpty) {
      return '$title$given';
    } else if (family.isNotEmpty) {
      return '$title$family';
    }

    return null;
  }

  static String? extractHumanNameFamilyFirst(dynamic name) {
    if (name == null) return null;

    final family = name.family?.toString() ?? '';
    final given = name.given?.isNotEmpty == true
        ? name.given!.map((g) => g.toString()).join(' ')
        : '';

    if (family.isNotEmpty && given.isNotEmpty) {
      return '$family, $given';
    } else if (family.isNotEmpty) {
      return family;
    } else if (given.isNotEmpty) {
      return given;
    }

    return null;
  }

  static String? extractFirstHumanNameFromArray(List<dynamic>? nameArray) {
    if (nameArray != null &&
        nameArray.isNotEmpty &&
        nameArray.first is fhir_r4.HumanName) {
      return extractHumanName(nameArray.first);
    }
    return null;
  }

  static String extractPatientGiven(Patient patient) {
    if (patient.name?.isNotEmpty == true) {
      final given = patient.name!.first.given;
      if (given != null && given.isNotEmpty) {
        return given.map((g) => g.toString()).join(' ');
      }
    }
    return '';
  }

  static String extractPatientFamily(Patient patient) {
    if (patient.name?.isNotEmpty == true) {
      final family = patient.name!.first.family;
      if (family != null) {
        return family.toString();
      }
    }
    return '';
  }

  static String extractPatientId(Patient patient) {
    if (patient.identifier?.isNotEmpty == true) {
      for (final identifier in patient.identifier!) {
        if (identifier.value != null) {
          return identifier.value!.toString();
        }
      }
    }
    return patient.id;
  }

  static String extractPatientAge(Patient patient) {
    if (patient.birthDate == null) return 'N/A';

    try {
      final birthDateStr = patient.birthDate!.toString();
      if (birthDateStr.isEmpty) return 'N/A';

      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      final age = now.year - birthDate.year;

      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        return '${age - 1} years';
      }

      return '$age years';
    } catch (e) {
      return 'N/A';
    }
  }

  static DateTime? extractPatientBirthDate(Patient patient) {
    if (patient.birthDate == null) return null;

    try {
      final birthDateStr = patient.birthDate!.toString();
      if (birthDateStr.isEmpty) return null;

      return DateTime.parse(birthDateStr);
    } catch (e) {
      return null;
    }
  }

  static String extractPatientGender(Patient patient) {
    final gender = FhirCommonExtractor.extractStatus(patient.gender);
    return gender ?? 'Unknown';
  }

  static String extractPatientIdentifierLabel(Patient patient) {
    if (patient.identifier == null || patient.identifier!.isEmpty) {
      return 'ID';
    }

    for (final id in patient.identifier!) {
      final coding = id.type?.coding;
      if (coding != null && coding.isNotEmpty) {
        final code = coding.first.code?.toString();
        switch (code) {
          case 'MR':
            return 'MRN';
          case 'SS':
            final displayText = id.type?.text?.toString().toUpperCase() ?? '';
            final codingDisplay =
                coding.first.display?.toString().toUpperCase() ?? '';
            final combined = '$displayText $codingDisplay';
            if (combined.contains('CNP') ||
                combined.contains('COD NUMERIC PERSONAL')) return 'CNP';
            if (combined.contains('SVNR') ||
                combined.contains('SOZIALVERSICHERUNGSNUMMER')) return 'SVNr';
            if (combined.contains('KVNR') ||
                combined.contains('KRANKENVERSICHERTENNUMMER')) return 'KVNR';
            if (combined.contains('NHS')) return 'NHS';
            if (combined.contains('CIP') ||
                combined.contains('CÓDIGO DE IDENTIFICACIÓN PERSONAL')) return 'CIP';
            if (combined.contains('NIR') ||
                combined.contains('SÉCURITÉ SOCIALE')) return 'NIR';
            if (combined.contains('CODICE FISCALE') ||
                combined.contains(' CF')) return 'CF';
            if (combined.contains('BSN') ||
                combined.contains('BURGERSERVICENUMMER')) return 'BSN';
            if (combined.contains('PESEL')) return 'PESEL';
            if (combined.contains('PERSONNUMMER') ||
                combined.contains('PNR')) return 'PNR';
            if (combined.contains('AHV') ||
                combined.contains('HINTERLASSENENVERSICHERUNG')) return 'AHV';
            return 'SSN';
          case 'NI':
            final displayText = id.type?.text?.toString().toUpperCase() ?? '';
            if (displayText.contains('DNI')) return 'DNI';
            return 'NI';
          case 'NH':
            return 'NHS';
          case 'DL':
            return 'DL';
          case 'PPN':
            return 'Passport';
        }
      }
    }

    final firstWithType = patient.identifier!
        .where((id) => id.type?.text != null && id.value != null)
        .firstOrNull;
    if (firstWithType != null) {
      return firstWithType.type!.text!.toString();
    }

    return 'ID';
  }

  static String extractPatientMRN(Patient patient) {
    if (patient.identifier == null || patient.identifier!.isEmpty) {
      return '';
    }

    final label = extractPatientIdentifierLabel(patient);
    final targetCode = _labelToFhirCode(label);

    if (targetCode != null) {
      try {
        final match = patient.identifier!.firstWhere(
          (id) =>
              id.type?.coding?.any(
                (coding) => coding.code?.toString() == targetCode,
              ) ??
              false,
        );
        if (match.value != null) return match.value!.toString();
      } catch (_) {}
    }

    try {
      final mrnIdentifier = patient.identifier!.firstWhere(
        (id) =>
            id.type?.coding?.any(
              (coding) => coding.code?.toString() == 'MR',
            ) ??
            false,
      );

      if (mrnIdentifier.value != null) {
        return mrnIdentifier.value!.toString();
      }
    } catch (_) {}

    try {
      final textMatch = patient.identifier!.firstWhere(
        (id) =>
            id.value != null &&
            id.value!.toString().isNotEmpty &&
            (id.type?.text?.toString().toUpperCase().contains('MRN') ?? false),
      );
      return textMatch.value!.toString();
    } catch (_) {}

    final first = patient.identifier!
        .where((id) => id.value != null && id.value!.toString().isNotEmpty)
        .firstOrNull;
    return first?.value?.toString() ?? '';
  }

  static String? _labelToFhirCode(String label) {
    switch (label) {
      case 'MRN':
        return 'MR';
      case 'CNP':
      case 'SSN':
      case 'KVNR':
      case 'SVNr':
      case 'CIP':
      case 'NIR':
      case 'CF':
      case 'BSN':
      case 'PESEL':
      case 'PNR':
      case 'AHV':
        return 'SS';
      case 'NHS':
        return 'NH';
      case 'DNI':
        return 'NI';
      default:
        return null;
    }
  }

  static String? extractMultipleBirth(dynamic multipleBirthX) {
    if (multipleBirthX == null) return null;

    final boolValue = multipleBirthX.isAs<fhir_r4.FhirBoolean>();
    if (boolValue != null) {
      return boolValue.valueBoolean == true ? 'Yes' : 'No';
    }

    final intValue = multipleBirthX.isAs<fhir_r4.FhirInteger>();
    if (intValue != null) {
      return 'Yes (Birth order: $intValue)';
    }

    return null;
  }

  static String? extractCommunicationLanguages(
      List<fhir_r4.PatientCommunication>? communication) {
    if (communication == null || communication.isEmpty) return null;

    final languages = communication
        .map((c) => FhirCommonExtractor.extractCodeableConceptText(c.language))
        .where((l) => l != null && l.isNotEmpty)
        .toList();

    return languages.isEmpty ? null : languages.join(', ');
  }

  static int? calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  static String? extractIdentifierByType(
      List<fhir_r4.Identifier>? identifiers, String typeCode) {
    if (identifiers == null) return null;

    for (final id in identifiers) {
      final code = id.type?.coding?.firstOrNull?.code?.valueString;
      if (code == typeCode) {
        return id.value?.valueString;
      }
    }
    return null;
  }

  static String? extractTelecomBySystem(
      List<fhir_r4.ContactPoint>? telecom, String system,
      {String? use}) {
    if (telecom == null) return null;

    for (final contact in telecom) {
      if (contact.system?.valueString == system) {
        if (use == null || contact.use?.valueString == use) {
          return contact.value?.valueString;
        }
      }
    }
    return null;
  }

  static List<Map<String, String>> extractAllTelecomBySystem(
      List<fhir_r4.ContactPoint>? telecom, String system) {
    if (telecom == null) return [];

    final results = <Map<String, String>>[];
    for (final contact in telecom) {
      if (contact.system?.valueString == system) {
        final value = contact.value?.valueString;
        if (value != null) {
          results.add({
            'value': value,
            'use': contact.use?.valueString ?? '',
          });
        }
      }
    }
    return results;
  }

  static String? extractTelecom(List<fhir_r4.ContactPoint>? telecom) {
    if (telecom == null || telecom.isEmpty) return null;

    for (final contact in telecom) {
      if (contact.value?.valueString != null) {
        final useType = contact.use?.valueString;
        final system = contact.system?.valueString;
        final value = contact.value!.valueString!;

        if (useType != null) {
          return '$value ($useType)';
        }
        if (system != null) {
          return '$system: $value';
        }
        return value;
      }
    }
    return null;
  }

  static String? formatFullAddress(fhir_r4.Address? address) {
    if (address == null) return null;

    final parts = <String>[];

    if (address.line != null) {
      for (final line in address.line!) {
        final lineStr = line.valueString;
        if (lineStr != null && lineStr.isNotEmpty) {
          parts.add(lineStr);
        }
      }
    }

    final cityStateZip = <String>[];
    if (address.city?.valueString != null) {
      cityStateZip.add(address.city!.valueString!);
    }
    if (address.state?.valueString != null) {
      cityStateZip.add(address.state!.valueString!);
    }
    if (address.postalCode?.valueString != null) {
      cityStateZip.add(address.postalCode!.valueString!);
    }
    if (cityStateZip.isNotEmpty) {
      parts.add(cityStateZip.join(', '));
    }

    if (address.country?.valueString != null) {
      parts.add(address.country!.valueString!);
    }

    return parts.isNotEmpty ? parts.join('\n') : null;
  }

  static String? extractRaceOrEthnicity(
      Map<String, dynamic> rawResource, String extensionUrl) {
    final extensions = rawResource['extension'] as List<dynamic>?;
    if (extensions == null) return null;

    for (final ext in extensions) {
      if (ext is Map<String, dynamic> && ext['url'] == extensionUrl) {
        final nestedExtensions = ext['extension'] as List<dynamic>?;
        if (nestedExtensions != null) {
          for (final nested in nestedExtensions) {
            if (nested is Map<String, dynamic> && nested['url'] == 'text') {
              return nested['valueString']?.toString();
            }
          }
          for (final nested in nestedExtensions) {
            if (nested is Map<String, dynamic> &&
                nested['url'] == 'ombCategory') {
              return nested['valueCoding']?['display']?.toString();
            }
          }
        }
      }
    }
    return null;
  }

  static String? extractExtensionValue(
      Map<String, dynamic> rawResource, String extensionUrl) {
    final extensions = rawResource['extension'] as List<dynamic>?;
    if (extensions == null) return null;

    for (final ext in extensions) {
      if (ext is Map<String, dynamic> && ext['url'] == extensionUrl) {
        return ext['valueCode']?.toString() ??
            ext['valueString']?.toString() ??
            ext['valueCodeableConcept']?['text']?.toString() ??
            ext['valueCodeableConcept']?['coding']?[0]?['display']?.toString();
      }
    }
    return null;
  }

  static String? extractBirthPlace(Map<String, dynamic> rawResource) {
    final extensions = rawResource['extension'] as List<dynamic>?;
    if (extensions == null) return null;

    for (final ext in extensions) {
      if (ext is Map<String, dynamic> &&
          ext['url'] ==
              'http://hl7.org/fhir/StructureDefinition/patient-birthPlace') {
        final address = ext['valueAddress'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];
          if (address['city'] != null) parts.add(address['city'].toString());
          if (address['state'] != null) parts.add(address['state'].toString());
          if (address['country'] != null) {
            parts.add(address['country'].toString());
          }
          return parts.isNotEmpty ? parts.join(', ') : null;
        }
      }
    }
    return null;
  }
}
