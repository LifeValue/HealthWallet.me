import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/records/presentation/pages/records_list_body.dart';

void main() {
  group('a long press on a record', () {
    test('starts selecting on mobile, for Share nearby', () {
      expect(
        RecordsListBody.canStartSelection(
          isDesktop: false,
          isSelectionMode: false,
        ),
        isTrue,
      );
    });

    test('does nothing on desktop, which has no selection bar to leave it', () {
      expect(
        RecordsListBody.canStartSelection(
          isDesktop: true,
          isSelectionMode: false,
        ),
        isFalse,
      );
    });

    test('does nothing while already selecting', () {
      for (final isDesktop in [false, true]) {
        expect(
          RecordsListBody.canStartSelection(
            isDesktop: isDesktop,
            isSelectionMode: true,
          ),
          isFalse,
        );
      }
    });
  });
}
