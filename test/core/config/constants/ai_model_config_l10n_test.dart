import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

void main() {
  final configs = AiModelVariant.values.map(AiModelConfig.fromVariant);
  final en = lookupAppLocalizations(const Locale('en'));

  test('English names are unchanged and descriptions are the summary with '
      'the size', () {
    for (final config in configs) {
      expect(config.localizedName(en), config.displayName);
      expect(
        config.localizedDescription(en),
        '${config.summary} (~${config.sizeGb} GB)',
      );
    }
  });

  test('the size shown is the model file size, rounded to 0.1 GB', () {
    expect(AiModelConfig.qwen.sizeGb, 1.1);
    expect(AiModelConfig.qwen35x4b.sizeGb, 2.6);
    expect(AiModelConfig.qwen7b.sizeGb, 4.6);
    expect(
      AiModelConfig.qwen7b.localizedDescription(en),
      'Best accuracy for desktop (~4.6 GB)',
    );
  });

  test('Romanian translates the offered tiers and formats sizes', () {
    final ro = lookupAppLocalizations(const Locale('ro'));
    expect(AiModelConfig.qwen35x4b.localizedName(ro), 'Avansat');
    expect(AiModelConfig.qwen.localizedName(ro), 'Lite');
    expect(
      AiModelConfig.qwen.localizedDescription(ro),
      'Rapid și ușor (~1,1 GB)',
    );
    expect(
      AiModelConfig.qwen7b.localizedDescription(ro),
      'Cea mai bună precizie pentru desktop (~4,6 GB)',
    );
  });
}
