import 'package:flutter/material.dart';

class HomeHighlightController {
  late final GlobalKey firstVitalCardKey;
  late final GlobalKey firstOverviewCardKey;
  late final GlobalKey firstSpecialtyCardKey;

  HomeHighlightController() {
    _initializeKeys();
  }

  void _initializeKeys() {
    firstVitalCardKey = GlobalKey(debugLabel: 'First Vital Card');
    firstOverviewCardKey = GlobalKey(debugLabel: 'First Overview Card');
    firstSpecialtyCardKey = GlobalKey(debugLabel: 'First Specialty Card');
  }

  List<GlobalKey> get highlightTargetKeys => [
        firstVitalCardKey,
        firstSpecialtyCardKey,
        firstOverviewCardKey,
      ];
}

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

  List<GlobalKey> get highlightTargetKeys => [
        setupButtonKey,
        loadDemoDataButtonKey,
        syncDataButtonKey,
      ];
}
