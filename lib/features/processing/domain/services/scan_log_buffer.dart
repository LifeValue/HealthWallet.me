import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ScanLogBuffer extends ChangeNotifier {
  ScanLogBuffer._();

  static final ScanLogBuffer instance = ScanLogBuffer._();

  static const int _maxEntries = 500;

  final List<String> _entries = [];
  File? _logFile;

  List<String> getAll() => List.unmodifiable(_entries);

  int get length => _entries.length;

  Future<void> _ensureLogFile() async {
    if (_logFile != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/scan_debug.log');
  }

  void log(String message) {
    debugPrint(message);
    _entries.add(message);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
    _appendToFile(message);
  }

  void _appendToFile(String message) {
    _ensureLogFile().then((_) {
      _logFile?.writeAsString(
        '$message\n',
        mode: FileMode.append,
        flush: true,
      );
    }).catchError((_) {});
  }

  Future<String> readPersistedLogs() async {
    await _ensureLogFile();
    if (_logFile != null && await _logFile!.exists()) {
      return _logFile!.readAsString();
    }
    return '';
  }

  Future<void> clearPersistedLogs() async {
    await _ensureLogFile();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
