import 'package:injectable/injectable.dart';

@lazySingleton
class ExternalFilesService {
  List<String> _filePaths = [];

  void addFilePaths(List<String> paths) {
    _filePaths.addAll(paths);
  }

  List<String> consumeFilePaths() {
    final paths = List<String>.from(_filePaths);
    _filePaths.clear();
    return paths;
  }

  bool get hasPendingFiles => _filePaths.isNotEmpty;
}