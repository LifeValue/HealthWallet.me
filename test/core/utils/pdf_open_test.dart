import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/pdf_open.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a file that cannot be opened fails with an error the caller can '
      'handle, on any host', () async {
    // On Linux pdfx is unsupported and the platform check throws; on macOS
    // the plugin itself is missing in tests. Either way the error reaches
    // the caller instead of escaping the zone.
    await expectLater(
      openPdfDocument('/nowhere/report.pdf'),
      throwsA(anything),
    );
  });
}
