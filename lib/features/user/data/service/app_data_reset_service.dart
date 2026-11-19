import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deletes the user's data for the desktop "Reset" action: every database
/// table, the preferences, the health-data temp files and the stored share
/// sessions.
///
/// Only the app's own temp files go (see [TempFileSweeper]), including the
/// OCR page cache since the processing sessions using it are deleted too; the
/// temporary directory itself is kept, because on Windows it is the user's
/// `%TEMP%`.
class AppDataResetService {
  AppDataResetService(
    this._database, {
    TempFileSweeper? sweeper,
    this._supportDirectory = getApplicationSupportDirectory,
    this._preferences = SharedPreferences.getInstance,
  }) : _sweeper =
           sweeper ??
           TempFileSweeper(deleteDebugLogs: true, includeProcessingCache: true);

  final AppDatabase _database;
  final TempFileSweeper _sweeper;

  @visibleForTesting
  TempFileSweeper get sweeper => _sweeper;
  final DirectoryProvider _supportDirectory;
  final Future<SharedPreferences> Function() _preferences;

  /// Deletes everything it can. Never throws: each failure is logged and the
  /// reset goes on, since the app exits right after.
  Future<void> reset() async {
    // Notes refer to sources, so they go before them; each table on its own,
    // so one failure doesn't keep the rest.
    for (final table in <TableInfo>[
      _database.recordNotes,
      _database.fhirResource,
      _database.sources,
      _database.processingSessions,
    ]) {
      try {
        await _database.delete(table).go();
      } catch (e, s) {
        logger.e('Reset: clearing ${table.actualTableName} failed', e, s);
      }
    }

    try {
      final prefs = await _preferences();
      await prefs.clear();
    } catch (e, s) {
      logger.e('Reset: clearing the preferences failed', e, s);
    }

    await _sweeper.sweep();

    try {
      final supportDir = await _supportDirectory();
      final shareDir = Directory('${supportDir.path}/share_sessions');
      if (shareDir.existsSync()) {
        await shareDir.delete(recursive: true);
      }
    } catch (e, s) {
      logger.w('Reset: clearing the share sessions failed', e, s);
    }
  }
}
