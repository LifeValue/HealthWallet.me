import 'dart:async';

import 'package:injectable/injectable.dart';

/// Keeps a backup restore and the attachment file cleaner apart.
///
/// A restore decides to reuse a file already in Documents before the commit
/// that makes its rows refer to it; until then the file looks unreferenced.
/// The restore runs through [exclusive], which waits for a cleaner pass that
/// has already started; the cleaner runs through [ifFree], which skips while
/// a restore runs (the next start-up's sweep catches up).
@lazySingleton
class AttachmentFilesLock {
  Future<void>? _held;

  /// Whether some work holds the lock now.
  bool get isHeld => _held != null;

  /// Runs [work] once nothing else holds the lock, and holds it meanwhile.
  Future<T> exclusive<T>(Future<T> Function() work) async {
    for (var held = _held; held != null; held = _held) {
      await held;
    }
    final done = Completer<void>();
    _held = done.future;
    try {
      return await work();
    } finally {
      _held = null;
      done.complete();
    }
  }

  /// Runs [work] holding the lock when nothing holds it, or returns null
  /// without running it.
  Future<T?> ifFree<T>(Future<T> Function() work) =>
      isHeld ? Future.value() : exclusive(work);
}
