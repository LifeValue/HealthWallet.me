import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_patient.dart';
import 'package:health_wallet/features/holders/domain/entity/holder_snapshot.dart';
import 'package:health_wallet/features/holders/domain/services/holder_linker.dart';

const ssn = HolderIdentifier(
  system: 'http://hl7.org/fhir/sid/us-ssn',
  value: '123-45-6789',
  typeCodes: {'SS'},
);

HolderIdentifier mrn(String system, String value) =>
    HolderIdentifier(system: system, value: value, typeCodes: const {'MR'});

HolderPatient patient(
  String rowId,
  String sourceId, {
  String? resourceId,
  List<HolderIdentifier> identifiers = const [],
  String family = '',
  String given = '',
  String birthDate = '',
}) => HolderPatient(
  rowId: rowId,
  resourceId: resourceId ?? rowId,
  sourceId: sourceId,
  identifiers: identifiers,
  family: family,
  given: given,
  birthDate: birthDate,
);

const placeholder = HolderPatient(
  rowId: 'default_patient',
  resourceId: 'f3a1',
  sourceId: 'wallet-default_patient',
  identifiers: [
    HolderIdentifier(
      system: 'urn:oid:2.16.840.1.113883.4.1',
      value: 'default_patient',
      typeCodes: {'SS'},
    ),
  ],
  family: 'Holder',
  given: 'Health Wallet',
);

Map<String, String> link(
  List<HolderSource> sources,
  List<HolderPatient> patients, [
  Map<String, Set<String>> references = const {},
]) => const HolderLinker().link(
  HolderSnapshot(
    sources: sources,
    patients: patients,
    references: references,
  ),
);

void main() {
  test('the unnamed default holder and the first provider patient are one '
      'person, named after the wallet patient', () {
    expect(
      link(
        const [HolderSource('wallet-default_patient'), HolderSource('epic')],
        [
          placeholder,
          patient(
            'p1',
            'epic',
            identifiers: [mrn('http://hospital-a/mrn', '55501')],
            family: 'Doe',
            given: 'Jane',
          ),
        ],
      ),
      {'wallet-default_patient': 'default_patient', 'epic': 'default_patient'},
    );
  });

  test('two providers with the same national number and different record '
      'numbers are one person', () {
    final links = link(
      const [HolderSource('a'), HolderSource('b')],
      [
        patient('pa', 'a', identifiers: [mrn('http://a/mrn', '55501'), ssn]),
        patient(
          'pb',
          'b',
          identifiers: [
            mrn('http://b/mrn', '90012'),
            const HolderIdentifier(
              system: 'urn:oid:2.16.840.1.113883.4.1',
              value: '123456789',
              typeCodes: {'SS'},
            ),
          ],
        ),
      ],
    );
    expect(links, {'a': 'pa', 'b': 'pa'});
  });

  test('the same name and full birth date join; a year alone does not', () {
    HolderPatient jane(String id, String date) => patient(
      id,
      id,
      family: 'Popescu',
      given: 'Ștefan-Ioan',
      birthDate: date,
    );
    expect(
      link(
        const [HolderSource('a'), HolderSource('b')],
        [
          jane('a', '1980-04-02'),
          patient(
            'b',
            'b',
            family: 'POPESCU',
            given: 'stefan ioan',
            birthDate: '1980-04-02',
          ),
        ],
      ).values.toSet(),
      {'a'},
    );
    expect(
      link(
        const [HolderSource('a'), HolderSource('b')],
        [
          jane('a', '1980'),
          jane('b', '1980'),
        ],
      ).values.toSet(),
      {'a', 'b'},
    );
  });

  test('different national numbers keep two people with the same name and '
      'birth date apart', () {
    HolderPatient twin(String id, String number) => patient(
      id,
      id,
      identifiers: [
        HolderIdentifier(
          system: 'urn:oid:1.2.3',
          value: number,
          typeCodes: const {'NI'},
        ),
      ],
      family: 'Doe',
      given: 'Alex',
      birthDate: '1990-01-01',
    );
    expect(
      link(
        const [HolderSource('a'), HolderSource('b')],
        [
          twin('a', '1900101123'),
          twin('b', '1900101456'),
        ],
      ).values.toSet(),
      {'a', 'b'},
    );
  });

  test('record numbers count only within the same system, and short ones '
      'not at all', () {
    expect(
      link(
        const [HolderSource('a'), HolderSource('b')],
        [
          patient('a', 'a', identifiers: [mrn('http://a/mrn', '55501')]),
          patient('b', 'b', identifiers: [mrn('http://b/mrn', '55501')]),
        ],
      ).values.toSet(),
      {'a', 'b'},
    );
    expect(
      link(
        const [HolderSource('a'), HolderSource('b')],
        [
          patient('a', 'a', identifiers: [mrn('http://x/mrn', '12')]),
          patient('b', 'b', identifiers: [mrn('http://x/mrn', '12')]),
        ],
      ).values.toSet(),
      {'a', 'b'},
    );
  });

  test('a wallet source joins the patient it was made for, by row id or FHIR '
      'id, with or without a Patient row of its own', () {
    final links = link(
      const [
        HolderSource('epic'),
        HolderSource('wallet-fhir-1'),
        HolderSource('wallet-epic/Patient/1'),
      ],
      [
        patient('epic/Patient/1', 'epic', resourceId: 'fhir-1'),
        // An edited copy whose identifier was corrected.
        patient(
          'wallet-fhir-1_9c2',
          'wallet-fhir-1',
          identifiers: [mrn('http://healthwallet.me/id', '77777')],
        ),
      ],
    );
    expect(links.values.toSet(), {'wallet-fhir-1_9c2'});
    expect(links.length, 3);
  });

  test('a source without patients joins the one its records refer to, '
      'matched on the whole id', () {
    final links = link(
      const [HolderSource('a'), HolderSource('b'), HolderSource('labs')],
      [patient('12', 'a'), patient('123', 'b')],
      {
        'labs': {'Patient/123'},
      },
    );
    expect(links['labs'], '123');
  });

  test('a source referring to two people, or to no one while the wallet has '
      'several, stays unlinked; with one person it joins them', () {
    final two = link(
      const [
        HolderSource('a'),
        HolderSource('b'),
        HolderSource('mixed'),
        HolderSource('wallet-patient-default'),
      ],
      [patient('pa', 'a'), patient('pb', 'b')],
      {
        'mixed': {'Patient/pa', 'Patient/pb'},
      },
    );
    expect(two.keys, unorderedEquals(['a', 'b']));

    expect(
      link(
        const [HolderSource('a'), HolderSource('wallet-patient-default')],
        [patient('pa', 'a')],
      ),
      {'a': 'pa', 'wallet-patient-default': 'pa'},
    );
  });

  test('the demo patient is someone else: the default holder stays itself '
      'next to it, and still joins a provider patient', () {
    final demo = patient(
      'demo-patient',
      'demo_data',
      family: 'Demo',
      given: 'Ana',
    );
    expect(
      link(
        const [
          HolderSource('wallet-default_patient'),
          HolderSource('demo_data'),
        ],
        [placeholder, demo],
      ),
      {
        'wallet-default_patient': 'default_patient',
        'demo_data': 'demo-patient',
      },
    );
    expect(
      link(
        const [
          HolderSource('wallet-default_patient'),
          HolderSource('demo_data'),
          HolderSource('epic'),
        ],
        [placeholder, demo, patient('p1', 'epic', family: 'Doe')],
      )['epic'],
      'default_patient',
    );
  });

  test('with two other people the default holder stays on its own', () {
    final links = link(
      const [
        HolderSource('wallet-default_patient'),
        HolderSource('a'),
        HolderSource('b'),
      ],
      [placeholder, patient('pa', 'a'), patient('pb', 'b')],
    );
    expect(links.values.toSet(), {'default_patient', 'pa', 'pb'});
  });

  test('a renamed default holder joins only a match', () {
    final named = patient(
      'default_patient',
      'wallet-default_patient',
      family: 'Doe',
      given: 'Jane',
      birthDate: '1980-04-02',
    );
    expect(
      link(
        const [HolderSource('wallet-default_patient'), HolderSource('epic')],
        [named, patient('p1', 'epic', family: 'Roe', given: 'Jim')],
      ).values.toSet(),
      {'default_patient', 'p1'},
    );
  });

  test('linked sources keep their holder, new ones join it, and two holders '
      'are never merged', () {
    final links = link(
      const [
        HolderSource('a', holderId: 'h1'),
        HolderSource('b', holderId: 'h2'),
        HolderSource('c'),
      ],
      [
        patient('pa', 'a', identifiers: [ssn]),
        patient('pb', 'b', identifiers: [ssn]),
        patient('pc', 'c', identifiers: [ssn]),
      ],
    );
    expect(links.keys, ['c']);
    expect(links['c'], anyOf('h1', 'h2'));
  });

  test('the same records give the same holders in any order', () {
    final sources = [
      const HolderSource('wallet-default_patient'),
      const HolderSource('epic'),
      const HolderSource('wallet-p1'),
      const HolderSource('kaiser'),
    ];
    final patients = [
      placeholder,
      patient('p1', 'epic', identifiers: [ssn]),
      patient('p2', 'kaiser', identifiers: [ssn]),
    ];
    final first = link(sources, patients);
    final second = link(
      sources.reversed.toList(),
      patients.reversed.toList(),
    );
    expect(second, first);
    expect(first.values.toSet(), {'default_patient'});
  });
}
