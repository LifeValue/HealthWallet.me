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
          '- patientIdentifier = the CNP number (13 digits after "CNP:"), NOT "Cod prezentare", "Foie de observatie", or "Nr. fisa"',
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

  /// Words that tell a document's country. An identifier name weighs
  /// [_strongMarker], a field label shared with neighbouring countries
  /// [_weakMarker]. Matched case- and diacritic-insensitively on word
  /// boundaries.
  static const _documentMarkers = <String, (List<String>, List<String>)>{
    'RO': (['CNP', 'Cod Numeric Personal'], ['Data nasterii', 'Data internarii', 'Data externarii', 'Bilet de iesire', 'Buletin de analize', 'Judetul']),
    'DE': (['KVNR', 'Krankenversichertennummer', 'Versichertennummer', 'Versicherten-Nr', 'Krankenkasse'], ['Geburtsdatum', 'Aufnahmedatum', 'Entlassungsbrief', 'Laborbefund', 'Befunddatum']),
    'AT': (['SVNr', 'SV-Nr', 'Sozialversicherungsnummer', 'Österreich'], []),
    'CH': (['AHV', 'AHV-Nr', 'AHV-Nummer', 'Schweiz', 'Suisse', 'Svizzera'], []),
    'ES': (['DNI', 'CIP', 'Tarjeta sanitaria'], ['Fecha de nacimiento', 'Fecha de ingreso', 'Fecha de alta', 'Informe de alta', 'Informe de laboratorio']),
    'FR': (['NIR', 'Securite sociale', 'Carte Vitale'], ['Date de naissance', "Date d'admission", 'Compte rendu']),
    'IT': (['Codice Fiscale', 'Tessera sanitaria'], ['Data di nascita', 'Data di ricovero', 'Lettera di dimissione']),
    'NL': (['BSN', 'Burgerservicenummer'], ['Geboortedatum', 'Opnamedatum', 'Ontslagbrief']),
    'PL': (['PESEL'], ['Data urodzenia', 'Data przyjecia', 'Wypis']),
    'SE': (['Personnummer'], ['Fodelsedatum', 'Inskrivningsdatum', 'Epikris']),
    'GB': (['NHS', 'NHS Number', 'GMC'], []),
    'US': (['MRN', 'SSN', 'Medical Record Number'], ['Date of Birth', 'DOB', 'Admission Date', 'Discharge Date']),
  };

  static const _strongMarker = 3;
  static const _weakMarker = 1;

  static const _diacritics = {
    'ă': 'a', 'â': 'a', 'à': 'a', 'á': 'a', 'ä': 'a', 'å': 'a', 'ą': 'a', //
    'î': 'i', 'í': 'i', 'ì': 'i', 'ï': 'i',
    'ș': 's', 'ş': 's', 'ś': 's', 'ț': 't', 'ţ': 't',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ę': 'e',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ń': 'n', 'ç': 'c', 'ć': 'c', 'ł': 'l', 'ż': 'z', 'ź': 'z', 'ß': 'ss',
  };

  static String _fold(String text) {
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      out.write(_diacritics[char] ?? char);
    }
    return out.toString();
  }

  static final Map<String, List<(RegExp, int)>> _markerPatterns = {
    for (final MapEntry(key: country, value: (strong, weak)) in _documentMarkers.entries)
      country: [
        for (final m in strong) (_markerPattern(m), _strongMarker),
        for (final m in weak) (_markerPattern(m), _weakMarker),
      ],
  };

  static RegExp _markerPattern(String marker) =>
      RegExp('(^|[^a-z0-9])${RegExp.escape(_fold(marker))}(\$|[^a-z0-9])');

  /// The country whose markers score highest in [ocrText]; null when no
  /// marker matches or the best score is shared.
  static String? detectCountry(String ocrText) {
    if (ocrText.trim().isEmpty) return null;
    final folded = _fold(ocrText);
    String? best;
    var bestScore = 0;
    var tie = false;
    for (final MapEntry(key: country, value: patterns) in _markerPatterns.entries) {
      var score = 0;
      for (final (pattern, weight) in patterns) {
        if (pattern.hasMatch(folded)) score += weight;
      }
      if (score > bestScore) {
        best = country;
        bestScore = score;
        tie = false;
      } else if (score == bestScore && score > 0) {
        tie = true;
      }
    }
    return tie ? null : best;
  }

  /// The profile of the country [ocrText] comes from (see [detectCountry]),
  /// else [forCurrentLocale]: a German document on a Romanian phone gets the
  /// German hints.
  static CountryIdentifier forDocument(String ocrText) {
    final country = detectCountry(ocrText);
    return country != null ? forCountry(country) : forCurrentLocale();
  }

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
