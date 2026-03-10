import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

@lazySingleton
class PathResolver {
  String? _documentsPath;

  static final _containerPattern =
      RegExp(r'/Containers/Data/Application/[^/]+/Documents/');

  Future<String> _getDocumentsPath() async {
    if (_documentsPath != null) return _documentsPath!;
    final dir = await getApplicationDocumentsDirectory();
    _documentsPath = dir.path;
    return _documentsPath!;
  }

  Future<String> toRelative(String path) async {
    if (path.isEmpty) return path;
    if (!path.startsWith('/')) return path;

    final docsPath = await _getDocumentsPath();
    final prefix = '$docsPath/';

    if (path.startsWith(prefix)) {
      return path.substring(prefix.length);
    }

    final match = _containerPattern.firstMatch(path);
    if (match != null) {
      return path.substring(match.end);
    }

    return path;
  }

  Future<String> toAbsolute(String path) async {
    if (path.isEmpty) return path;

    if (path.startsWith('/')) {
      final docsPath = await _getDocumentsPath();
      if (path.startsWith(docsPath)) return path;

      final match = _containerPattern.firstMatch(path);
      if (match != null) {
        return '$docsPath/${path.substring(match.end)}';
      }
      return path;
    }

    final docsPath = await _getDocumentsPath();
    return '$docsPath/$path';
  }

  Future<List<String>> resolveAll(List<String> paths) async {
    if (paths.isEmpty) return paths;
    return Future.wait(paths.map(toAbsolute));
  }

  Future<String> resolveFileUrl(String fileUrl) async {
    if (!fileUrl.startsWith('file://')) return fileUrl;
    final path = fileUrl.substring(7);
    final resolved = await toAbsolute(path);
    return 'file://$resolved';
  }

  Future<String> toRelativeFileUrl(String fileUrl) async {
    if (!fileUrl.startsWith('file://')) return fileUrl;
    final path = fileUrl.substring(7);
    final relative = await toRelative(path);
    return 'file://$relative';
  }
}
