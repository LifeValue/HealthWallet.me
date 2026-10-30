import 'dart:io';

import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

@lazySingleton
class AttachmentSyncService {
  final PathResolver _pathResolver;

  AttachmentSyncService(this._pathResolver);

  /// The directory attachments live in on this device.
  Future<String> documentsPath() => _pathResolver.getDocumentsPath();

  /// Finds the local file for an attachment path stored in a record or sent
  /// by the peer in a `file_request`.
  ///
  /// The path is untrusted, so only regular files inside the documents
  /// directory are returned, also after following symbolic links. Paths from
  /// another device fall back to the same file name in the documents
  /// directory, or to the same place under an old iOS app container.
  Future<File?> resolveFile(String storedPath) async {
    final docsPath = p.normalize(await _pathResolver.getDocumentsPath());
    if (storedPath.isEmpty) return null;

    final candidates = <String>[
      if (_isAbsolute(storedPath))
        p.normalize(storedPath)
      else
        p.normalize(p.join(docsPath, storedPath)),
    ];

    final match = _containerPattern.firstMatch(storedPath);
    if (match != null) {
      candidates.add(p.normalize(p.join(docsPath, match.group(1)!)));
    }

    final fileName = storedPath.split(RegExp(r'[/\\]')).last;
    if (fileName.isNotEmpty && fileName != '.' && fileName != '..') {
      candidates.add(p.join(docsPath, fileName));
    }

    for (final candidate in candidates) {
      final file = await _insideDocs(candidate, docsPath);
      if (file != null) return file;
    }
    return null;
  }

  static final _containerPattern = RegExp(
    r'/Containers/Data/Application/[^/]+/Documents/(.+)',
  );

  static bool _isAbsolute(String path) =>
      p.isAbsolute(path) ||
      path.startsWith('/') ||
      path.startsWith(r'\') ||
      RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(path);

  /// The real file behind [candidate] when it is inside [docsPath] and is not
  /// the database (`db.sqlite`, `-wal`, `-shm`, …), which lives there too.
  Future<File?> _insideDocs(String candidate, String docsPath) async {
    if (!p.isWithin(docsPath, candidate) || _isDatabase(candidate)) return null;
    final file = File(candidate);
    if (!await file.exists()) return null;
    final String realFile;
    try {
      final realDocs = await Directory(docsPath).resolveSymbolicLinks();
      realFile = await file.resolveSymbolicLinks();
      if (!p.isWithin(realDocs, realFile) || _isDatabase(realFile)) return null;
    } on FileSystemException catch (e) {
      logger.w('Attachment path could not be resolved: $candidate', e);
      return null;
    }
    return File(realFile);
  }

  static bool _isDatabase(String path) =>
      p.basename(path).toLowerCase().startsWith('db.sqlite');
}
