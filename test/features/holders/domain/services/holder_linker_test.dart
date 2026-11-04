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

HolderLinks linkAll(
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

Map<String, String> link(
  List<HolderSource> sources,
  List<HolderPatient> patients, [
  Map<String, Set<String>> references = const {},
]) => linkAll(sources, patients, references).links;

void main() {
  test('next to the untouched default holder, a provider patient who '
      'matches no one is asked about', () {
    final result = linkAll(
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
    );
    expect(result.links, {'wallet-default_patient': 'default_patient'});
    expect(result.questions.single.sourceIds, ['epic']);
  });

  test('the untouched default holder is known by its content, under any '
      'row id', () {
    final result = linkAll(
      const [HolderSource('wallet-default_patient'), HolderSource('epic')],
      [
        const HolderPatient(
          rowId: 'bf2e982b',
          resourceId: 'bf2e982b',
          sourceId: 'wallet-default_patient',
          identifiers: [
            HolderIdentifier(system: 'x', value: 'default_patient'),
          ],
          family: 'Holder',
          given: 'Health Wallet',
        ),
        patient('p1', 'epic'),
      ],
    );
    expect(result.questions.single.sourceIds, ['epic']);
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

  test('the demo patient is never asked about, and a provider patient next '
      'to the default holder still is', () {
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
      linkAll(
        const [
          HolderSource('wallet-default_patient'),
          HolderSource('demo_data'),
          HolderSource('epic'),
        ],
        [placeholder, demo, patient('p1', 'epic', family: 'Doe')],
      ).questions.single.sourceIds,
      ['epic'],
    );
  });

  test('next to the default holder every other person is asked about', () {
    final result = linkAll(
      const [
        HolderSource('wallet-default_patient'),
        HolderSource('a'),
        HolderSource('b'),
      ],
      [placeholder, patient('pa', 'a'), patient('pb', 'b')],
    );
    expect(result.links.values.toSet(), {'default_patient'});
    expect(result.questions.map((q) => q.newHolderId), ['pa', 'pb']);
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

  group('once the wallet has holders', () {
    test('a newcomer who matches no one is asked about, even next to a '
        'single holder', () {
      final result = linkAll(
        const [
          HolderSource('wallet-jane', holderId: 'jane'),
          HolderSource('epic'),
        ],
        [
          patient('jane', 'wallet-jane', family: 'Doe', given: 'Jane'),
          patient('p1', 'epic', family: 'Doe', given: 'J.'),
        ],
      );
      expect(result.links, isEmpty);
      expect(result.questions.single.sourceIds, ['epic']);
    });

    test('with only the demo person, a newcomer becomes a holder', () {
      final result = linkAll(
        const [
          HolderSource('demo_data', holderId: 'demo-patient'),
          HolderSource('epic'),
        ],
        [patient('demo-patient', 'demo_data'), patient('p1', 'epic')],
      );
      expect(result.links, {'epic': 'p1'});
      expect(result.questions, isEmpty);
    });

    test('the demo person is not a holder to join', () {
      final result = linkAll(
        const [
          HolderSource('wallet-jane', holderId: 'jane'),
          HolderSource('demo_data', holderId: 'demo-patient'),
          HolderSource('epic'),
        ],
        [
          patient('jane', 'wallet-jane'),
          patient('demo-patient', 'demo_data'),
          patient('p1', 'epic'),
        ],
      );
      expect(result.links, isEmpty);
      expect(result.questions.single.sourceIds, ['epic']);
    });

    test('with several holders a newcomer is asked about, with the sources '
        'that wait and the holder it gets as someone else', () {
      final result = linkAll(
        const [
          HolderSource('wallet-jane', holderId: 'jane'),
          HolderSource('wallet-tom', holderId: 'tom'),
          HolderSource('epic'),
          HolderSource('wallet-p1'),
        ],
        [
          patient('jane', 'wallet-jane'),
          patient('tom', 'wallet-tom'),
          patient('p1', 'epic'),
        ],
      );
      expect(result.links, isEmpty);
      final question = result.questions.single;
      expect(question.sourceIds, ['epic', 'wallet-p1']);
      expect(question.newHolderId, 'p1');
    });

    test('a newcomer who matches a holder joins it without a question', () {
      final result = linkAll(
        const [
          HolderSource('wallet-jane', holderId: 'jane'),
          HolderSource('wallet-tom', holderId: 'tom'),
          HolderSource('epic'),
        ],
        [
          patient('jane', 'wallet-jane', identifiers: [ssn]),
          patient('tom', 'wallet-tom'),
          patient('p1', 'epic', identifiers: [ssn]),
        ],
      );
      expect(result.links, {'epic': 'jane'});
      expect(result.questions, isEmpty);
    });

    test('two newcomers next to one holder are both asked about', () {
      final result = linkAll(
        const [
          HolderSource('wallet-jane', holderId: 'jane'),
          HolderSource('a'),
          HolderSource('b'),
        ],
        [
          patient('jane', 'wallet-jane'),
          patient('pa', 'a'),
          patient('pb', 'b'),
        ],
      );
      expect(result.links, isEmpty);
      expect(result.questions.map((q) => q.newHolderId), ['pa', 'pb']);
    });
  });

  group('holders that are one person', () {
    Map<String, String> merges(
      List<HolderPatient> patients,
      Map<String, String> holderBySource,
    ) => const HolderLinker().merges(
      patients: patients,
      holderBySource: holderBySource,
    );

    test('join the smallest holder id when they share a national number, '
        'however their names are written', () {
      expect(
        merges(
          [
            patient(
              'c',
              'wallet-c',
              identifiers: [ssn],
              given: 'Ion',
              family: 'Pop',
            ),
            patient(
              'b',
              'wallet-b',
              identifiers: [ssn],
              given: 'Pop',
              family: 'Ion',
            ),
            patient('a', 'epic', identifiers: [ssn]),
          ],
          {'wallet-c': 'c', 'wallet-b': 'b', 'epic': 'a'},
        ),
        {'b': 'a', 'c': 'a'},
      );
    });

    test('stay apart with the same name and birth date only, or the same '
        'record number at two hospitals', () {
      expect(
        merges(
          [
            patient(
              'a',
              'epic',
              identifiers: [mrn('http://a/mrn', '55501')],
              given: 'Jane',
              family: 'Doe',
              birthDate: '1980-04-02',
            ),
            patient(
              'b',
              'kaiser',
              identifiers: [mrn('http://b/mrn', '55501')],
              given: 'Jane',
              family: 'Doe',
              birthDate: '1980-04-02',
            ),
          ],
          {'epic': 'a', 'kaiser': 'b'},
        ),
        isEmpty,
      );
    });

    test('never take in the demo person', () {
      expect(
        merges(
          [
            patient('a', 'wallet-a', identifiers: [ssn]),
            patient('demo', 'demo_data', identifiers: [ssn]),
          ],
          {'wallet-a': 'a', 'demo_data': 'demo'},
        ),
        isEmpty,
      );
    });
  });
}
