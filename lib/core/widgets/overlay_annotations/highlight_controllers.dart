import 'package:flutter/material.dart';

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

  List<GlobalKey> get highlightTargetKeys => [
        firstVitalCardKey,
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
