import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';

/// The default holder no one has named yet.
const _unnamed = Patient(
  id: 'p-me',
  rawResource: {
    'name': [
      {
        'family': 'Holder',
        'given': ['Health Wallet'],
      },
    ],
    'identifier': [
      {'value': 'default_patient'},
    ],
  },
);

const _stored = Patient(
  id: 'p-ana',
  rawResource: {
    'name': [
      {
        'family': 'Pop',
        'given': ['Ana'],
      },
    ],
  },
);

const _scanned = MappingPatient(
  id: 'p-scan',
  givenName: MappedProperty(value: 'Alexandru'),
  familyName: MappedProperty(value: 'Szilagyi'),
);

const _nameless = MappingPatient(
  id: 'p-none',
  dateOfBirth: MappedProperty(value: '1990-02-19'),
);

void main() {
  group('the unnamed user', () {
    const you = StagedPatient(
      existing: _unnamed,
      draft: _scanned,
      mode: ImportMode.linkExisting,
    );

    test('shows the document\'s details, never the default name', () {
      expect(you.review, PatientReview.you);
      expect(you.shown, _scanned);
      expect(you.canSwap, isTrue);
      expect(you.needsName, isFalse);
    });

    test('without a patient in the document, shows empty fields under the '
        'holder\'s id', () {
      const empty = StagedPatient(
        existing: _unnamed,
        mode: ImportMode.linkExisting,
      );

      expect(empty.review, PatientReview.you);
      expect(empty.shown.id, 'p-me');
      expect(empty.shown.isIdentified, isFalse);
    });

    test('swaps to a new person with the same details, and back', () {
      final someoneElse = you.swapped;

      expect(someoneElse.mode, ImportMode.createNew);
      expect(someoneElse.draft, _scanned);
      expect(someoneElse.review, PatientReview.newPerson);
      expect(someoneElse.canSwap, isTrue);
      expect(someoneElse.swapped, you);
    });

    test('swapped with empty fields, becomes a new person who needs a name '
        'and does not take the holder\'s id', () {
      const empty = StagedPatient(
        existing: _unnamed,
        mode: ImportMode.linkExisting,
      );

      final someoneElse = empty.swapped;

      expect(someoneElse.review, PatientReview.unidentified);
      expect(someoneElse.draft!.id, isNot(anyOf('', 'p-me')));
      expect(someoneElse.needsName, isTrue);
    });
  });

  group('someone in the wallet', () {
    test('as they are, shows their details and cannot be swapped', () {
      const linked = StagedPatient(
        existing: _stored,
        mode: ImportMode.linkExisting,
      );

      expect(linked.review, PatientReview.existing);
      expect(linked.shown, MappingPatient.fromFhirResource(_stored));
      expect(linked.canSwap, isFalse);
    });

    test('edited, shows the edits', () {
      final edited = StagedPatient(
        existing: _stored,
        draft: MappingPatient.fromFhirResource(
          _stored,
        ).copyWithMap({'givenName': 'Anna'}) as MappingPatient,
        mode: ImportMode.linkExisting,
      );

      expect(edited.review, PatientReview.existingEdited);
      expect(edited.shown.givenName.value, 'Anna');
    });

    test('picked instead of the document\'s patient, shows them and swaps '
        'back to the document\'s patient', () {
      const changed = StagedPatient(
        existing: _stored,
        draft: _scanned,
        mode: ImportMode.linkExisting,
      );

      expect(changed.review, PatientReview.changedTo);
      expect(changed.shown, MappingPatient.fromFhirResource(_stored));
      expect(changed.swapped.draft, _scanned);
      expect(changed.swapped.mode, ImportMode.createNew);
    });
  });

  group('a new person', () {
    test('named by the document can be saved', () {
      const named = StagedPatient(draft: _scanned);

      expect(named.review, PatientReview.newPerson);
      expect(named.canSwap, isFalse);
      expect(named.needsName, isFalse);
    });

    test('the document does not name needs a name first', () {
      const nameless = StagedPatient(draft: _nameless);

      expect(nameless.review, PatientReview.unidentified);
      expect(nameless.needsName, isTrue);
    });
  });
}
