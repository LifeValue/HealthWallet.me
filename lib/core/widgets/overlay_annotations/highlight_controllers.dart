import 'package:flutter/material.dart';

/// Controller that manages GlobalKeys for home page highlight targets.
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

  /// Returns all highlight target keys.
  List<GlobalKey> get highlightTargetKeys => [
        firstVitalCardKey,
        firstOverviewCardKey,
      ];
}

/// Controller that manages GlobalKeys for sync placeholder highlight targets.
class SyncPlaceholderHighlightController {
  late final GlobalKey setupButtonKey;
  late final GlobalKey loadDemoDataButtonKey;
  late final GlobalKey syncDataButtonKey;

  SyncPlaceholderHighlightController() {
    _initializeKeys();
  }

  void _initializeKeys() {
    setupButtonKey = GlobalKey(debugLabel: 'Setup Button');
    loadDemoDataButtonKey = GlobalKey(debugLabel: 'Load Demo Data Button');
    syncDataButtonKey = GlobalKey(debugLabel: 'Sync Data Button');
  }

  /// Returns all highlight target keys in order (Setup, Load Demo Data, Sync Data).
  List<GlobalKey> get highlightTargetKeys => [
        setupButtonKey,
        loadDemoDataButtonKey,
        syncDataButtonKey,
      ];
}

/// Constants for home onboarding overlay.
class HomeOnboardingConstants {
  static const String reorderMessage =
      'Long press to reorder them according to your preference.';

  static const String subtitle = 'Tap to continue';

  HomeOnboardingConstants._();
}
