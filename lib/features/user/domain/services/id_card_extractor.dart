import 'package:health_wallet/core/config/constants/country_identifier.dart';

class IdCardExtractionResult {
  final String? givenName;
  final String? familyName;
  final String? dateOfBirth;
  final String? gender;
  final String? identifierValue;
  final String? identifierLabel;

  const IdCardExtractionResult({
    this.givenName,
    this.familyName,
    this.dateOfBirth,
    this.gender,
    this.identifierValue,
    this.identifierLabel,
  });

  bool get hasData =>
      (givenName?.isNotEmpty ?? false) ||
      (familyName?.isNotEmpty ?? false) ||
      (identifierValue?.isNotEmpty ?? false);

  IdCardExtractionResult merge(IdCardExtractionResult other) {
    return IdCardExtractionResult(
      givenName: givenName ?? other.givenName,
      familyName: familyName ?? other.familyName,
      dateOfBirth: dateOfBirth ?? other.dateOfBirth,
      gender: gender ?? other.gender,
      identifierValue: identifierValue ?? other.identifierValue,
      identifierLabel: identifierLabel ?? other.identifierLabel,
    );
  }
}

class IdCardExtractor {
  static IdCardExtractionResult extract(String ocrText, String? countryCode) {
    final text = ocrText.replaceAll('\r', '\n');
    var upperCountry = countryCode?.toUpperCase();

    var mrzData = const IdCardExtractionResult();
    final mrzResult = _tryParseMrz(text);
    if (mrzResult != null) {
      mrzData = IdCardExtractionResult(
        familyName: mrzResult.familyName,
        givenName: mrzResult.givenName,
        dateOfBirth: mrzResult.dob,
        gender: mrzResult.gender,
      );
      if (mrzResult.countryCode != null) {
        upperCountry = mrzResult.countryCode;
      }
    }

    final profile = CountryIdentifier.forCountry(upperCountry);

    var result = _extractByCountry(text, upperCountry) ??
        const IdCardExtractionResult();

    result = result.merge(mrzData);

    if (result.familyName == null || result.givenName == null) {
      final standaloneNames = _tryStandaloneUppercaseNames(text);
      if (standaloneNames != null) {
        result = result.merge(IdCardExtractionResult(
          familyName: standaloneNames.familyName,
          givenName: standaloneNames.givenName,
        ));
      }
    }

    if ((result.dateOfBirth == null || result.gender == null) &&
        result.identifierValue != null) {
      final idParsed = _tryDeriveFromIdentifier(
        result.identifierValue!,
        result.identifierLabel,
      );
      if (idParsed != null) {
        result = result.merge(IdCardExtractionResult(
          dateOfBirth: idParsed.dob,
          gender: idParsed.gender,
        ));
      }
    }

    if (result.identifierValue == null || result.identifierValue!.isEmpty) {
      final genericId = _extractGenericIdentifier(text, profile);
      if (genericId != null) {
        result = result.merge(IdCardExtractionResult(
          identifierValue: genericId,
          identifierLabel: profile.identifierLabel,
        ));
      }
    }

    return IdCardExtractionResult(
      givenName: _cleanName(result.givenName),
      familyName: _cleanName(result.familyName),
      dateOfBirth: result.dateOfBirth,
      gender: result.gender,
      identifierValue: result.identifierValue,
      identifierLabel: result.identifierLabel ?? profile.identifierLabel,
    );
  }

  static IdCardExtractionResult? _extractByCountry(
      String text, String? country) {
    switch (country) {
      case 'RO':
        return _extractRomanian(text);
      case 'DE':
        return _extractGerman(text);
      case 'AT':
        return _extractAustrian(text);
      case 'CH':
        return _extractSwiss(text);
      case 'ES':
        return _extractSpanish(text);
      case 'FR':
        return _extractFrench(text);
      case 'IT':
        return _extractItalian(text);
      case 'GB':
        return _extractUK(text);
      case 'NL':
        return _extractDutch(text);
      case 'PL':
        return _extractPolish(text);
      case 'SE':
        return _extractSwedish(text);
      case 'US':
        return _extractUS(text);
      default:
        return _extractGeneric(text);
    }
  }

  static IdCardExtractionResult _extractRomanian(String text) {
    String? cnp;
    final cnpMatch = RegExp(
      r'(?:CNP|Cod\s*Num|Personal\s*No)[:\s.]*(\d{13})',
      caseSensitive: false,
    ).firstMatch(text);
    if (cnpMatch != null) {
      cnp = cnpMatch.group(1);
    } else {
      final digits13 = RegExp(r'\b(\d{13})\b').allMatches(text);
      for (final m in digits13) {
        if (_tryParseCnpFields(m.group(1)!) != null) {
          cnp = m.group(1);
          break;
        }
      }
    }

    String? familyName;
    String? givenName;

    final lines = text.split('\n').map((l) => l.trim()).toList();

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].toLowerCase();
      if (familyName == null &&
          (line.contains('nume') || line.contains('surname') || line.contains('last name') || line.contains('nom')) &&
          !line.contains('prenume') && !line.contains('prenom') && !line.contains('first')) {
        final nextLine = lines[i + 1].trim();
        if (nextLine.isNotEmpty &&
            RegExp(r'^[A-ZÀÂĂÎȘȚ\-\s]{2,}$').hasMatch(nextLine) &&
            !nextLine.contains('PRENUME') && !nextLine.contains('CARTE')) {
          familyName = nextLine;
        }
      }
      if (givenName == null &&
          (line.contains('prenume') || line.contains('prenom') || line.contains('first name') || line.contains('given'))) {
        final nextLine = lines[i + 1].trim();
        if (nextLine.isNotEmpty &&
            RegExp(r'^[A-ZÀÂĂÎȘȚ\-\s]{2,}$').hasMatch(nextLine) &&
            !nextLine.contains('CETAT') && !nextLine.contains('NATION')) {
          givenName = nextLine;
        }
      }
    }

    if (familyName == null || givenName == null) {
      final numePrename = RegExp(
        r'Nume\s*(?:si|și)\s*[Pp]renume[:\s]*([A-ZÀ-Ž][A-ZÀ-Ž\-]+)\s+([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-\s]+)',
        multiLine: true,
      ).firstMatch(text);
      if (numePrename != null) {
        familyName ??= numePrename.group(1);
        givenName ??= numePrename.group(2);
      }
    }

    final sexMatch = RegExp(
      r'(?:Sex)[:\s]*(M|F|masculin|feminin)',
      caseSensitive: false,
    ).firstMatch(text);

    String? dob;
    String? gender;
    if (cnp != null) {
      final parsed = _tryParseCnpFields(cnp);
      if (parsed != null) {
        dob = parsed.dob;
        gender = parsed.gender;
      }
    }
    if (gender == null && sexMatch != null) {
      final val = sexMatch.group(1)!.toUpperCase();
      if (val == 'M' || val.startsWith('MASC')) {
        gender = 'male';
      } else if (val == 'F' || val.startsWith('FEM')) {
        gender = 'female';
      }
    }

    return IdCardExtractionResult(
      familyName: familyName,
      givenName: givenName,
      dateOfBirth: dob,
      gender: gender,
      identifierValue: cnp,
      identifierLabel: 'CNP',
    );
  }

  static IdCardExtractionResult _extractGerman(String text) {
    final nameMatch = RegExp(
      r'(?:Familienname|Name|Nachname)[:\s]*([A-ZÄÖÜa-zäöüß\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final vornameMatch = RegExp(
      r'(?:Vornamen|Vorname)[:\s]*([A-ZÄÖÜa-zäöüß\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Geburtsdatum|Geb\.?\s*Datum)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      multiLine: true,
    ).firstMatch(text);
    final idMatch = RegExp(
      r'(?:Ausweisnummer|Personalausweis)[:\s]*([A-Z0-9]+)',
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    return IdCardExtractionResult(
      familyName: nameMatch?.group(1),
      givenName: vornameMatch?.group(1),
      dateOfBirth: dob,
      identifierValue: idMatch?.group(1),
      identifierLabel: 'KVNR',
    );
  }

  static IdCardExtractionResult _extractAustrian(String text) {
    final nameMatch = RegExp(
      r'(?:Familienname|Name|Nachname)[:\s]*([A-ZÄÖÜa-zäöüß\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final vornameMatch = RegExp(
      r'(?:Vorname|Vornamen)[:\s]*([A-ZÄÖÜa-zäöüß\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Geburtsdatum|Geb\.?\s*Datum)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      multiLine: true,
    ).firstMatch(text);
    final geschlechtMatch = RegExp(
      r'(?:Geschlecht)[:\s]*(M|F|W|männlich|weiblich)',
      caseSensitive: false,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    String? gender;
    if (geschlechtMatch != null) {
      final val = geschlechtMatch.group(1)!.toUpperCase();
      if (val == 'M' || val.startsWith('MÄNN')) {
        gender = 'male';
      } else if (val == 'F' || val == 'W' || val.startsWith('WEIB')) {
        gender = 'female';
      }
    }

    return IdCardExtractionResult(
      familyName: nameMatch?.group(1),
      givenName: vornameMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierLabel: 'SVNr',
    );
  }

  static IdCardExtractionResult _extractSwiss(String text) {
    final nameMatch = RegExp(
      r'(?:Name|Nom|Cognome|Familienname)[/:\s]*([A-ZÀ-Ža-zà-ž\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final vornameMatch = RegExp(
      r'(?:Vorname|Prénom|Nome|Vornamen|Prénoms)[/:\s]*([A-ZÀ-Ža-zà-ž\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Geburtsdatum|Date\s*de\s*naissance|Data\s*di\s*nascita)[/:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    String? gender;
    final genderMatch = RegExp(
      r'(?:Geschlecht|Sexe|Sesso)[/:\s]*(M|F|W|männlich|weiblich|masculin|féminin|maschile|femminile)',
      caseSensitive: false,
    ).firstMatch(text);
    if (genderMatch != null) {
      final val = genderMatch.group(1)!.toUpperCase();
      if (val == 'M' || val.startsWith('MÄNN') || val.startsWith('MASC')) {
        gender = 'male';
      } else if (val == 'F' || val == 'W' || val.startsWith('WEIB') ||
          val.startsWith('FÉM') || val.startsWith('FEMM')) {
        gender = 'female';
      }
    }

    final ahvMatch = RegExp(r'\b(756[.\s]?\d{4}[.\s]?\d{4}[.\s]?\d{2})\b')
        .firstMatch(text);

    return IdCardExtractionResult(
      familyName: nameMatch?.group(1),
      givenName: vornameMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: ahvMatch?.group(1)?.replaceAll(RegExp(r'[\s.]'), ''),
      identifierLabel: 'AHV',
    );
  }

  static IdCardExtractionResult _extractSpanish(String text) {
    final apellidosMatch = RegExp(
      r'(?:APELLIDOS?)[:\s]*([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑa-záéíóúñ\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final nombreMatch = RegExp(
      r'(?:NOMBRE)[:\s]*([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑa-záéíóúñ\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final dniMatch = RegExp(r'(?:DNI|NUM)[:\s]*(\d{8}[A-Z])\b').firstMatch(text) ??
        RegExp(r'\b(\d{8}[A-Z])\b').firstMatch(text);
    final dobMatch = RegExp(
      r'(?:FECHA\s*DE\s*NACIMIENTO|F\.?\s*NACIMIENTO)[:\s]*(\d{2}[.\-/\s]\d{2}[.\-/\s]\d{4})',
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    String? gender;
    final sexoMatch = RegExp(
      r'(?:SEXO)[:\s]*([HMF])\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (sexoMatch != null) {
      final val = sexoMatch.group(1)!.toUpperCase();
      if (val == 'H') {
        gender = 'male';
      } else if (val == 'M') {
        gender = 'female';
      }
    }

    return IdCardExtractionResult(
      familyName: apellidosMatch?.group(1),
      givenName: nombreMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: dniMatch?.group(1),
      identifierLabel: 'CIP',
    );
  }

  static IdCardExtractionResult _extractFrench(String text) {
    final nomMatch = RegExp(
      r'(?:Nom|NOM)(?:/Surname)?[:\s]*([A-ZÀÂÆÇÉÈÊËÏÎÔŒÙÛÜŸ][A-ZÀÂÆÇÉÈÊËÏÎÔŒÙÛÜŸa-zàâæçéèêëïîôœùûüÿ\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final prenomMatch = RegExp(
      r'(?:Prénom|PRENOM|Prénoms?)(?:/Given\s*names?)?[:\s]*([A-ZÀÂÆÇÉÈÊËÏÎÔŒÙÛÜŸ][A-ZÀÂÆÇÉÈÊËÏÎÔŒÙÛÜŸa-zàâæçéèêëïîôœùûüÿ\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final nirMatch = RegExp(
      r'\b([12]\s?\d{2}\s?\d{2}\s?\d{2}\s?\d{3}\s?\d{3}\s?\d{2})\b',
    ).firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Date\s*de\s*naissance|Né\(?e?\)?\s*le)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    String? gender;
    final sexeMatch = RegExp(
      r'(?:Sexe)[:\s]*(M|F|masculin|féminin)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sexeMatch != null) {
      final val = sexeMatch.group(1)!.toUpperCase();
      if (val == 'M' || val.startsWith('MASC')) {
        gender = 'male';
      } else if (val == 'F' || val.startsWith('FÉM')) {
        gender = 'female';
      }
    }
    if (gender == null) {
      if (RegExp(r'\bNé le\b', caseSensitive: false).hasMatch(text)) {
        gender = 'male';
      } else if (RegExp(r'\bNée le\b', caseSensitive: false).hasMatch(text)) {
        gender = 'female';
      }
    }

    String? nirValue = nirMatch?.group(1)?.replaceAll(' ', '');

    return IdCardExtractionResult(
      familyName: nomMatch?.group(1),
      givenName: prenomMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: nirValue,
      identifierLabel: 'NIR',
    );
  }

  static IdCardExtractionResult _extractItalian(String text) {
    final cognomeMatch = RegExp(
      r'(?:COGNOME|Cognome)[:\s]*([A-ZÀÈÉÌÒÙ][A-ZÀÈÉÌÒÙa-zàèéìòù\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final nomeMatch = RegExp(
      r'(?:\bNOME\b|\bNome\b)[:\s]*([A-ZÀÈÉÌÒÙ][A-ZÀÈÉÌÒÙa-zàèéìòù\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final cfMatch = RegExp(r'\b([A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z])\b')
        .firstMatch(text);

    String? dob;
    final luogoDataMatch = RegExp(
      r'(?:Luogo\s*e\s*data\s*di\s*nascita)[:\s]*(?:[A-Za-zÀ-ž\s]+\s)?(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    final natoMatch = RegExp(
      r'(?:NATO/?A\s*IL|NATA/?O\s*IL)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    final dataNascitaMatch = RegExp(
      r'(?:Data\s*di\s*nascita)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);

    final dobRaw = luogoDataMatch?.group(1) ??
        natoMatch?.group(1) ??
        dataNascitaMatch?.group(1);
    if (dobRaw != null) {
      dob = _parseEuropeanDate(dobRaw);
    }

    String? gender;
    final sessoMatch = RegExp(
      r'(?:Sesso)[:\s]*(M|F)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sessoMatch != null) {
      gender = sessoMatch.group(1)!.toUpperCase() == 'M' ? 'male' : 'female';
    }
    if (gender == null) {
      if (RegExp(r'\bNATO\s*IL\b', caseSensitive: false).hasMatch(text)) {
        gender = 'male';
      } else if (RegExp(r'\bNATA\s*IL\b', caseSensitive: false).hasMatch(text)) {
        gender = 'female';
      }
    }

    if (cfMatch != null && (dob == null || gender == null)) {
      final cfParsed = _tryParseCodiceFiscale(cfMatch.group(1)!);
      if (cfParsed != null) {
        dob ??= cfParsed.dob;
        gender ??= cfParsed.gender;
      }
    }

    return IdCardExtractionResult(
      familyName: cognomeMatch?.group(1),
      givenName: nomeMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: cfMatch?.group(1),
      identifierLabel: 'CF',
    );
  }

  static IdCardExtractionResult _extractUK(String text) {
    final surnameMatch = RegExp(
      r'(?:Surname|SURNAME|LN)[:\s]*([A-Z][A-Za-z\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final forenamesMatch = RegExp(
      r'(?:Forenames?|Given\s*names?|FORENAMES?|FN)[:\s]*([A-Z][A-Za-z\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final nhsMatch = RegExp(r'\b(\d{3}\s?\d{3}\s?\d{4})\b').firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Date\s*of\s*[Bb]irth|DOB)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    String? gender;
    final sexMatch = RegExp(
      r'(?:Sex)[:\s]*(M|F|Male|Female)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sexMatch != null) {
      final val = sexMatch.group(1)!.toUpperCase();
      if (val == 'M' || val == 'MALE') {
        gender = 'male';
      } else if (val == 'F' || val == 'FEMALE') {
        gender = 'female';
      }
    }

    return IdCardExtractionResult(
      familyName: surnameMatch?.group(1),
      givenName: forenamesMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: nhsMatch?.group(1)?.replaceAll(' ', ''),
      identifierLabel: 'NHS',
    );
  }

  static IdCardExtractionResult _extractDutch(String text) {
    final achternaamMatch = RegExp(
      r'(?:Achternaam|Naam|NAAM)[:\s]*([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final voornaamMatch = RegExp(
      r'(?:Voorna(?:a)?men?|VOORNA(?:A)?MEN?)[:\s]*([A-ZÀ-Ž][A-ZÀ-Ža-zà-ž\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final bsnMatch = RegExp(
      r'(?:Burgerservicenummer|BSN)[/:\s]*(\d{9})\b',
      caseSensitive: false,
    ).firstMatch(text) ??
        RegExp(r'\b(\d{9})\b').firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Geboortedatum|Geb\.?\s*datum)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    String? gender;
    final geslachtMatch = RegExp(
      r'(?:Geslacht)[:\s]*(M|V|Man|Vrouw)',
      caseSensitive: false,
    ).firstMatch(text);
    if (geslachtMatch != null) {
      final val = geslachtMatch.group(1)!.toUpperCase();
      if (val == 'M' || val == 'MAN') {
        gender = 'male';
      } else if (val == 'V' || val == 'VROUW') {
        gender = 'female';
      }
    }

    return IdCardExtractionResult(
      familyName: achternaamMatch?.group(1),
      givenName: voornaamMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: bsnMatch?.group(1),
      identifierLabel: 'BSN',
    );
  }

  static IdCardExtractionResult _extractPolish(String text) {
    final nazwiskoMatch = RegExp(
      r'(?:Nazwisko|NAZWISKO)[:\s]*([A-ZĄĆĘŁŃÓŚŹŻ][A-ZĄĆĘŁŃÓŚŹŻa-ząćęłńóśźż\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final imieMatch = RegExp(
      r'(?:Imiona|IMIONA|Imi(?:ę|e)|IMIĘ)[:\s]*([A-ZĄĆĘŁŃÓŚŹŻ][A-ZĄĆĘŁŃÓŚŹŻa-ząćęłńóśźż\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final peselMatch = RegExp(
      r'(?:PESEL)[:\s]*(\d{11})\b',
      caseSensitive: false,
    ).firstMatch(text) ??
        RegExp(r'\b(\d{11})\b').firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Data\s*urodzenia)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    String? gender;

    if (peselMatch != null) {
      final pesel = peselMatch.group(1)!;
      final parsed = _tryParsePeselFields(pesel);
      if (parsed != null) {
        dob = parsed.dob;
        gender = parsed.gender;
      }
    }

    if (gender == null) {
      final plecMatch = RegExp(
        r'(?:Płeć|PŁEĆ|Plec|PLEC)[:\s]*(M|K)',
        caseSensitive: false,
      ).firstMatch(text);
      if (plecMatch != null) {
        gender = plecMatch.group(1)!.toUpperCase() == 'M' ? 'male' : 'female';
      }
    }

    if (dob == null && dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    return IdCardExtractionResult(
      familyName: nazwiskoMatch?.group(1),
      givenName: imieMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: peselMatch?.group(1),
      identifierLabel: 'PESEL',
    );
  }

  static IdCardExtractionResult _extractSwedish(String text) {
    final efternamnMatch = RegExp(
      r'(?:Efternamn|EFTERNAMN)[:\s]*([A-ZÅÄÖ][A-ZÅÄÖa-zåäö\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final fornamnMatch = RegExp(
      r'(?:Förnamn|FÖRNAMN)[:\s]*([A-ZÅÄÖ][A-ZÅÄÖa-zåäö\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final pnrMatch = RegExp(r'\b(\d{8}[-]?\d{4})\b').firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Födelsedatum)[:\s]*(\d{4}[.\-/]\d{2}[.\-/]\d{2})',
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    String? gender;

    if (pnrMatch != null) {
      final pnr = pnrMatch.group(1)!.replaceAll('-', '');
      if (pnr.length == 12) {
        final y = pnr.substring(0, 4);
        final m = pnr.substring(4, 6);
        final d = pnr.substring(6, 8);
        dob = '$y-$m-$d';
        final genderDigit = int.tryParse(pnr[10]);
        if (genderDigit != null) {
          gender = genderDigit.isOdd ? 'male' : 'female';
        }
      }
    }

    if (gender == null) {
      final konMatch = RegExp(
        r'(?:Kön|KÖN)[:\s]*(M|K)',
        caseSensitive: false,
      ).firstMatch(text);
      if (konMatch != null) {
        gender = konMatch.group(1)!.toUpperCase() == 'M' ? 'male' : 'female';
      }
    }

    if (dob == null && dobMatch != null) {
      final parts = dobMatch.group(1)!.split(RegExp(r'[.\-/]'));
      if (parts.length == 3) {
        dob = '${parts[0]}-${parts[1]}-${parts[2]}';
      }
    }

    return IdCardExtractionResult(
      familyName: efternamnMatch?.group(1),
      givenName: fornamnMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierValue: pnrMatch?.group(1),
      identifierLabel: 'PNR',
    );
  }

  static IdCardExtractionResult _extractUS(String text) {
    final surnameMatch = RegExp(
      r'(?:Surname|Last\s*Name|LN)[:\s]*([A-Z][A-Za-z\-]+)',
      multiLine: true,
    ).firstMatch(text);
    final givenMatch = RegExp(
      r'(?:Given\s*Names?|First\s*Name|FN)[:\s]*([A-Z][A-Za-z\-\s]+)',
      multiLine: true,
    ).firstMatch(text);
    final dobMatch = RegExp(
      r'(?:Date\s*of\s*[Bb]irth|DOB)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      multiLine: true,
    ).firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      final parts = dobMatch.group(1)!.split(RegExp(r'[.\-/]'));
      if (parts.length == 3) {
        if (parts[2].length == 4) {
          dob = '${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
        }
      }
    }

    String? gender;
    final sexMatch = RegExp(
      r'(?:Sex|SEX)[:\s]*(M|F|Male|Female)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sexMatch != null) {
      final val = sexMatch.group(1)!.toUpperCase();
      if (val == 'M' || val == 'MALE') {
        gender = 'male';
      } else if (val == 'F' || val == 'FEMALE') {
        gender = 'female';
      }
    }

    return IdCardExtractionResult(
      familyName: surnameMatch?.group(1),
      givenName: givenMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
      identifierLabel: 'MRN',
    );
  }

  static IdCardExtractionResult _extractGeneric(String text) {
    final namePatterns = [
      RegExp(
        r'(?:Name|Surname|Last\s*Name|Family\s*Name)[:\s]*([A-Z][A-Za-z\-]+)',
        multiLine: true,
      ),
      RegExp(
        r'(?:First\s*Name|Given\s*Names?|Forenames?)[:\s]*([A-Z][A-Za-z\-\s]+)',
        multiLine: true,
      ),
    ];
    final dobPattern = RegExp(
      r'(?:Date\s*of\s*[Bb]irth|DOB|Born)[:\s]*(\d{2}[.\-/]\d{2}[.\-/]\d{4})',
      multiLine: true,
    );

    final familyMatch = namePatterns[0].firstMatch(text);
    final givenMatch = namePatterns[1].firstMatch(text);
    final dobMatch = dobPattern.firstMatch(text);

    String? dob;
    if (dobMatch != null) {
      dob = _parseEuropeanDate(dobMatch.group(1)!);
    }

    String? gender;
    final sexMatch = RegExp(
      r'(?:Sex|Gender)[:\s]*(M|F|Male|Female)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sexMatch != null) {
      final val = sexMatch.group(1)!.toUpperCase();
      if (val == 'M' || val == 'MALE') {
        gender = 'male';
      } else if (val == 'F' || val == 'FEMALE') {
        gender = 'female';
      }
    }

    return IdCardExtractionResult(
      familyName: familyMatch?.group(1),
      givenName: givenMatch?.group(1),
      dateOfBirth: dob,
      gender: gender,
    );
  }

  static String? _extractGenericIdentifier(
      String text, CountryIdentifier profile) {
    final labelPattern = RegExp(
      '${RegExp.escape(profile.identifierLabel)}[:\\s]*(\\S+)',
      caseSensitive: false,
    );
    final match = labelPattern.firstMatch(text);
    return match?.group(1);
  }

  static String? _parseEuropeanDate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '');
    final parts = cleaned.split(RegExp(r'[.\-/]'));
    if (parts.length != 3) return null;

    final d = parts[0].padLeft(2, '0');
    final m = parts[1].padLeft(2, '0');
    final y = parts[2];

    if (y.length != 4) return null;
    return '$y-$m-$d';
  }

  static _CnpFields? _tryParseCnpFields(String cnp) {
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

    return _CnpFields(dob: dob, gender: gender);
  }

  static _CnpFields? _tryParsePeselFields(String pesel) {
    if (pesel.length != 11 || !RegExp(r'^\d{11}$').hasMatch(pesel)) {
      return null;
    }

    var yy = int.parse(pesel.substring(0, 2));
    var mm = int.parse(pesel.substring(2, 4));
    final dd = int.parse(pesel.substring(4, 6));

    int century;
    if (mm > 80) {
      century = 1800;
      mm -= 80;
    } else if (mm > 60) {
      century = 2200;
      mm -= 60;
    } else if (mm > 40) {
      century = 2100;
      mm -= 40;
    } else if (mm > 20) {
      century = 2000;
      mm -= 20;
    } else {
      century = 1900;
    }

    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    final year = century + yy;
    final dob =
        '$year-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
    final genderDigit = int.parse(pesel[9]);
    final gender = genderDigit.isOdd ? 'male' : 'female';

    return _CnpFields(dob: dob, gender: gender);
  }

  static _CnpFields? _tryParseCodiceFiscale(String cf) {
    if (cf.length != 16) return null;

    const monthMap = {
      'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'H': 6,
      'L': 7, 'M': 8, 'P': 9, 'R': 10, 'S': 11, 'T': 12,
    };

    final yyStr = cf.substring(6, 8);
    final monthChar = cf[8].toUpperCase();
    final dayStr = cf.substring(9, 11);

    final yy = int.tryParse(yyStr);
    final month = monthMap[monthChar];
    var day = int.tryParse(dayStr);

    if (yy == null || month == null || day == null) return null;

    String gender;
    if (day > 40) {
      gender = 'female';
      day -= 40;
    } else {
      gender = 'male';
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final year = yy > 50 ? 1900 + yy : 2000 + yy;
    final dob =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    return _CnpFields(dob: dob, gender: gender);
  }

  static _MrzResult? _tryParseMrz(String text) {
    final normalized = text
        .replaceAll('«', '<')
        .replaceAll('\u00AB', '<')
        .replaceAll('\u00BB', '<');

    final td3Result = _tryParseTd3Mrz(normalized);
    if (td3Result != null) return td3Result;

    final td1Result = _tryParseTd1Mrz(normalized);
    if (td1Result != null) return td1Result;

    return null;
  }

  static _MrzResult? _tryParseTd3Mrz(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    String? line1;
    String? line2;

    for (int i = 0; i < lines.length; i++) {
      final cleaned = lines[i].replaceAll(' ', '');
      if (cleaned.length >= 40 && RegExp(r'^P[<A-Z]').hasMatch(cleaned)) {
        line1 = cleaned;
        if (i + 1 < lines.length) {
          final next = lines[i + 1].replaceAll(' ', '');
          if (next.length >= 40 && RegExp(r'^[A-Z0-9<]').hasMatch(next)) {
            line2 = next;
          }
        }
        break;
      }
    }

    if (line1 == null) return null;

    final nameSection = line1.length > 5 ? line1.substring(5) : '';
    final nameParts = nameSection.split('<<');
    if (nameParts.length < 2) return null;

    final surname = nameParts[0].replaceAll('<', ' ').trim();
    final given = nameParts.sublist(1).join(' ').replaceAll('<', ' ').trim();

    if (surname.isEmpty || given.isEmpty) return null;
    if (surname.length < 2 || given.length < 2) return null;

    String? dob;
    String? gender;
    String? nationality;

    final issuingCountry = line1.length >= 5
        ? line1.substring(2, 5).replaceAll('<', '')
        : null;

    if (line2 != null && line2.length >= 20) {
      if (line2.length >= 13) {
        nationality = line2.substring(10, 13).replaceAll('<', '');
      }

      final dobRaw = line2.length >= 19 ? line2.substring(13, 19) : null;
      if (dobRaw != null && RegExp(r'^\d{6}$').hasMatch(dobRaw)) {
        dob = _parseMrzDate(dobRaw);
      }

      if (line2.length >= 21) {
        final sexChar = line2[20];
        if (sexChar == 'M') {
          gender = 'male';
        } else if (sexChar == 'F') {
          gender = 'female';
        }
      }
    }

    final detectedCountry = _mrzCountryToIso2(nationality ?? issuingCountry);

    return _MrzResult(
      familyName: _titleCase(surname),
      givenName: _titleCase(given),
      dob: dob,
      gender: gender,
      countryCode: detectedCountry,
    );
  }

  static _MrzResult? _tryParseTd1Mrz(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    final List<String> mrzLines = [];
    for (final line in lines) {
      final cleaned = line.replaceAll(' ', '');
      if (cleaned.length >= 28 &&
          cleaned.length <= 34 &&
          RegExp(r'^[A-Z0-9<]{28,34}$').hasMatch(cleaned)) {
        mrzLines.add(cleaned);
      }
    }

    if (mrzLines.length < 3) return null;

    final td1Line2 = mrzLines[1];
    final td1Line3 = mrzLines[2];

    final nameParts = td1Line3.split('<<');
    if (nameParts.length < 2) return null;

    final surname = nameParts[0].replaceAll('<', ' ').trim();
    final given = nameParts.sublist(1).join(' ').replaceAll('<', ' ').trim();

    if (surname.isEmpty || given.isEmpty) return null;
    if (surname.length < 2 || given.length < 2) return null;

    String? dob;
    String? gender;

    if (td1Line2.length >= 7) {
      final dobRaw = td1Line2.substring(0, 6);
      if (RegExp(r'^\d{6}$').hasMatch(dobRaw)) {
        dob = _parseMrzDate(dobRaw);
      }
    }

    if (td1Line2.length >= 8) {
      final sexChar = td1Line2[7];
      if (sexChar == 'M') {
        gender = 'male';
      } else if (sexChar == 'F') {
        gender = 'female';
      }
    }

    String? nationality;
    final td1Line1 = mrzLines[0];
    if (td1Line1.length >= 5) {
      nationality = td1Line1.substring(2, 5).replaceAll('<', '');
    }
    if (td1Line2.length >= 18) {
      final nat2 = td1Line2.substring(15, 18).replaceAll('<', '');
      if (nat2.isNotEmpty) nationality = nat2;
    }

    return _MrzResult(
      familyName: _titleCase(surname),
      givenName: _titleCase(given),
      dob: dob,
      gender: gender,
      countryCode: _mrzCountryToIso2(nationality),
    );
  }

  static String? _mrzCountryToIso2(String? mrzCode) {
    if (mrzCode == null || mrzCode.isEmpty) return null;
    const map = {
      'ROU': 'RO', 'DEU': 'DE', 'AUT': 'AT', 'ESP': 'ES',
      'FRA': 'FR', 'ITA': 'IT', 'GBR': 'GB', 'NLD': 'NL',
      'POL': 'PL', 'SWE': 'SE', 'CHE': 'CH', 'USA': 'US',
      'D': 'DE',
    };
    return map[mrzCode] ?? (mrzCode.length == 2 ? mrzCode : null);
  }

  static String? _parseMrzDate(String yymmdd) {
    if (yymmdd.length != 6) return null;
    final yy = int.tryParse(yymmdd.substring(0, 2));
    final mm = int.tryParse(yymmdd.substring(2, 4));
    final dd = int.tryParse(yymmdd.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;

    final year = yy > 50 ? 1900 + yy : 2000 + yy;
    return '$year-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
  }

  static _MrzResult? _tryStandaloneUppercaseNames(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final countryIdx = lines.indexWhere((l) =>
        RegExp(r'^(ROMÂNIA|ROMANIA|DEUTSCHLAND|BUNDESREPUBLIK|REPUBLIQUE|REPUBBLICA|KINGDOM|KONINKRIJK|RZECZPOSPOLITA|SVERIGE|SCHWEIZ|SUISSE|ESPAÑA|UNITED\s*STATES)', caseSensitive: false)
            .hasMatch(l));

    if (countryIdx < 0) return null;

    String? familyName;
    String? givenName;

    for (int i = countryIdx + 1; i < lines.length && i < countryIdx + 12; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length < 2) continue;
      if (RegExp(r'^[A-ZÀÂĂÎȘȚÄÖÜÅÉÈÊËÏÎÔŒÙÛÜŸÁÍÓÚÑĄĆĘŁŃÓŚŹŻÆØ\- ]{2,}$')
              .hasMatch(line) &&
          !RegExp(
            r'^(ROMÂNĂ|ROU|ROMANĂ|CARTE|PASAPORT|PASSPORT|PASSEPORT|IDENTITY|CARD|PE|BULETIN|REISEPASS|PERSONALAUSWEIS|REPUBLICA|REPUBLIC|FEDERATION|DOCUMENT|NATIONAL|EUROPÄISCHE|UNION|EUROPEENNE|EUROPEA|TYPE|TIPO|TIPO|NOV|DEC|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT)$',
            caseSensitive: false,
          ).hasMatch(line) &&
          !RegExp(r'^\d').hasMatch(line)) {
        if (familyName == null) {
          familyName = line;
        } else if (givenName == null) {
          givenName = line;
          break;
        }
      }
    }

    if (familyName == null || givenName == null) return null;

    return _MrzResult(
      familyName: _titleCase(familyName),
      givenName: _titleCase(givenName),
    );
  }

  static _CnpFields? _tryDeriveFromIdentifier(
      String idValue, String? idLabel) {
    switch (idLabel) {
      case 'CNP':
        return _tryParseCnpFields(idValue);
      case 'PESEL':
        return _tryParsePeselFields(idValue);
      case 'PNR':
        final pnr = idValue.replaceAll('-', '');
        if (pnr.length == 12) {
          final y = pnr.substring(0, 4);
          final m = pnr.substring(4, 6);
          final d = pnr.substring(6, 8);
          final genderDigit = int.tryParse(pnr[10]);
          String? gender;
          if (genderDigit != null) {
            gender = genderDigit.isOdd ? 'male' : 'female';
          }
          return _CnpFields(dob: '$y-$m-$d', gender: gender ?? 'male');
        }
        return null;
      case 'CF':
        return _tryParseCodiceFiscale(idValue);
      default:
        return null;
    }
  }

  static String _titleCase(String input) {
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String? _cleanName(String? name) {
    if (name == null || name.isEmpty) return null;
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _MrzResult {
  final String familyName;
  final String givenName;
  final String? dob;
  final String? gender;
  final String? countryCode;
  const _MrzResult({
    required this.familyName,
    required this.givenName,
    this.dob,
    this.gender,
    this.countryCode,
  });
}

class _CnpFields {
  final String dob;
  final String gender;
  const _CnpFields({required this.dob, required this.gender});
}
