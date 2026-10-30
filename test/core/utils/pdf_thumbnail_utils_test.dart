import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/pdf_thumbnail_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a PDF that cannot be opened has no thumbnail, and nothing is thrown, '
      'on any host', () async {
    expect(await renderPdfFirstPage('/nowhere/report.pdf'), isNull);
  });
}
