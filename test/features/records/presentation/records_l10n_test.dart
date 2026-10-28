import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/filters/date_range_filter_model.dart';
import 'package:health_wallet/features/records/presentation/widgets/filters/date_range_selector.dart';
import 'package:health_wallet/features/records/presentation/widgets/filters/date_wide_dropdown.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_type_header.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_active_filters_bar.dart';
import 'package:health_wallet/features/records/presentation/widgets/records_view_toggle.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('de');
    await initializeDateFormatting('ro');
  });

  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));
  final ro = lookupAppLocalizations(const Locale('ro'));

  group('records view toggle', () {
    testWidgets('shows the Romanian records label', (tester) async {
      await tester.pumpWidget(
        _app(
          const Locale('ro'),
          RecordsViewToggle(
            mode: RecordsViewMode.recordsList,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Înregistrări'), findsOneWidget);
      expect(find.text('Records'), findsNothing);
    });

    testWidgets('shows the Romanian attachments label', (tester) async {
      await tester.pumpWidget(
        _app(
          const Locale('ro'),
          RecordsViewToggle(
            mode: RecordsViewMode.attachments,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Atașamente'), findsOneWidget);
      expect(find.text('Attachments'), findsNothing);
    });
  });

  testWidgets('active filter chips show Romanian type, specialty and date', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Locale('ro'),
        const RecordsActiveFiltersBar(
          activeFilters: [FhirType.Condition],
          dateFilter: DateFilter(fromYear: 2024),
          activeSpecialties: [MedicalSpecialty.cardiology],
        ),
      ),
    );
    expect(find.text('Afecțiune'), findsOneWidget);
    expect(find.text('Cardiologie'), findsOneWidget);
    expect(find.text('Dată: Din 2024'), findsOneWidget);
    expect(find.text('Condition'), findsNothing);
    expect(find.text('Cardiology'), findsNothing);
  });

  testWidgets('record type header shows the Romanian type and date', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Locale('ro'),
        RecordTypeHeader(
          fhirType: FhirType.Condition,
          date: DateTime(2024, 3, 5),
        ),
      ),
    );
    expect(find.text('Afecțiune'), findsOneWidget);
    expect(find.text('5 martie 2024'), findsOneWidget);
  });

  group('date filter', () {
    test('chip label uses German month names', () {
      const filter = DateFilter(fromDay: 5, fromMonth: 3, fromYear: 2024);
      expect(filter.formatChipLabel(de), 'Datum: Ab 5 Mär 2024');
    });

    test('chip label stays the same in English', () {
      const filter = DateFilter(
        fromMonth: 3,
        fromYear: 2024,
        toMonth: 5,
        toYear: 2024,
      );
      expect(filter.formatChipLabel(en), 'Date: Mar 2024 - May 2024');
      expect(
        const DateFilter(toYear: 2020).formatChipLabel(en),
        'Date: Until 2020',
      );
    });

    test('flags an end date before the start date', () {
      expect(
        const DateFilter(fromYear: 2025, toYear: 2024).hasInvalidRange,
        isTrue,
      );
      expect(
        const DateFilter(
          fromMonth: 4,
          toMonth: 4,
          fromDay: 9,
          toDay: 2,
        ).hasInvalidRange,
        isTrue,
      );
      expect(
        const DateFilter(fromYear: 2024, toYear: 2025).hasInvalidRange,
        isFalse,
      );
    });

    test('month dropdown lists German month names', () {
      final names = DateRangeDropdownService.getMonths(
        'de',
      ).map((m) => m.displayText).toList();
      expect(names, hasLength(13));
      expect(names, containsAll(['Mai', 'Okt', 'Dez']));
      expect(names, isNot(contains('Oct')));
    });

    test('month dropdown keeps the English abbreviations', () {
      final names = DateRangeDropdownService.getMonths(
        'en',
      ).skip(1).map((m) => m.displayText).toList();
      expect(names, [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ]);
    });

    testWidgets('the German year field opens the year picker', (tester) async {
      final containerKey = GlobalKey();
      await tester.pumpWidget(
        _app(
          const Locale('de'),
          Container(
            key: containerKey,
            child: DateRangeSelector(
              label: de.start,
              icon: Assets.icons.calendar,
              year: null,
              month: null,
              day: null,
              onYearChanged: (_) {},
              onMonthChanged: (_) {},
              onDayChanged: (_) {},
              containerKey: containerKey,
            ),
          ),
        ),
      );
      expect(find.text('Jahr'), findsOneWidget);

      final yearField = find.byType(DateWideDropdown).at(2);
      await tester.tap(
        find.descendant(of: yearField, matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();

      final currentYear = DateTime.now().year;
      expect(find.text('${currentYear - 24} - $currentYear'), findsOneWidget);
    });
  });

  test('Romanian strings used by the records screens are translated', () {
    expect(ro.noAttachments, isNot(en.noAttachments));
    expect(ro.viewRelated, isNot(en.viewRelated));
    expect(de.dateFilterEndBeforeStart, isNot(en.dateFilterEndBeforeStart));
  });
}
