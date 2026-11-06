import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';

/// Decides whether two Patient rows, usually from different sources, are the
/// same person. Hospital record numbers differ from one provider to the
/// next, so they only count within the same system; national identifiers
/// and name with birth date work across providers.
class HolderMatcher {
  const HolderMatcher();

  /// v2-0203 codes of identifiers a country issues once per person: social
  /// security, national health and national person numbers. The app stores
  /// the national numbers it asks for under `SS` or `NH`.
  static const nationalTypes = {'SS', 'NH', 'NI', 'NN', 'SB'};

  /// Shorter values (a bed number, a two-digit test id) match by chance.
  static const _minIdentifierLength = 5;

  bool samePerson(HolderPatient a, HolderPatient b) =>
      sameIdentity(a, b) ||
      (!_differentNationalNumbers(a, b) && _sameNameAndBirthDate(a, b));

  /// Whether [a] and [b] share an identifier that names one person: strong
  /// enough to join two people already in the wallet, which a name and
  /// birth date alone are not.
  bool sameIdentity(HolderPatient a, HolderPatient b) {
    if (_differentNationalNumbers(a, b)) return false;
    // An ID typed in the app takes its system from the device's region, so
    // the same CNP can be stored under two systems; its value is what counts.
    final typed =
        a.sourceId.startsWith(_walletPrefix) &&
        b.sourceId.startsWith(_walletPrefix);
    for (final x in a.identifiers) {
      for (final y in b.identifiers) {
        if (_sameIdentifier(x, y, typed: typed)) return true;
      }
    }
    return false;
  }

  static const _walletPrefix = 'wallet-';

  /// Whether a patient read from a scanned document is [stored]. A scan's
  /// identifier usually has no system, so its value is compared with every
  /// stored identifier but a clinic's own number, which means nothing
  /// without its clinic; one with a system (a clinic's patient number, which
  /// a layout extractor scopes to its clinic) matches only an identifier of
  /// that system. A name counts only with the full birth date on both.
  bool sameScannedPerson(HolderPatient scanned, HolderPatient stored) {
    for (final x in scanned.identifiers) {
      final value = normalize(x.value);
      if (value.length < _minIdentifierLength) continue;
      final system = normalize(x.system);
      if (stored.identifiers.any(
        (y) =>
            y.value != HolderPatient.placeholderRowId &&
            normalize(y.value) == value &&
            (system.isEmpty
                ? !_isClinicScoped(y)
                : normalize(y.system) == system),
      )) {
        return true;
      }
    }
    return _sameNameAndBirthDate(scanned, stored);
  }

  /// Systems of numbers a clinic gives its own patients
  /// (`http://healthwallet.me/clinic/<clinicKey>/patient`): two clinics'
  /// `PA-00001` are two people, so such a number counts only within its
  /// system, even when both rows were saved in the app.
  static const clinicSystemPrefix = 'http://healthwallet.me/clinic/';

  static bool _isClinicScoped(HolderIdentifier id) =>
      id.system.startsWith(clinicSystemPrefix);

  /// The same value, and either the same system, or a national number on
  /// either side (a number that long and unique doesn't recur by chance), or
  /// both [typed] in the app. A clinic's number needs the same system.
  bool _sameIdentifier(
    HolderIdentifier x,
    HolderIdentifier y, {
    bool typed = false,
  }) {
    final value = normalize(x.value);
    if (value.length < _minIdentifierLength || value != normalize(y.value)) {
      return false;
    }
    if (x.value == HolderPatient.placeholderRowId) return false;
    final system = normalize(x.system);
    if (_isClinicScoped(x) || _isClinicScoped(y)) {
      return system == normalize(y.system);
    }
    if (typed || _isNational(x) || _isNational(y)) return true;
    return system.isNotEmpty && system == normalize(y.system);
  }

  /// Two numbers of the same national scheme that differ are two people,
  /// whatever their names say.
  bool _differentNationalNumbers(HolderPatient a, HolderPatient b) {
    for (final x in a.identifiers.where(_isNational)) {
      for (final y in b.identifiers.where(_isNational)) {
        final system = normalize(x.system);
        if (system.isNotEmpty &&
            system == normalize(y.system) &&
            normalize(x.value) != normalize(y.value)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _sameNameAndBirthDate(HolderPatient a, HolderPatient b) {
    final family = normalize(a.family);
    final given = normalize(a.given);
    // Only a full date: "1980" alone is shared by too many people.
    final birthDate = a.birthDate.length >= 10
        ? a.birthDate.substring(0, 10)
        : '';
    return family.isNotEmpty &&
        given.isNotEmpty &&
        birthDate.isNotEmpty &&
        family == normalize(b.family) &&
        given == normalize(b.given) &&
        b.birthDate.length >= 10 &&
        birthDate == b.birthDate.substring(0, 10);
  }

  bool _isNational(HolderIdentifier id) =>
      id.typeCodes.any(nationalTypes.contains);

  /// Whether [identifier] is in [text] as a whole: on its own, or as a run of
  /// digits written with spaces, dashes, dots or slashes ("123 45 6789").
  /// Part of a longer number (a phone number, a date) doesn't count.
  static bool appearsIn(String identifier, String text) {
    final whole = RegExp(
      '(?<![0-9A-Za-z])${RegExp.escape(identifier)}(?![0-9A-Za-z])',
    );
    if (whole.hasMatch(text)) return true;

    final digits = identifier.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return false;
    for (final run in RegExp(r'\d[\d \-./]*\d').allMatches(text)) {
      final found = run.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (found == digits) return true;
      // Long national numbers are often printed without their check digit.
      if (digits.length > 10 &&
          found == digits.substring(0, digits.length - 1)) {
        return true;
      }
    }
    return false;
  }

  /// Lower case, without spaces, dashes or diacritics, so "Ștefan-Ioan" and
  /// "stefan ioan" compare equal, as do "123-45-6789" and "123456789".
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.trim().toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      if (c == ' ' || c == '-') continue;
      buffer.write(_diacritics[c] ?? c);
    }
    return buffer.toString();
  }

  static const _diacritics = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ă': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'đ': 'd',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'þ': 'th',
    'ß': 'ss',
    'ș': 's',
    'ş': 's',
    'ț': 't',
    'ţ': 't',
  };
}
