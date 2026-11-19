import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';

void main() {
  group('canHandOver', () {
    for (final status in ProcessingStatus.values) {
      final expected =
          status != ProcessingStatus.draft &&
          status != ProcessingStatus.handedOver;
      test('${status.name}: ${expected ? 'can' : 'cannot'} be sent', () {
        expect(
          ProcessingSession(
            id: 's',
            filePaths: const ['page.jpg'],
            status: status,
          ).canHandOver,
          expected,
        );
      });
    }

    test('a session without files cannot be sent', () {
      expect(const ProcessingSession(id: 's').canHandOver, isFalse);
    });
  });
}
