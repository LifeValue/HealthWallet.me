import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

@lazySingleton
class PathResolver {
  String? _documentsPath;

  static final _containerPattern =
      RegExp(r'/Containers/Data/Application/[^/]+/Documents/');

  Future<String> getDocumentsPath() async {
    if (_documentsPath != null) return _documentsPath!;
    final dir = await getApplicationDocumentsDirectory();
    if (Platform.isWindows) {
      final hwDir = Directory(p.join(dir.path, 'HealthWallet', 'Documents'));
      if (!await hwDir.exists()) await hwDir.create(recursive: true);
      _documentsPath = hwDir.path;
    } else {
      _documentsPath = dir.path;
    }
    return _documentsPath!;
  }

  bool _isAbsolute(String path) {
    if (path.startsWith('/')) return true;
    if (path.length >= 3 &&
        path[1] == ':' &&
        (path[2] == '\\' || path[2] == '/')) return true;
    return false;
  }

  bool _startsWithDocsPath(String path, String docsPath) {
    final normalized = path.replaceAll('\\', '/');
    final normalizedDocs = docsPath.replaceAll('\\', '/');
    return normalized.startsWith(normalizedDocs);
  }

  Future<String> toRelative(String path) async {
    if (path.isEmpty) return path;

    final docsPath = await getDocumentsPath();

    if (_startsWithDocsPath(path, docsPath)) {
      return path.substring(docsPath.length + 1);
    }

    if (path.startsWith('/')) {
      final match = _containerPattern.firstMatch(path);
      if (match != null) {
        return path.substring(match.end);
      }
    }

    return path;
  }

  Future<String> toAbsolute(String path) async {
    if (path.isEmpty) return path;

    final docsPath = await getDocumentsPath();

    if (_isAbsolute(path)) {
      if (_startsWithDocsPath(path, docsPath)) return path;

      final match = _containerPattern.firstMatch(path);
      if (match != null) {
        return '$docsPath/${path.substring(match.end)}';
      }
      return path;
    }

    return '$docsPath/$path';
  }

  Future<List<String>> resolveAll(List<String> paths) async {
    if (paths.isEmpty) return paths;
    return Future.wait(paths.map(toAbsolute));
  }

  Future<String> resolveFileUrl(String fileUrl) async {
    if (!fileUrl.startsWith('file://')) return fileUrl;
    final path = Uri.decodeComponent(fileUrl.substring(7));
    final resolved = await toAbsolute(path);
    return 'file://$resolved';
  }

  Future<String> toRelativeFileUrl(String fileUrl) async {
    if (!fileUrl.startsWith('file://')) return fileUrl;
    final path = Uri.decodeComponent(fileUrl.substring(7));
    final relative = await toRelative(path);
    return 'file://$relative';
  }
}
