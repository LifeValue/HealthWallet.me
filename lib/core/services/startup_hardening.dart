import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';

/// Startup steps both entry points run before anything else: silence
/// `debugPrint` in release builds (its output can hold patient data) and
/// sweep the health-data files a previous run left in temp.
///
/// Returns the sweep, which the entry points don't wait for.
Future<void> hardenStartup({
  required bool releaseMode,
  TempFileSweeper? sweeper,
}) {
  if (releaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  return (sweeper ??
          TempFileSweeper(
            deleteDebugLogs: TempFileSweeper.deleteDebugLogsFor(
              releaseMode: releaseMode,
            ),
          ))
      .sweep();
}
