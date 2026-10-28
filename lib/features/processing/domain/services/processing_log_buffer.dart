import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

/// In-memory and on-disk log of the scan pipeline, shown by the terminal icon on
/// the processing screen.
///
/// The entries hold patient data, so the buffer only exists in debug and
/// profile builds: in release builds [log] is a no-op, nothing is kept in
/// memory and no file is written.
class ProcessingLogBuffer extends ChangeNotifier {
  ProcessingLogBuffer._({required this.isEnabled, this._directory});

  /// A buffer that writes to [directory] instead of the documents directory.
  @visibleForTesting
  ProcessingLogBuffer.forTesting({
    required bool enabled,
    required Directory directory,
  }) : this._(isEnabled: enabled, directory: directory);

  static final ProcessingLogBuffer _default = ProcessingLogBuffer._(
    isEnabled: enabledFor(releaseMode: kReleaseMode),
  );

  /// Whether a build in [releaseMode] keeps the log: only debug and profile
  /// builds do, since the entries hold patient data.
  @visibleForTesting
  static bool enabledFor({required bool releaseMode}) => !releaseMode;
  static ProcessingLogBuffer _instance = _default;

  static ProcessingLogBuffer get instance => _instance;

  /// Replaces [instance] with [buffer]; `null` restores the default one.
  @visibleForTesting
  static void debugOverrideInstance(ProcessingLogBuffer? buffer) =>
      _instance = buffer ?? _default;

  /// Name of the log file in the documents directory.
  static const String logFileName = TempFileSweeper.scanDebugLogName;

  static const int _maxEntries = 500;

  /// Whether the log is kept; false in release builds.
  final bool isEnabled;

  final Directory? _directory;
  final List<String> _entries = [];
  File? _logFile;
  Future<void> _pendingWrite = Future.value();

  List<String> getAll() => List.unmodifiable(_entries);

  int get length => _entries.length;

  Future<File> _ensureLogFile() async {
    return _logFile ??= File(
      '${(_directory ?? await getApplicationDocumentsDirectory()).path}'
      '/$logFileName',
    );
  }

  void log(String message) {
    if (!isEnabled) return;
    debugPrint(message);
    _entries.add(message);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
    _appendToFile(message);
  }

  void _appendToFile(String message) {
    _pendingWrite = _pendingWrite
        .then((_) async {
          final file = await _ensureLogFile();
          await file.writeAsString(
            '$message\n',
            mode: FileMode.append,
            flush: true,
          );
        })
        .catchError((Object e) {
          // The log is a debugging aid: a failed write must not break the
          // scan pipeline, so it is reported and dropped.
          logger.w('Writing $logFileName failed', e);
        });
  }

  Future<String> readPersistedLogs() async {
    if (!isEnabled) return '';
    await _pendingWrite;
    final file = await _ensureLogFile();
    if (await file.exists()) {
      return file.readAsString();
    }
    return '';
  }

  Future<void> clearPersistedLogs() async {
    if (!isEnabled) return;
    await _pendingWrite;
    final file = await _ensureLogFile();
    if (await file.exists()) {
      await file.writeAsString('');
    }
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
