import 'package:flutter/widgets.dart';

class CountryIdentifier {
  final String identifierLabel;
  final String identifierFhirCode;
  final String identifierDisplayName;
  final String fhirIdentifierSystem;
  final String dialCode;
  final RegExp? identifierPattern;
  final String promptHints;

  const CountryIdentifier({
    required this.identifierLabel,
    required this.identifierFhirCode,
    required this.identifierDisplayName,
    required this.fhirIdentifierSystem,
    this.dialCode = '1',
    this.identifierPattern,
    this.promptHints = '',
  });

  static const _profiles = <String, CountryIdentifier>{
    'RO': CountryIdentifier(
      identifierLabel: 'CNP',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Cod Numeric Personal',
      fhirIdentifierSystem: 'urn:oid:2.16.840.1.113883.4.40',
      dialCode: '40',
      promptHints:
          '- Romanian: "Data nasterii" = birth date. "Data internarii" = NOT birth date\n'
          '- CNP (Cod Numeric Personal) = Romanian 13-digit ID. Encodes birth date and gender\n'
          '- patientMRN = the CNP number (13 digits after "CNP:"), NOT "Cod prezentare", "Foie de observatie", or "Nr. fisa"',
    ),
    'DE': CountryIdentifier(
      identifierLabel: 'KVNR',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Krankenversichertennummer',
      fhirIdentifierSystem: 'http://fhir.de/sid/gkv/kvid-10',
      dialCode: '49',
      promptHints:
          '- German: "Geburtsdatum" = birth date. "Aufnahmedatum" = NOT birth date\n'
          '- KVNR (Krankenversichertennummer) = German 10-char health insurance number (letter + 9 digits)',
    ),
    'AT': CountryIdentifier(
      identifierLabel: 'SVNr',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Sozialversicherungsnummer',
      fhirIdentifierSystem: 'urn:oid:1.2.40.0.10.1.4.3.1',
      dialCode: '43',
      promptHints:
          '- German: "Geburtsdatum" = birth date. "Aufnahmedatum" = NOT birth date\n'
          '- SVNr (Sozialversicherungsnummer) = Austrian 10-digit social insurance number',
    ),
    'ES': CountryIdentifier(
      identifierLabel: 'CIP',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Código de Identificación Personal',
      fhirIdentifierSystem: 'urn:oid:2.16.724.4.41',
      dialCode: '34',
      promptHints:
          '- Spanish: "Fecha de nacimiento" = birth date. "Fecha de ingreso" = NOT birth date\n'
          '- CIP (Código de Identificación Personal) = Spanish healthcare personal ID. Also look for DNI (8 digits + letter)',
    ),
    'FR': CountryIdentifier(
      identifierLabel: 'NIR',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Numéro de Sécurité Sociale',
      fhirIdentifierSystem: 'urn:oid:1.2.250.1.213.1.4.8',
      dialCode: '33',
      promptHints:
          '- French: "Date de naissance" = birth date. "Date d\'admission" = NOT birth date\n'
          '- NIR (Numéro de Sécurité Sociale) = French 13+2 digit social security number (Carte Vitale)',
    ),
    'IT': CountryIdentifier(
      identifierLabel: 'CF',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Codice Fiscale',
      fhirIdentifierSystem: 'urn:oid:2.16.840.1.113883.2.9.4.3.2',
      dialCode: '39',
      promptHints:
          '- Italian: "Data di nascita" = birth date. "Data di ricovero" = NOT birth date\n'
          '- CF (Codice Fiscale) = Italian 16-char alphanumeric tax/health code. Encodes name, birth date, and gender',
    ),
    'NL': CountryIdentifier(
      identifierLabel: 'BSN',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Burgerservicenummer',
      fhirIdentifierSystem: 'http://fhir.nl/fhir/NamingSystem/bsn',
      dialCode: '31',
      promptHints:
          '- Dutch: "Geboortedatum" = birth date. "Opnamedatum" = NOT birth date\n'
          '- BSN (Burgerservicenummer) = Dutch 9-digit citizen service number',
    ),
    'PL': CountryIdentifier(
      identifierLabel: 'PESEL',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'PESEL',
      fhirIdentifierSystem: 'urn:oid:2.16.840.1.113883.3.4424.1.1.616.1.1.2',
      dialCode: '48',
      promptHints:
          '- Polish: "Data urodzenia" = birth date. "Data przyjęcia" = NOT birth date\n'
          '- PESEL = Polish 11-digit national ID. Encodes birth date and gender',
    ),
    'SE': CountryIdentifier(
      identifierLabel: 'PNR',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'Personnummer',
      fhirIdentifierSystem: 'urn:oid:1.2.752.129.2.1.3.1',
      dialCode: '46',
      promptHints:
          '- Swedish: "Födelsedatum" = birth date. "Inskrivningsdatum" = NOT birth date\n'
          '- Personnummer = Swedish 12-digit personal number (YYYYMMDD-XXXX). Encodes birth date and gender',
    ),
    'CH': CountryIdentifier(
      identifierLabel: 'AHV',
      identifierFhirCode: 'SS',
      identifierDisplayName: 'AHV-Nummer',
      fhirIdentifierSystem: 'urn:oid:2.16.756.5.32',
      dialCode: '41',
      promptHints:
          '- Swiss: "Geburtsdatum" = birth date. "Aufnahmedatum" = NOT birth date\n'
          '- AHV (Alters- und Hinterlassenenversicherung) = Swiss 13-digit social insurance number',
    ),
    'GB': CountryIdentifier(
      identifierLabel: 'NHS',
      identifierFhirCode: 'NH',
      identifierDisplayName: 'NHS Number',
      fhirIdentifierSystem: 'https://fhir.nhs.uk/Id/nhs-number',
      dialCode: '44',
      promptHints:
          '- UK: "Date of Birth" / "DOB" = birth date. "Date of Admission" = NOT birth date\n'
          '- NHS Number = UK 10-digit health service number',
    ),
    'US': CountryIdentifier(
      identifierLabel: 'MRN',
      identifierFhirCode: 'MR',
      identifierDisplayName: 'Medical Record Number',
      fhirIdentifierSystem: 'http://hospital.smarthealthit.org',
      promptHints:
          '- US: "DOB" / "Date of Birth" = birth date. "Admission Date" = NOT birth date\n'
          '- MRN (Medical Record Number) = hospital-assigned patient ID',
    ),
  };

  static const _defaultProfile = CountryIdentifier(
    identifierLabel: 'ID',
    identifierFhirCode: 'MR',
    identifierDisplayName: 'Identifier',
    fhirIdentifierSystem: 'http://healthwallet.me/id',
  );

  static CountryIdentifier forCountry(String? countryCode) {
    if (countryCode == null) return _defaultProfile;
    return _profiles[countryCode.toUpperCase()] ?? _defaultProfile;
  }

  static CountryIdentifier forCurrentLocale() {
    final countryCode =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    return forCountry(countryCode);
  }

  static String defaultIdentifierLabel(String? countryCode) =>
      forCountry(countryCode).identifierLabel;

  static String? labelFromSystem(String system) {
    if (system.isEmpty) return null;
    for (final profile in _profiles.values) {
      if (system.contains(profile.fhirIdentifierSystem)) {
        return profile.identifierLabel;
      }
    }
    return null;
  }
}
