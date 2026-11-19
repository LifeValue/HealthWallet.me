import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../fixtures/fhir/fhir_fixtures.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final en = lookupAppLocalizations(const Locale('en'));

  List<String> infos(Map<String, dynamic> attachment) => entityFromJson(
    documentReferenceJson(attachments: [attachment]),
  ).additionalInfo(en).map((line) => line.info).toList();

  test('shows the size of a scanned document in the largest unit', () {
    expect(
      infos({
        'contentType': 'application/pdf',
        'title': 'scan.pdf',
        'size': 2411724,
      }),
      contains('Size: 2.3 MB'),
    );
  });

  test('keeps bytes for a small file', () {
    expect(
      infos({'contentType': 'text/plain', 'title': 'note.txt', 'size': 512}),
      contains('Size: 512 B'),
    );
  });

  test('shows no size line when the attachment has no size', () {
    expect(
      infos({'contentType': 'application/pdf', 'title': 'scan.pdf'}).join(),
      isNot(contains('Size')),
    );
  });
}
