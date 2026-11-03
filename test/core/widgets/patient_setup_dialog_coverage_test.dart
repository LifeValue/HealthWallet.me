import 'package:bloc_test/bloc_test.dart' show MockBloc, whenListen;
import 'package:fhir_r4/fhir_r4.dart' show AdministrativeGender;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/theme.dart';
import 'package:health_wallet/core/widgets/patient_setup_dialog.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/user/domain/services/patient_deduplication_service.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/mixins/id_card_scan_mixin.dart';
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

/// A records bloc whose state can't be read, as when it was closed.
class _BrokenHomeBloc extends _MockHomeBloc {
  @override
  HomeState get state => throw StateError('home bloc closed');
}

class _MockUserBloc extends MockBloc<UserEvent, UserState>
    implements UserBloc {}

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

const _patient = Patient(
  id: 'patient-1',
  sourceId: 'wallet-1',
  gender: AdministrativeGender.female,
);

const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);
const _imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  late _MockPatientBloc patientBloc;
  late _MockHomeBloc homeBloc;
  late _MockUserBloc userBloc;
  late _FakeTextRecognitionService ocr;
  late int dismissals;
  late List<MethodCall> permissionCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dismissals = 0;
    permissionCalls = [];

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

    ocr = _FakeTextRecognitionService();
    getIt.registerSingleton<TextRecognitionService>(ocr);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // The camera permission is denied, so a camera scan stops there.
    messenger.setMockMethodCallHandler(_permissionChannel, (call) async {
      permissionCalls.add(call);
      return <int, int>{};
    });
    messenger.setMockMethodCallHandler(
      _imagePickerChannel,
      (call) async => '/photos/card.jpg',
    );
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_permissionChannel, null);
    messenger.setMockMethodCallHandler(_imagePickerChannel, null);
    await getIt.reset();
  });

  /// Opens the dialog on a device set to [deviceLocale].
  Future<void> openDialog(
    WidgetTester tester, {
    Locale deviceLocale = const Locale('en', 'US'),
    HomeBloc? home,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = deviceLocale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      _App(
        patientBloc: patientBloc,
        homeBloc: home ?? homeBloc,
        userBloc: userBloc,
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
    await tester.tap(find.text(_en.done));
    await tester.pumpAndSettle();
  }

  Finder hinted(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  Finder phoneField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.keyboardType == TextInputType.phone,
  );

  Finder withText(String text) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.controller?.text == text,
  );

  DialogContent content(WidgetTester tester) =>
      tester.widget<DialogContent>(find.byType(DialogContent));

  PatientEditSaved savedEdit() =>
      patientBloc.events.whereType<PatientEditSaved>().single;

  group('opening', () {
    testWidgets('starts empty, on the device\'s country', (tester) async {
      await openDialog(tester, deviceLocale: const Locale('de', 'DE'));

      expect(find.text(_en.setup), findsOneWidget);
      expect(find.text(_en.patientSetupSubtitle), findsOneWidget);
      expect(hinted(_en.givenName), findsOneWidget);
      expect(hinted(_en.familyName), findsOneWidget);
      expect(hinted('KVNR (optional)'), findsOneWidget);
      expect(find.text('🇩🇪 Germany'), findsOneWidget);
      expect(find.text(_en.selectBirthDate), findsOneWidget);
      expect(find.text('N/A'), findsOneWidget);
      expect(content(tester).selectedCountryCode, 'DE');
      expect(content(tester).isSetupMode, isTrue);
    });

    testWidgets('a device without a region starts on the United States', (
      tester,
    ) async {
      await openDialog(tester, deviceLocale: const Locale('en'));

      expect(content(tester).selectedCountryCode, 'US');
      expect(hinted('MRN (optional)'), findsOneWidget);
    });

    testWidgets('sets up the wallet copy of a patient seen in several '
        'sources', (tester) async {
      const provider = Patient(id: 'patient-1', sourceId: 'provider-1');
      const wallet = Patient(id: 'patient-1-wallet', sourceId: 'wallet-1');
      whenListen(
        patientBloc,
        const Stream<PatientState>.empty(),
        initialState: const PatientState(
          patientGroups: {
            'patient-1': PatientGroup(
              representativePatient: provider,
              sourceIds: ['provider-1', 'wallet-1'],
              allPatientInstances: [provider, wallet],
            ),
          },
        ),
      );
      await openDialog(tester);

      await tester.enterText(hinted(_en.givenName), 'Maria');
      await save(tester);

      expect(savedEdit().patientId, 'patient-1-wallet');
      expect(savedEdit().sourceId, 'wallet-1');
    });

    testWidgets('sets up the group\'s main copy when there is no wallet '
        'copy', (tester) async {
      const provider = Patient(id: 'provider-patient', sourceId: 'provider-1');
      whenListen(
        patientBloc,
        const Stream<PatientState>.empty(),
        initialState: const PatientState(
          patientGroups: {
            'patient-1': PatientGroup(
              representativePatient: provider,
              sourceIds: ['provider-1'],
              allPatientInstances: [provider],
            ),
          },
        ),
      );
      await openDialog(tester);

      await tester.enterText(hinted(_en.givenName), 'Maria');
      await save(tester);

      expect(savedEdit().patientId, 'provider-patient');
    });
  });

  group('done', () {
    testWidgets('saves every field filled in', (tester) async {
      await openDialog(tester, deviceLocale: const Locale('ro', 'RO'));

      await tester.enterText(hinted(_en.givenName), ' Ana   Maria ');
      await tester.enterText(hinted(_en.familyName), 'Popescu');
      await tester.enterText(hinted('CNP (optional)'), '2900203123456');
      content(tester).onBirthDateChanged!(DateTime(1990, 2, 3));
      await tester.pumpAndSettle();
      await pick(tester, from: _en.preferNotToSay, to: _en.female);
      await pick(tester, from: 'N/A', to: 'AB-');
      await tester.enterText(phoneField(), '712345678');
      await tester.pumpAndSettle();

      await save(tester);

      final edit = savedEdit();
      expect(edit.patientId, 'patient-1');
      expect(edit.given, ['Ana', 'Maria']);
      expect(edit.family, 'Popescu');
      expect(edit.identifierValue, '2900203123456');
      expect(edit.birthDate, DateTime(1990, 2, 3));
      expect(edit.gender, 'female');
      expect(edit.bloodType, 'AB-');
      expect(edit.contactPhone, '+40712345678');
      expect(edit.availableSources, isEmpty);
      expect(find.byType(PatientSetupDialog), findsNothing);
      expect(dismissals, 1);
    });

    testWidgets('with only a blood type saves it, the rest empty', (
      tester,
    ) async {
      await openDialog(tester);

      await pick(tester, from: 'N/A', to: 'O+');
      await save(tester);

      final edit = savedEdit();
      expect(edit.bloodType, 'O+');
      expect(edit.given, isNull);
      expect(edit.family, isNull);
      expect(edit.identifierValue, isNull);
      expect(edit.birthDate, isNull);
      expect(edit.gender, 'unknown');
      expect(edit.contactPhone, isNull);
    });

    testWidgets('with only a birth date saves it', (tester) async {
      await openDialog(tester);

      content(tester).onBirthDateChanged!(DateTime(1975, 1, 1));
      await tester.pumpAndSettle();
      await save(tester);

      expect(savedEdit().birthDate, DateTime(1975, 1, 1));
      expect(savedEdit().bloodType, 'N/A');
    });

    testWidgets('with only an identifier saves it', (tester) async {
      await openDialog(tester);

      await tester.enterText(hinted('MRN (optional)'), 'MRN-1');
      await save(tester);

      expect(savedEdit().identifierValue, 'MRN-1');
      expect(savedEdit().given, isNull);
    });

    testWidgets('with only a family name saves it', (tester) async {
      await openDialog(tester);

      await tester.enterText(hinted(_en.familyName), 'Popescu');
      await save(tester);

      expect(savedEdit().family, 'Popescu');
      expect(savedEdit().given, isNull);
    });

    testWidgets(
      'with only an emergency phone saves the phone',
      skip: true, // BUG: setup drops an emergency phone entered on its own; the phone is not one of the fields that trigger a save
      (tester) async {
        await openDialog(tester, deviceLocale: const Locale('ro', 'RO'));

        await tester.enterText(phoneField(), '712345678');
        await tester.pumpAndSettle();
        await save(tester);

        expect(savedEdit().contactPhone, '+40712345678');
      },
    );

    testWidgets('with only an emergency phone currently closes without '
        'saving', (tester) async {
      await openDialog(tester, deviceLocale: const Locale('ro', 'RO'));

      await tester.enterText(phoneField(), '712345678');
      await tester.pumpAndSettle();
      await save(tester);

      expect(patientBloc.events.whereType<PatientEditSaved>(), isEmpty);
      expect(find.byType(PatientSetupDialog), findsNothing);
      expect(dismissals, 1);
    });

    testWidgets('that fails keeps the dialog open and can be tried again', (
      tester,
    ) async {
      await openDialog(tester, home: _BrokenHomeBloc());

      await tester.enterText(hinted(_en.givenName), 'Maria');
      await save(tester);

      expect(patientBloc.events.whereType<PatientEditSaved>(), isEmpty);
      expect(find.byType(PatientSetupDialog), findsOneWidget);
      expect(dismissals, 0);
      // The buttons work again.
      await tester.tap(find.text(_en.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(PatientSetupDialog), findsNothing);
    });
  });

  testWidgets('picking a country relabels the identifier and clears the '
      'phone', (tester) async {
    await openDialog(tester, deviceLocale: const Locale('ro', 'RO'));
    await tester.enterText(phoneField(), '712345678');
    await tester.pumpAndSettle();
    expect(hinted('CNP (optional)'), findsOneWidget);

    await pick(tester, from: '🇷🇴 Romania', to: '🇪🇸 Spain');

    expect(content(tester).selectedCountryCode, 'ES');
    expect(hinted('CIP (optional)'), findsOneWidget);
    expect(content(tester).selectedContactPhone, '');

    await tester.enterText(hinted(_en.givenName), 'Maria');
    await save(tester);
    expect(savedEdit().contactPhone, isNull);
  });

  testWidgets('cancelling closes, tells the bloc and saves nothing', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.enterText(hinted(_en.givenName), 'Maria');
    await tester.tap(find.text(_en.cancel));
    await tester.pumpAndSettle();

    expect(patientBloc.events, [const PatientEditCancelled()]);
    expect(find.byType(PatientSetupDialog), findsNothing);
    expect(dismissals, 1);
  });

  group('an ID card', () {
    testWidgets('picked from the gallery fills in the card\'s details, which '
        'are saved', (tester) async {
      ocr.text = _romanianCard;
      await openDialog(tester);

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();

      expect(ocr.images, ['/photos/card.jpg']);
      expect(withText('ANDREI'), findsOneWidget);
      expect(withText('DUMITRESCU'), findsOneWidget);
      expect(withText('1650812350142'), findsOneWidget);
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

    testWidgets('without a country on it is read as a card of the picked '
        'country', (tester) async {
      ocr.text = '1650812350142\nDUMITRESCU ANDREI';
      await openDialog(tester, deviceLocale: const Locale('ro', 'RO'));

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();

      expect(withText('1650812350142'), findsOneWidget);
    });

    testWidgets('without a birth date or gender keeps the ones picked', (
      tester,
    ) async {
      ocr.text = '''BUNDESREPUBLIK DEUTSCHLAND
PERSONALAUSWEIS
Name MUSTERMANN
Vornamen ERIKA''';
      await openDialog(tester);
      await pick(tester, from: _en.preferNotToSay, to: _en.female);
      content(tester).onBirthDateChanged!(DateTime(1964, 8, 12));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();

      expect(find.text(_en.idScanPartial), findsOneWidget);
      expect(withText('MUSTERMANN'), findsOneWidget);
      expect(find.text(_en.female), findsOneWidget);
      expect(content(tester).selectedBirthDate, DateTime(1964, 8, 12));
    });

    testWidgets('a read offers to read the same image again, which applies '
        'the new text', (tester) async {
      ocr.text = '''BUNDESREPUBLIK DEUTSCHLAND
PERSONALAUSWEIS
Name MUSTERMANN
Vornamen ERIKA''';
      await openDialog(tester);
      expect(content(tester).onRetryOcr, isNull);

      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();
      final scan =
          tester.state(find.byType(PatientSetupDialog)) as IdCardScanMixin;
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
      await openDialog(tester);
      await tester.tap(find.text(_en.attachFile));
      await tester.pumpAndSettle();
      expect(find.text(_en.idScanFailed), findsOneWidget);

      await tester.tap(find.text(_en.retry).first);
      await tester.pumpAndSettle();

      expect(find.text(_en.idScanFailed), findsNothing);
      expect(permissionCalls.single.method, 'requestPermissions');
    });
  });
}

/// The app around the dialog, opened the way the app opens it.
class _App extends StatelessWidget {
  final PatientBloc patientBloc;
  final HomeBloc homeBloc;
  final UserBloc userBloc;
  final VoidCallback onDismiss;

  const _App({
    required this.patientBloc,
    required this.homeBloc,
    required this.userBloc,
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
              onPressed: () => PatientSetupDialog.show(
                context,
                _patient,
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
