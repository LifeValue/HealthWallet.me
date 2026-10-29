import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

typedef DirectoryProvider = Future<Directory> Function();

/// Deletes the health-data files the app leaves in the temporary directory:
/// share payloads, received share sessions, IPS PDFs and the wallet pass.
///
/// Only top-level entries with these exact names are deleted, never the
/// temporary directory itself: on Windows it is the user's shared `%TEMP%`.
/// The OCR page cache (`pdf_page_*`) and `resized_*` images are kept unless
/// [includeProcessingCache] is set, because processing sessions may still use
/// them.
///
/// The files are named from the constants below, so a producer and the sweep
/// can't drift apart.
class TempFileSweeper {
  TempFileSweeper({
    this._temporaryDirectory = getTemporaryDirectory,
    this._documentsDirectory = getApplicationDocumentsDirectory,
    bool? deleteDebugLogs,
    this.includeProcessingCache = false,
  }) : deleteDebugLogs =
           deleteDebugLogs ?? deleteDebugLogsFor(releaseMode: kReleaseMode);

  /// Prefix of an encrypted share payload being sent:
  /// `share_<payload id>.bin`. Older builds wrote it as plaintext `.json`,
  /// which the sweep still deletes.
  static const sharePayloadPrefix = 'share_';

  /// Prefix of a received share's attachment directory:
  /// `share_session_<payload id>`.
  static const shareSessionPrefix = 'share_session_';

  /// Separator in an IPS export's name: `<patient> - IPS Summary - <date>.pdf`.
  static const ipsSummaryInfix = ' - IPS Summary - ';

  /// The Apple Wallet pass written before it is handed to Wallet.
  static const walletPassFileName = 'HealthWallet_Emergency.pkpass';

  /// Prefix of a PDF page rendered for OCR and AI. Unique to this app,
  /// because on Windows the temporary directory is the user's shared `%TEMP%`
  /// and Reset deletes every top-level file with this prefix.
  static const ocrPagePrefix = 'healthwallet_pdf_page_';

  /// Prefix of an image downscaled for AI; unique for the same reason.
  static const resizedImagePrefix = 'healthwallet_resized_';

  /// Prefix of a record's attachment decoded to view it:
  /// `healthwallet_record_preview_<uuid>.<ext>`. The viewer deletes it when
  /// it closes; the sweep catches what a crash left.
  static const recordPreviewPrefix = 'healthwallet_record_preview_';

  /// Directory in the documents directory holding the OCR cache metadata
  /// (`<sha256 cache key>.json`, listing the `pdf_page_*` images).
  static const ocrCacheDirName = 'pdf_preview_cache';

  /// Debug logs older builds wrote to the documents directory.
  static const shareDebugLogName = 'share_debug.log';
  static const scanDebugLogName = 'scan_debug.log';

  /// `share_<id>.bin` for the payload [id].
  static String sharePayloadName(String id) => '$sharePayloadPrefix$id.bin';

  /// `share_session_<id>` for the payload [id].
  static String shareSessionName(String id) => '$shareSessionPrefix$id';

  /// `healthwallet_record_preview_<id>.<extension>` for a new random [id].
  static String recordPreviewName(String extension) =>
      '$recordPreviewPrefix${const Uuid().v4()}.$extension';

  /// The IPS export's file name without extension.
  static String ipsSummaryName(String patient, String date) =>
      '$patient$ipsSummaryInfix$date';

  /// Whether a build in [releaseMode] deletes the old debug logs: release
  /// builds no longer write them.
  static bool deleteDebugLogsFor({required bool releaseMode}) => releaseMode;

  final DirectoryProvider _temporaryDirectory;
  final DirectoryProvider _documentsDirectory;

  /// Whether [sweep] also deletes the old debug logs.
  final bool deleteDebugLogs;

  /// Whether [sweep] also deletes the OCR page images, the downscaled images
  /// and the OCR cache metadata. Only for a full reset, which also deletes
  /// the processing sessions that use them.
  final bool includeProcessingCache;

  static const _debugLogs = [shareDebugLogName, scanDebugLogName];

  static final _sharePayload = RegExp(
    '^${RegExp.escape(sharePayloadPrefix)}(.+)\\.(?:bin|json)\$',
  );
  static final _shareSession = RegExp(
    '^${RegExp.escape(shareSessionPrefix)}(.+)\$',
  );
  static final _ipsSummary = RegExp(
    '^.*${RegExp.escape(ipsSummaryInfix)}.*\\.pdf\$',
  );
  static final _ocrCacheMetadata = RegExp(r'^[0-9a-f]{64}\.json$');
  static final _recordPreview = RegExp(
    '^${RegExp.escape(recordPreviewPrefix)}(.+)\\.[a-z0-9]+\$',
  );

  /// Deletes the known temp files and, when set, the old debug logs and the
  /// processing cache. Never throws: each failure is logged and the sweep
  /// goes on.
  Future<void> sweep() async {
    await _sweepTemporaryDirectory();
    if (deleteDebugLogs) await _deleteDebugLogs();
    if (includeProcessingCache) await _deleteOcrCacheMetadata();
  }

  Future<void> _sweepTemporaryDirectory() async {
    final List<FileSystemEntity> entries;
    try {
      final dir = await _temporaryDirectory();
      if (!await dir.exists()) return;
      entries = await dir.list(followLinks: false).toList();
    } catch (e, s) {
      logger.w('Temp sweep: listing the temporary directory failed', e, s);
      return;
    }

    for (final entry in entries) {
      final name = p.basename(entry.path);
      final delete = switch (entry) {
        File() => _isHealthDataFile(name) || _isProcessingCacheFile(name),
        Directory() => _isShareSession(name),
        _ => false,
      };
      if (!delete) continue;
      await _delete(entry, name);
    }
  }

  bool _isProcessingCacheFile(String name) =>
      includeProcessingCache &&
      (name.startsWith(ocrPagePrefix) || name.startsWith(resizedImagePrefix));

  static bool _isHealthDataFile(String name) {
    if (name == walletPassFileName || _ipsSummary.hasMatch(name)) return true;
    final preview = _recordPreview.firstMatch(name);
    if (preview != null && _isUuid(preview.group(1)!)) return true;
    final match = _sharePayload.firstMatch(name);
    return match != null && _isUuid(match.group(1)!);
  }

  static bool _isShareSession(String name) {
    final match = _shareSession.firstMatch(name);
    return match != null && _isUuid(match.group(1)!);
  }

  static bool _isUuid(String value) => Uuid.isValidUUID(
    fromString: value,
    validationMode: ValidationMode.nonStrict,
  );

  Future<void> _delete(FileSystemEntity entry, String name) async {
    try {
      await entry.delete(recursive: entry is Directory);
    } catch (e, s) {
      logger.w('Temp sweep: deleting $name failed', e, s);
    }
  }

  Future<Directory?> _documents() async {
    try {
      return await _documentsDirectory();
    } catch (e, s) {
      logger.w('Temp sweep: finding the documents directory failed', e, s);
      return null;
    }
  }

  Future<void> _deleteDebugLogs() async {
    final dir = await _documents();
    if (dir == null) return;
    for (final name in _debugLogs) {
      final file = File(p.join(dir.path, name));
      try {
        if (await file.exists()) await file.delete();
      } catch (e, s) {
        logger.w('Temp sweep: deleting $name failed', e, s);
      }
    }
  }

  Future<void> _deleteOcrCacheMetadata() async {
    final docs = await _documents();
    if (docs == null) return;
    final List<FileSystemEntity> entries;
    try {
      final dir = Directory(p.join(docs.path, ocrCacheDirName));
      if (!await dir.exists()) return;
      entries = await dir.list(followLinks: false).toList();
    } catch (e, s) {
      logger.w('Temp sweep: listing the OCR cache failed', e, s);
      return;
    }
    for (final entry in entries) {
      final name = p.basename(entry.path);
      if (entry is File && _ocrCacheMetadata.hasMatch(name)) {
        await _delete(entry, name);
      }
    }
  }
}
