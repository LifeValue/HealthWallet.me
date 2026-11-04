import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/domain/services/patient_edit_service.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/mixins/id_card_scan_mixin.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/dialog_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the events sent to it instead of running them.
class _MockPatientBloc extends MockBloc<PatientEvent, PatientState>
    implements PatientBloc {
  final events = <PatientEvent>[];

  @override
  void add(PatientEvent event) => events.add(event);
}

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState>
    implements HomeBloc {}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

/// Answers with the stored blood type and whether anything changed as the
/// test sets them, and records the blood type writes.
class _FakePatientEditService extends Fake implements PatientEditService {
  String? bloodType = 'A+';
  bool bloodTypeThrows = false;
  bool hasChanges = true;
  Exception? changesError;
  final bloodTypeWrites = <(String patientId, String bloodType)>[];

  @override
  Future<String?> getCurrentBloodType(Patient patient) async {
    if (bloodTypeThrows) throw StateError('records unavailable');
    return bloodType;
  }

  @override
  Future<bool> hasPatientChanges({
    required Patient currentPatient,
    required DateTime? newBirthDate,
    required String newGender,
    required String newBloodType,
    String? newIdentifierValue,
    required AppLocalizations l10n,
  }) async {
    if (changesError case final error?) throw error;
    return hasChanges;
  }

  @override
  Future<void> updateBloodTypeObservation(
    Patient patient,
    String bloodType,
  ) async {
    bloodTypeWrites.add((patient.id, bloodType));
    this.bloodType = bloodType;
  }
}

/// Returns [text] for every image.
class _FakeTextRecognitionService extends Fake
    implements TextRecognitionService {
  String text = '';
  final images = <String>[];

  @override
  Future<String> recognizeTextFromImage(String imagePath) async {
    images.add(imagePath);
    return text;
  }
}

final _en = lookupAppLocalizations(const Locale('en'));

// Made-up card text, laid out the way OCR returns a Romanian identity card.
const _romanianCard = '''ROMANIA ROUMANIE ROMANIA
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

Patient _patient({
  String? phone,
  String? identifier,
  String? birthDate = '1980-05-17',
}) => Patient(
  id: 'patient-1',
  sourceId: 'wallet-1',
  gender: fhir_r4.AdministrativeGender.female,
  birthDate: birthDate != null ? fhir_r4.FhirDate.fromString(birthDate) : null,
  name: [
    fhir_r4.HumanName(
      given: [fhir_r4.FhirString('Maria'), fhir_r4.FhirString('Elena')],
      family: fhir_r4.FhirString('Doe'),
    ),
  ],
  identifier: identifier == null
      ? null
      : [
          fhir_r4.Identifier(
            type: fhir_r4.CodeableConcept(
              coding: [fhir_r4.Coding(code: fhir_r4.FhirCode('MR'))],
            ),
            value: fhir_r4.FhirString(identifier),
          ),
        ],
  contact: phone == null
      ? null
      : [
          fhir_r4.PatientContact(
            telecom: [
              fhir_r4.ContactPoint(
                system: fhir_r4.ContactPointSystem.phone,
                value: fhir_r4.FhirString(phone),
              ),
            ],
          ),
        ],
);

const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);
const _imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  late _MockPatientBloc patientBloc;
  late _MockHomeBloc homeBloc;
  late _MockUserBloc userBloc;
  late _FakePatientEditService editService;
  late _FakeTextRecognitionService ocr;
  late int bloodTypeUpdates;
  late int dismissals;
  late List<MethodCall> permissionCalls;
  String? pickedImage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bloodTypeUpdates = 0;
    dismissals = 0;
    permissionCalls = [];
    pickedImage = '/photos/card.jpg';

    patientBloc = _MockPatientBloc();
    homeBloc = _MockHomeBloc();
    userBloc = _MockUserBloc();
    whenListen(
      patientBloc,
      const Stream<PatientState>.empty(),
      initialState: const PatientState(),
    );
    whenListen(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeState(),
    );
    whenListen(
      userBloc,
      const Stream<UserState>.empty(),
      initialState: const UserState(),
    );

    editService = _FakePatientEditService();
    ocr = _FakeTextRecognitionService();
    getIt
      ..registerSingleton<PatientEditService>(editService)
      ..registerSingleton<TextRecognitionService>(ocr);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // The camera permission is denied, so a camera scan stops there.
    messenger.setMockMethodCallHandler(_permissionChannel, (call) async {
      permissionCalls.add(call);
      return <int, int>{};
    });
    messenger.setMockMethodCallHandler(
      _imagePickerChannel,
      (call) async => pickedImage,
    );
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissionChannel, null);
    messenger.setMockMethodCallHandler(_imagePickerChannel, null);
    await getIt.reset();
  });

  Future<void> openDialog(WidgetTester tester, Patient patient) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _App(
        patient: patient,
        patientBloc: patientBloc,
        homeBloc: homeBloc,
        userBloc: userBloc,
        onBloodTypeUpdated: () => bloodTypeUpdates++,
        onDismiss: () => dismissals++,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(
    WidgetTester tester, {
    required String from,
    required String to,
  }) async {
    await tester.tap(find.text(from));
    await tester.pumpAndSettle();
    await tester.tap(find.text(to).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(_en.save));
    await tester.pumpAndSettle();
  }

  Finder field(String text) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.controller?.text == text,
  );

  Finder phoneField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.keyboardType == TextInputType.phone,
  );

  DialogContent content(WidgetTester tester) =>
      tester.widget<DialogContent>(find.byType(DialogContent));

  PatientEditSaved savedEdit() =>
      patientBloc.events.whereType<PatientEditSaved>().single;

  Iterable<PatientEditSaved> savedEdits() =>
      patientBloc.events.whereType<PatientEditSaved>();

  group('opening', () {
    testWidgets('fills in the stored names, identifier, birth date, blood '
        'type and emergency phone', (tester) async {
      await openDialog(
        tester,
        _patient(phone: '+40712345678', identifier: 'MRN-42'),
      );

      expect(find.text(_en.editDetails), findsOneWidget);
      expect(field('Maria Elena'), findsOneWidget);
      expect(field('Doe'), findsOneWidget);
      expect(field('MRN-42'), findsOneWidget);
      // The identifier is labelled after the stored identifier's type.
      expect(find.text('MRN'), findsOneWidget);
      expect(content(tester).selectedBirthDate, DateTime(1980, 5, 17));
      expect(find.text('A+'), findsOneWidget);
      expect(content(tester).selectedContactPhone, '+40712345678');
      expect(
        tester.widget<TextField>(phoneField()).controller!.text,
        isNotEmpty,
      );
    });

    testWidgets('shows N/A for a stored blood type that is not one of the '
        'options', (tester) async {
      editService.bloodType = 'Z+';
      await openDialog(tester, _patient());

      expect(content(tester).selectedBloodType, 'N/A');
    });

    testWidgets('shows N/A when no blood type is stored', (tester) async {
      editService.bloodType = '';
      await openDialog(tester, _patient());

      expect(content(tester).selectedBloodType, 'N/A');
    });

    testWidgets('shows N/A when the blood type cannot be read', (tester) async {
      editService.bloodTypeThrows = true;
      await openDialog(tester, _patient());

      expect(content(tester).selectedBloodType, 'N/A');
    });

    testWidgets('a saved country labels the identifier after that country', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.countryCode: 'RO',
      });
      await openDialog(tester, _patient(identifier: '1650812350142'));

      expect(content(tester).selectedCountryCode, 'RO');
      expect(content(tester).identifierLabel, 'CNP');
    });

    testWidgets('edits the provider copy when there is no wallet copy', (
      tester,
    ) async {
      final provider = _patient().copyWith(
        id: 'provider-patient',
        sourceId: 'provider-1',
      );
      whenListen(
        patientBloc,
        const Stream<PatientState>.empty(),
        initialState: PatientState(
          patientGroups: {
            'patient-1': PatientGroup(
              representativePatient: provider,
              sourceIds: [provider.sourceId],
              allPatientInstances: [provider],
            ),
          },
        ),
      );
      await openDialog(tester, _patient());

      await tester.enterText(field('Doe'), 'Popescu');
      await save(tester);

      expect(savedEdit().patientId, 'provider-patient');
      expect(savedEdit().sourceId, 'provider-1');
    });
  });

  group('saving', () {
    testWidgets('without a change closes without saving', (tester) async {
      editService.hasChanges = false;
      await openDialog(tester, _patient(phone: '+40712345678'));

      await save(tester);

      expect(savedEdits(), isEmpty);
      expect(editService.bloodTypeWrites, isEmpty);
      expect(find.byType(PatientEditDialog), findsNothing);
      expect(dismissals, 1);
      expect(bloodTypeUpdates, 0);
    });

    testWidgets('only a new blood type writes just the blood type', (
      tester,
    ) async {
      await openDialog(tester, _patient());

      await pick(tester, from: 'A+', to: 'B-');
      await save(tester);

      expect(editService.bloodTypeWrites, [('patient-1', 'B-')]);
      expect(savedEdits(), isEmpty);
      expect(bloodTypeUpdates, 1);
      expect(dismissals, 1);
      expect(find.byType(PatientEditDialog), findsNothing);
    });

    testWidgets('a new blood type with another field goes through the save '
        'and reports the blood type', (tester) async {
      await openDialog(tester, _patient());

      await pick(tester, from: 'A+', to: 'O-');
      await tester.enterText(field('Doe'), 'Popescu');
      await save(tester);

      expect(editService.bloodTypeWrites, isEmpty);
      final edit = savedEdit();
      expect(edit.bloodType, 'O-');
      expect(edit.family, 'Popescu');
      expect(edit.given, isNull);
      expect(edit.birthDate, isNull);
      expect(edit.gender, isNull);
      expect(edit.identifierValue, isNull);
      expect(edit.contactPhone, isNull);
      expect(bloodTypeUpdates, 1);
      expect(dismissals, 1);
    });

    testWidgets('an untouched blood type is saved as the stored one', (
      tester,
    ) async {
      await openDialog(tester, _patient());

      await tester.enterText(field('Doe'), 'Popescu');
      await save(tester);

      expect(savedEdit().bloodType, 'A+');
      expect(bloodTypeUpdates, 0);
    });

    testWidgets('an untouched blood type with none stored is saved as N/A', (
      tester,
    ) async {
      editService.bloodType = null;
      await openDialog(tester, _patient());

      await tester.enterText(field('Doe'), 'Popescu');
      await save(tester);

      expect(savedEdit().bloodType, 'N/A');
    });

    testWidgets('given names are split on spaces', (tester) async {
      await openDialog(tester, _patient());

      await tester.enterText(field('Maria Elena'), ' Ana   Maria ');
      await save(tester);

      expect(savedEdit().given, ['Ana', 'Maria']);
      expect(savedEdit().family, isNull);
    });

    // A cleared name is sent like an untouched one, so the stored names stay.
    testWidgets('a cleared given and family name are sent as no value', (
      tester,
    ) async {
      await openDialog(tester, _patient());

      await tester.enterText(field('Maria Elena'), '');
      await tester.enterText(field('Doe'), '');
      await save(tester);

      expect(savedEdit().given, isNull);
      expect(savedEdit().family, isNull);
      expect(find.byType(PatientEditDialog), findsNothing);
    });

    testWidgets('a changed identifier is saved', (tester) async {
      await openDialog(tester, _patient(identifier: 'MRN-42'));

      await tester.enterText(field('MRN-42'), 'MRN-43');
      await save(tester);

      expect(savedEdit().identifierValue, 'MRN-43');
    });

    testWidgets('a changed birth date is saved and shown', (tester) async {
      await openDialog(tester, _patient());

      content(tester).onBirthDateChanged!(DateTime(1990, 2, 3));
      await tester.pumpAndSettle();
      expect(content(tester).selectedBirthDate, DateTime(1990, 2, 3));

      await save(tester);

      expect(savedEdit().birthDate, DateTime(1990, 2, 3));
      expect(savedEdit().given, isNull);
    });

    testWidgets('a birth date set on a patient without one is saved', (
      tester,
    ) async {
      await openDialog(tester, _patient(birthDate: null));
      expect(find.text(_en.selectBirthDate), findsOneWidget);

      content(tester).onBirthDateChanged!(DateTime(1975, 1, 1));
      await tester.pumpAndSettle();
      await save(tester);

      expect(savedEdit().birthDate, DateTime(1975, 1, 1));
    });

    testWidgets('a changed gender is saved as its FHIR code', (tester) async {
      await openDialog(tester, _patient());

      await pick(tester, from: _en.female, to: _en.male);
      await save(tester);

      expect(savedEdit().gender, 'male');
    });

    testWidgets('a typed emergency phone is saved with the country dial '
        'code', (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.countryCode: 'RO',
      });
      await openDialog(tester, _patient());

      await tester.enterText(phoneField(), '712345678');
      await tester.pumpAndSettle();
      await save(tester);

      expect(savedEdit().contactPhone, '+40712345678');
      expect(savedEdit().identifierValue, isNull);
    });

    testWidgets('an emergency phone changed on its own is saved, keeping the '
        'blood type', (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.countryCode: 'RO',
      });
      editService.hasChanges = false;
      await openDialog(tester, _patient());

      await tester.enterText(phoneField(), '712345678');
      await tester.pumpAndSettle();
      await save(tester);

      final edit = savedEdit();
      expect(edit.contactPhone, '+40712345678');
      expect(edit.given, isNull);
      expect(edit.family, isNull);
      expect(edit.birthDate, isNull);
      expect(edit.gender, isNull);
      expect(edit.identifierValue, isNull);
      expect(edit.bloodType, 'A+');
      expect(editService.bloodTypeWrites, isEmpty);
      expect(dismissals, 1);
    });

    testWidgets('an untouched emergency phone is not written', (tester) async {
      await openDialog(tester, _patient(phone: '+40712345678'));

      await tester.enterText(field('Doe'), 'Popescu');
      await save(tester);

      expect(savedEdit().contactPhone, isNull);
    });

    testWidgets('picking a country clears the emergency phone and saves the '
        'country and the identifier', (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.countryCode: 'RO',
      });
      editService.hasChanges = false;
      await openDialog(
        tester,
        _patient(phone: '+40712345678', identifier: '1650812350142'),
      );

      await pick(tester, from: '🇷🇴 Romania', to: '🇪🇸 Spain');
      expect(content(tester).selectedCountryCode, 'ES');
      expect(content(tester).identifierLabel, 'CIP');
      expect(content(tester).selectedContactPhone, '');

      await save(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPrefsConstants.countryCode), 'ES');
      final edit = savedEdit();
      expect(edit.identifierValue, '1650812350142');
      expect(edit.contactPhone, '');
      expect(dismissals, 1);
    });

    testWidgets('the first country picked without a saved one counts as a '
        'change', (tester) async {
      editService.hasChanges = false;
      await openDialog(tester, _patient(identifier: 'MRN-42'));

      await pick(tester, from: '🇺🇸 United States', to: '🇷🇴 Romania');
      await save(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPrefsConstants.countryCode), 'RO');
      expect(savedEdit().identifierValue, 'MRN-42');
    });

    testWidgets('a saved country picked again saves nothing', (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConstants.countryCode: 'RO',
      });
      editService.hasChanges = false;
      await openDialog(tester, _patient());

      await save(tester);

      expect(savedEdits(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPrefsConstants.countryCode), 'RO');
    });

    testWidgets('that fails keeps the dialog open and can be tried again', (
      tester,
    ) async {
      editService.changesError = Exception('database locked');
      await openDialog(tester, _patient());

      await tester.enterText(field('Doe'), 'Popescu');
      await save(tester);

      expect(savedEdits(), isEmpty);
      expect(find.byType(PatientEditDialog), findsOneWidget);
      expect(dismissals, 0);

      editService.changesError = null;
      await save(tester);

      expect(savedEdit().family, 'Popescu');
      expect(find.byType(PatientEditDialog), findsNothing);
    });
  });

  testWidgets('cancelling closes, tells the bloc and saves nothing', (
    tester,
  ) async {
    await openDialog(tester, _patient());

    await tester.enterText(field('Doe'), 'Popescu');
    await tester.tap(find.text(_en.cancel));
    await tester.pumpAndSettle();

    expect(patientBloc.events, [const PatientEditCancelled()]);
    expect(find.byType(PatientEditDialog), findsNothing);
    expect(dismissals, 1);
  });

  group('an ID card', () {
    testWidgets('picked from the gallery fills in the card\'s details, which '
        'are saved', (tester) async {
      ocr.text = _romanianCard;
      await openDialog(tester, _patient(identifier: 'MRN-42'));

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();

      expect(ocr.images, ['/photos/card.jpg']);
      expect(field('ANDREI'), findsOneWidget);
      expect(field('DUMITRESCU'), findsOneWidget);
      expect(field('1650812350142'), findsOneWidget);
      expect(content(tester).selectedBirthDate, DateTime(1965, 8, 12));
      expect(find.text(_en.male), findsOneWidget);
      expect(find.text(_en.idScanVerifyDetails), findsOneWidget);

      await save(tester);

      final edit = savedEdit();
      expect(edit.given, ['ANDREI']);
      expect(edit.family, 'DUMITRESCU');
      expect(edit.identifierValue, '1650812350142');
      expect(edit.birthDate, DateTime(1965, 8, 12));
      expect(edit.gender, 'male');
    });

    testWidgets('with only a name keeps the rest and says the scan was '
        'partial', (tester) async {
      ocr.text = '''BUNDESREPUBLIK DEUTSCHLAND
PERSONALAUSWEIS
Name MUSTERMANN
Vornamen ERIKA''';
      await openDialog(tester, _patient(identifier: 'MRN-42'));

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();

      expect(find.text(_en.idScanPartial), findsOneWidget);
      expect(field('MUSTERMANN'), findsOneWidget);
      expect(field('ERIKA'), findsOneWidget);
      expect(field('MRN-42'), findsOneWidget);
      expect(content(tester).selectedBirthDate, DateTime(1980, 5, 17));
      expect(find.text(_en.female), findsOneWidget);
    });

    testWidgets('that cannot be read says so and leaves the fields', (
      tester,
    ) async {
      await openDialog(tester, _patient());

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();

      expect(find.text(_en.idScanFailed), findsOneWidget);
      expect(field('Maria Elena'), findsOneWidget);
      expect(field('Doe'), findsOneWidget);
    });

    testWidgets('a read offers to read the same image again, which applies '
        'the new text', (tester) async {
      ocr.text = '''BUNDESREPUBLIK DEUTSCHLAND
PERSONALAUSWEIS
Name MUSTERMANN
Vornamen ERIKA''';
      await openDialog(tester, _patient());
      expect(content(tester).onRetryOcr, isNull);

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();
      final scan =
          tester.state(find.byType(PatientEditDialog)) as IdCardScanMixin;
      expect(scan.scanCompleted, isTrue);
      expect(scan.scanMessage, _en.idScanPartial);
      expect(scan.lastScannedImagePath, '/photos/card.jpg');
      expect(content(tester).onRetryOcr, isNotNull);

      ocr.text = _romanianCard;
      content(tester).onRetryOcr!();
      await tester.pumpAndSettle();

      expect(ocr.images, ['/photos/card.jpg', '/photos/card.jpg']);
      expect(scan.scanMessage, _en.idScanVerifyDetails);
      expect(scan.isScanning, isFalse);
      expect(find.text(_en.idScanVerifyDetails), findsOneWidget);
      expect(content(tester).selectedBirthDate, DateTime(1965, 8, 12));
    });

    testWidgets('a scan retried after a failure clears the message and asks '
        'for the camera', (tester) async {
      await openDialog(tester, _patient());
      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();
      expect(find.text(_en.idScanFailed), findsOneWidget);

      await tester.tap(find.text(_en.retry).first);
      await tester.pumpAndSettle();

      expect(find.text(_en.idScanFailed), findsNothing);
      expect(permissionCalls.single.method, 'requestPermissions');
    });

    testWidgets('a gallery pick cancelled changes nothing', (tester) async {
      pickedImage = null;
      await openDialog(tester, _patient());

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();

      expect(ocr.images, isEmpty);
      expect(find.text(_en.attachFile), findsOneWidget);
      expect(field('Doe'), findsOneWidget);
    });
  });
}

/// The app around the dialog, opened the way the app opens it.
class _App extends StatelessWidget {
  final Patient patient;
  final PatientBloc patientBloc;
  final HomeBloc homeBloc;
  final UserBloc userBloc;
  final VoidCallback onBloodTypeUpdated;
  final VoidCallback onDismiss;

  const _App({
    required this.patient,
    required this.patientBloc,
    required this.homeBloc,
    required this.userBloc,
    required this.onBloodTypeUpdated,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PatientBloc>.value(value: patientBloc),
        BlocProvider<HomeBloc>.value(value: homeBloc),
        BlocProvider<UserBloc>.value(value: userBloc),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => PatientEditDialog.show(
                context,
                patient,
                onBloodTypeUpdated: onBloodTypeUpdated,
                onDismiss: onDismiss,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}
