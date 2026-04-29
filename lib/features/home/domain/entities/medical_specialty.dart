import 'package:health_wallet/gen/assets.gen.dart';

enum MedicalSpecialty {
  allergology(
    displayName: 'Allergology',
    abbreviation: 'AL',
    snomedSpecialtyCode: '394601005',
    headlineLoincCodes: {'6106-5', '7258-3'},
    screeningIntervalDays: 365,
  ),
  cardiology(
    displayName: 'Cardiology',
    abbreviation: 'CA',
    snomedSpecialtyCode: '394579002',
    headlineLoincCodes: {'85354-9', '8867-4', '2093-3', '13457-7'},
    screeningIntervalDays: 365,
  ),
  dental(
    displayName: 'Dental',
    abbreviation: 'DE',
    snomedSpecialtyCode: '394605001',
    headlineLoincCodes: {},
    screeningIntervalDays: 180,
  ),
  dermatology(
    displayName: 'Dermatology',
    abbreviation: 'DM',
    snomedSpecialtyCode: '394604002',
    headlineLoincCodes: {},
    screeningIntervalDays: 365,
  ),
  emergencyMedicine(
    displayName: 'Emergency Medicine',
    abbreviation: 'EM',
    snomedSpecialtyCode: '408478003',
    headlineLoincCodes: {},
    screeningIntervalDays: null,
  ),
  endocrinology(
    displayName: 'Endocrinology',
    abbreviation: 'EN',
    snomedSpecialtyCode: '394583002',
    headlineLoincCodes: {'2339-0', '4548-4', '3016-3'},
    screeningIntervalDays: 180,
  ),
  gastroenterology(
    displayName: 'Gastroenterology',
    abbreviation: 'GA',
    snomedSpecialtyCode: '394584008',
    headlineLoincCodes: {'14563-1', '2335-8'},
    screeningIntervalDays: 365,
  ),
  generalCare(
    displayName: 'General Care',
    abbreviation: 'GC',
    snomedSpecialtyCode: '394802001',
    headlineLoincCodes: {'8310-5', '29463-7', '8302-2'},
    screeningIntervalDays: 365,
  ),
  gynecology(
    displayName: 'Gynecology',
    abbreviation: 'GY',
    snomedSpecialtyCode: '394585009',
    headlineLoincCodes: {'10524-7', '2106-3'},
    screeningIntervalDays: 365,
  ),
  nephrology(
    displayName: 'Nephrology',
    abbreviation: 'NP',
    snomedSpecialtyCode: '394589003',
    headlineLoincCodes: {'2160-0', '33914-3', '3094-0'},
    screeningIntervalDays: 90,
  ),
  neurology(
    displayName: 'Neurology',
    abbreviation: 'NE',
    snomedSpecialtyCode: '394591006',
    headlineLoincCodes: {'30525-0'},
    screeningIntervalDays: 365,
  ),
  oncology(
    displayName: 'Oncology',
    abbreviation: 'ON',
    snomedSpecialtyCode: '394593009',
    headlineLoincCodes: {},
    screeningIntervalDays: null,
  ),
  ophthalmology(
    displayName: 'Ophthalmology',
    abbreviation: 'OP',
    snomedSpecialtyCode: '394594003',
    headlineLoincCodes: {'79880-1', '29271-4'},
    screeningIntervalDays: 365,
  ),
  orthopedics(
    displayName: 'Orthopedics',
    abbreviation: 'OR',
    snomedSpecialtyCode: '394609007',
    headlineLoincCodes: {'38263-0'},
    screeningIntervalDays: 365,
  ),
  psychiatry(
    displayName: 'Psychiatry',
    abbreviation: 'PS',
    snomedSpecialtyCode: '394587001',
    headlineLoincCodes: {'44249-1', '69737-5'},
    screeningIntervalDays: 365,
  ),
  pulmonology(
    displayName: 'Pulmonology',
    abbreviation: 'PU',
    snomedSpecialtyCode: '418112009',
    headlineLoincCodes: {'9279-1', '2708-6', '19926-5'},
    screeningIntervalDays: 365,
  ),
  rheumatology(
    displayName: 'Rheumatology',
    abbreviation: 'RH',
    snomedSpecialtyCode: '394600006',
    headlineLoincCodes: {'5130-0', '4537-7', '1988-5'},
    screeningIntervalDays: 180,
  ),
  urology(
    displayName: 'Urology',
    abbreviation: 'UR',
    snomedSpecialtyCode: '394612005',
    headlineLoincCodes: {'2857-1', '5811-5'},
    screeningIntervalDays: 365,
  );

  const MedicalSpecialty({
    required this.displayName,
    required this.abbreviation,
    required this.snomedSpecialtyCode,
    required this.headlineLoincCodes,
    required this.screeningIntervalDays,
  });

  final String displayName;
  final String abbreviation;
  final String snomedSpecialtyCode;
  final Set<String> headlineLoincCodes;
  final int? screeningIntervalDays;

  SvgGenImage get icon => switch (this) {
        allergology => Assets.specialities.allergology,
        cardiology => Assets.specialities.cardiology,
        dental => Assets.specialities.dental,
        dermatology => Assets.specialities.dermatology,
        emergencyMedicine => Assets.specialities.emergencyMedicine,
        endocrinology => Assets.specialities.endocrinology,
        gastroenterology => Assets.specialities.gastroenterology,
        generalCare => Assets.specialities.generalCare,
        gynecology => Assets.specialities.gynecology,
        nephrology => Assets.specialities.nephrology,
        neurology => Assets.specialities.neurology,
        oncology => Assets.specialities.oncology,
        ophthalmology => Assets.specialities.ophthalmology,
        orthopedics => Assets.specialities.orthopedics,
        psychiatry => Assets.specialities.psychiatry,
        pulmonology => Assets.specialities.pulmonology,
        rheumatology => Assets.specialities.rheumatology,
        urology => Assets.specialities.urology,
      };
}
