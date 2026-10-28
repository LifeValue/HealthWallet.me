import 'dart:convert';
import 'dart:io';

import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

@lazySingleton
class AttachmentSyncService {
  final PathResolver _pathResolver;
  static const _uuid = Uuid();

  AttachmentSyncService(this._pathResolver);

  Future<List<Map<String, dynamic>>> embedAttachments(
    List<Map<String, dynamic>> rows,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final resourceType = row['resource_type'] as String?;
      if (resourceType == 'DocumentReference') {
        final modified = Map<String, dynamic>.from(row);
        final resourceRaw = row['resource_raw'] as String?;
        if (resourceRaw != null) {
          try {
            final json = jsonDecode(resourceRaw) as Map<String, dynamic>;
            final embedded = await _embedFiles(json);
            if (embedded) {
              modified['resource_raw'] = jsonEncode(json);
            }
          } catch (_) {}
        }
        result.add(modified);
      } else {
        result.add(row);
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> restoreAttachments(
    List<Map<String, dynamic>> rows,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final resourceType = row['resource_type'] as String?;
      if (resourceType == 'DocumentReference') {
        final modified = Map<String, dynamic>.from(row);
        final resourceRaw = row['resource_raw'] as String?;
        if (resourceRaw != null) {
          try {
            final json = jsonDecode(resourceRaw) as Map<String, dynamic>;
            final restored = await _restoreFiles(json);
            if (restored) {
              modified['resource_raw'] = jsonEncode(json);
            }
          } catch (_) {}
        }
        result.add(modified);
      } else {
        result.add(row);
      }
    }
    return result;
  }

  Future<bool> _embedFiles(Map<String, dynamic> json) async {
    final content = json['content'] as List?;
    if (content == null) return false;

    var embedded = false;
    for (final item in content) {
      if (item is! Map<String, dynamic>) continue;
      final attachment = item['attachment'] as Map<String, dynamic>?;
      final url = attachment?['url'] as String?;
      if (url != null && url.startsWith('file://')) {
        final file = await resolveFile(Uri.decodeComponent(url.substring(7)));
        if (file != null) {
          final bytes = await file.readAsBytes();
          attachment!['data'] = base64Encode(bytes);
          attachment.remove('url');
          embedded = true;
        }
      }
    }
    return embedded;
  }

  Future<bool> _restoreFiles(Map<String, dynamic> json) async {
    final content = json['content'] as List?;
    if (content == null) return false;

    final docsPath = await _pathResolver.getDocumentsPath();
    final docsDir = Directory(docsPath);
    var restored = false;

    for (final item in content) {
      if (item is! Map<String, dynamic>) continue;
      final attachment = item['attachment'] as Map<String, dynamic>?;
      final data = attachment?['data'] as String?;
      if (data != null) {
        final bytes = base64Decode(data);
        final title = attachment?['title'] as String? ?? '${_uuid.v4()}.bin';
        final sanitized = title.replaceAll(RegExp(r'[^\w.\-]'), '_');
        final contentType = attachment?['contentType'] as String?;
        final ext = _extensionFromContentType(contentType);
        final hasExt = sanitized.contains('.');
        final uniqueName = hasExt
            ? '${sanitized.substring(0, sanitized.lastIndexOf('.'))}_${_uuid.v4().substring(0, 8)}${sanitized.substring(sanitized.lastIndexOf('.'))}'
            : '${sanitized}_${_uuid.v4().substring(0, 8)}$ext';
        final file = File('${docsDir.path}/$uniqueName');
        await file.writeAsBytes(bytes);
        attachment!['url'] = 'file://$uniqueName';
        attachment.remove('data');
        restored = true;
      }
    }
    return restored;
  }

  static String _extensionFromContentType(String? contentType) {
    switch (contentType) {
      case 'application/pdf':
        return '.pdf';
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      default:
        return '.bin';
    }
  }

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
