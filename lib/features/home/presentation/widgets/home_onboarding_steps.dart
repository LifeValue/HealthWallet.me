import 'package:flutter/material.dart';

/// Controller that manages GlobalKeys for onboarding highlight targets
class HomeHighlightController {
  late final GlobalKey firstVitalCardKey;
  late final GlobalKey firstOverviewCardKey;

  HomeHighlightController() {
    _initializeKeys();
  }

  void _initializeKeys() {
    firstVitalCardKey = GlobalKey(debugLabel: 'First Vital Card');
    firstOverviewCardKey = GlobalKey(debugLabel: 'First Overview Card');
  }

  /// Returns all highlight target keys
  List<GlobalKey> get highlightTargetKeys => [
        firstVitalCardKey,
        firstOverviewCardKey,
      ];
}

/// Constants for home onboarding
class HomeOnboardingConstants {
  static const String reorderMessage =
      'Long press to reorder them according to your preference.';

  HomeOnboardingConstants._();
}
