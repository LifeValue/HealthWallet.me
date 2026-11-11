import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/processing/data/data_source/local/processing_local_data_source.dart';
import 'package:health_wallet/features/processing/data/data_source/network/ai_inference_data_source.dart';
import 'package:health_wallet/features/processing/data/repository/processing_repository_impl.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

import '../../../../helpers/log_capture.dart';
import '../../../share_records/share_test_helpers.dart';

class _FakeLocalDataSource extends Fake implements ProcessingLocalDataSource {
  final deleted = <String>[];

  @override
  Future<int> deleteProcessingSession(String id) async {
    deleted.add(id);
    return 1;
  }
}

class _FakeNetworkDataSource extends Fake implements AiInferenceDataSource {}

class _FakeTextRecognitionService extends Fake
    implements TextRecognitionService {}

/// A file that exists but cannot be deleted. CI runs as root, so a
/// permission can't make the delete fail.
class _UndeletableFile extends Fake implements File {
  _UndeletableFile(this.path);

  @override
  final String path;

  @override
  Future<bool> exists() async => true;

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async =>
      throw FileSystemException('Cannot delete', path);
}

/// Makes the file at [path] undeletable; every other file is real.
final class _UndeletableAt extends IOOverrides {
  _UndeletableAt(this.path);

  final String path;

  @override
  File createFile(String path) =>
      path == this.path ? _UndeletableFile(path) : super.createFile(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
  late Directory root;
  late _FakeLocalDataSource local;
  late ProcessingRepositoryImpl repository;

  setUp(() {
    root = mockPathProvider();
    local = _FakeLocalDataSource();
    repository = ProcessingRepositoryImpl(
      _FakeNetworkDataSource(),
      local,
      _FakeTextRecognitionService(),
      PathResolver(),
    );
  });

  test('deleting a session deletes its files, stored relative or '
      'absolute', () async {
    final relative = File('${root.path}/Documents/imports/a.pdf')
      ..createSync(recursive: true);
    final absolute = File('${root.path}/Documents/imports/b.jpg')
      ..createSync(recursive: true);

    await repository.deleteProcessingSession(
      ProcessingSession(
        id: 's',
        filePaths: ['imports/a.pdf', absolute.path, 'imports/gone.jpg'],
      ),
    );

    expect(relative.existsSync(), isFalse);
    expect(absolute.existsSync(), isFalse);
    expect(local.deleted, ['s']);
    expect(logs, isEmpty);
  });

  test('a file that cannot be deleted is logged and the session still '
      'goes', () async {
    final kept = '${root.path}/Documents/imports/kept.pdf';
    final other = File('${root.path}/Documents/imports/other.pdf')
      ..createSync(recursive: true);

    await IOOverrides.runWithIOOverrides(
      () => repository.deleteProcessingSession(
        ProcessingSession(id: 's', filePaths: [kept, other.path]),
      ),
      _UndeletableAt(kept),
    );

    expect(local.deleted, ['s']);
    expect(other.existsSync(), isFalse);
    expect(logs, loggedWarning('Deleting a file of session s failed'));
  });
}
