import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/user/domain/services/id_card_extractor.dart';

void main() {
  // Made-up card text, laid out the way OCR returns a Romanian identity card.
  const romanianCard = '''ROMANIA ROUMANIE ROMANIA
CARTE DE IDENTITATE
IDENTITY CARD
SERIA TM NR 123456
CNP 1650812350142
Nume/Nom/Last name
DUMITRESCU
Prenume/Prenom/First name
ANDREI
Cetatenie/Nationalite/Nationality
Romana / ROU''';

  group('IdCardExtractor issuing country', () {
    test('reads a Romanian card on a phone set to the US', () {
      final result = IdCardExtractor.extract(romanianCard, 'US');

      expect(result.identifierValue, '1650812350142');
      expect(result.identifierLabel, 'CNP');
      expect(result.dateOfBirth, '1965-08-12');
      expect(result.gender, 'male');
      expect(result.familyName, 'DUMITRESCU');
      expect(result.givenName, 'ANDREI');
    });

    test('reads a Romanian card when no country is configured', () {
      final result = IdCardExtractor.extract(romanianCard, null);

      expect(result.identifierValue, '1650812350142');
      expect(result.identifierLabel, 'CNP');
    });

    test('reads a German card on a phone set to Romania', () {
      const germanCard = '''BUNDESREPUBLIK DEUTSCHLAND
PERSONALAUSWEIS
Name MUSTERMANN
Vornamen ERIKA
Geburtsdatum 12.08.1964''';

      final result = IdCardExtractor.extract(germanCard, 'RO');

      expect(result.familyName, 'MUSTERMANN');
      expect(result.dateOfBirth, '1964-08-12');
      expect(result.identifierLabel, isNot('CNP'));
    });

    test('falls back to the configured country when the card names none', () {
      const unlabelledCard = '''1650812350142
DUMITRESCU ANDREI''';

      final result = IdCardExtractor.extract(unlabelledCard, 'RO');

      expect(result.identifierValue, '1650812350142');
      expect(result.identifierLabel, 'CNP');
    });
  });
}
