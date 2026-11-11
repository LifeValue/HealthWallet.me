import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/features/processing/domain/ai_settings_reset.dart';

void main() {
  group('mistakenAiSettings', () {
    test('a fresh install has nothing to reset', () {
      for (final isDesktop in [true, false]) {
        expect(
          mistakenAiSettings(
            savedMaxTokens: null,
            savedUseVision: null,
            isDesktop: isDesktop,
          ),
          isEmpty,
        );
      }
    });

    test('a saved 500 token limit is reset on every platform', () {
      for (final isDesktop in [true, false]) {
        expect(
          mistakenAiSettings(
            savedMaxTokens: 500,
            savedUseVision: null,
            isDesktop: isDesktop,
          ),
          [SharedPrefsConstants.aiMaxTokens],
        );
      }
    });

    test('any other token limit is kept', () {
      expect(
        mistakenAiSettings(
          savedMaxTokens: 2000,
          savedUseVision: null,
          isDesktop: false,
        ),
        isEmpty,
      );
    });

    test('Deep Scan saved off is reset on the desktop only', () {
      expect(
        mistakenAiSettings(
          savedMaxTokens: null,
          savedUseVision: false,
          isDesktop: true,
        ),
        [SharedPrefsConstants.aiUseVision],
      );
      expect(
        mistakenAiSettings(
          savedMaxTokens: null,
          savedUseVision: false,
          isDesktop: false,
        ),
        isEmpty,
      );
    });

    test('Deep Scan saved on is kept', () {
      for (final isDesktop in [true, false]) {
        expect(
          mistakenAiSettings(
            savedMaxTokens: null,
            savedUseVision: true,
            isDesktop: isDesktop,
          ),
          isEmpty,
        );
      }
    });

    test('both are reset together on the desktop', () {
      expect(
        mistakenAiSettings(
          savedMaxTokens: 500,
          savedUseVision: false,
          isDesktop: true,
        ),
        [SharedPrefsConstants.aiMaxTokens, SharedPrefsConstants.aiUseVision],
      );
    });
  });
}
