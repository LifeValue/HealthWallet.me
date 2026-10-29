import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';

void main() {
  final configs = AiModelVariant.values.map(AiModelConfig.fromVariant);

  test('English names and descriptions are unchanged', () {
    final en = lookupAppLocalizations(const Locale('en'));
    for (final config in configs) {
      expect(config.localizedName(en), config.displayName);
      expect(config.localizedDescription(en), config.description);
    }
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
      'Cea mai bună precizie pentru desktop (~5 GB)',
    );
  });
}
