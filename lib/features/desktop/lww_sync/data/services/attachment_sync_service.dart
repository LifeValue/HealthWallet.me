import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

@lazySingleton
class AttachmentSyncService {
  static const _uuid = Uuid();

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
        final file = await resolveFile(url.substring(7));
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

    final docsDir = await getApplicationDocumentsDirectory();
    var restored = false;

    for (final item in content) {
      if (item is! Map<String, dynamic>) continue;
      final attachment = item['attachment'] as Map<String, dynamic>?;
      final data = attachment?['data'] as String?;
      if (data != null) {
        final bytes = base64Decode(data);
        final title =
            attachment?['title'] as String? ?? '${_uuid.v4()}.bin';
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

  Future<File?> resolveFile(String storedPath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final fileName = storedPath.split('/').last;

    if (!storedPath.startsWith('/')) {
      final resolved = File('${docsDir.path}/$storedPath');
      if (await resolved.exists()) return resolved;
    } else {
      final file = File(storedPath);
      if (await file.exists()) return file;
    }

    final docsFile = File('${docsDir.path}/$fileName');
    if (await docsFile.exists()) return docsFile;

    final cacheDir = await getTemporaryDirectory();
    final cachedFile = File('${cacheDir.path}/$fileName');
    if (await cachedFile.exists()) return cachedFile;

    final match = RegExp(r'/Application/[^/]+/(.+)').firstMatch(storedPath);
    if (match != null) {
      final containerBase = docsDir.parent.path;
      final resolved = File('$containerBase/${match.group(1)!}');
      if (await resolved.exists()) return resolved;
    }

    return null;
  }
}
