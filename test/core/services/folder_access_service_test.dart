import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/folder_access_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/fs');
  final calls = <MethodCall>[];
  late Object? Function(MethodCall call) answer;

  setUp(() {
    calls.clear();
    answer = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final result = answer(call);
          if (result is PlatformException) throw result;
          return result;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  FolderAccessService service({bool usesBookmarks = true}) =>
      FolderAccessService(channel: channel, usesBookmarks: usesBookmarks);

  group('without a sandbox (Windows)', () {
    test('makes no bookmark and needs no restore', () async {
      final access = service(usesBookmarks: false);

      expect(await access.bookmarkFor('/a'), isNull);
      expect(await access.restore('b'), 'b');
      expect(calls, isEmpty);
    });
  });

  group('on macOS', () {
    test('asks the platform for a bookmark of the chosen folder', () async {
      answer = (_) => 'Ym9va21hcms=';

      expect(await service().bookmarkFor('/Users/me/Backups'), 'Ym9va21hcms=');
      expect(calls.single.method, 'createBookmark');
      expect(calls.single.arguments, {'path': '/Users/me/Backups'});
    });

    test('a failed bookmark is logged, not thrown', () async {
      answer = (_) => PlatformException(code: 'bookmark_failed');

      expect(await service().bookmarkFor('/x'), isNull);
    });

    test('restoring keeps the same bookmark when it is still valid', () async {
      answer = (_) => {'path': '/x', 'granted': true, 'bookmark': null};

      expect(await service().restore('saved'), 'saved');
      expect(calls.single.method, 'resolveBookmark');
      expect(calls.single.arguments, {'bookmark': 'saved'});
    });

    test('a stale bookmark is replaced by the fresh one', () async {
      answer = (_) => {'path': '/x', 'granted': true, 'bookmark': 'fresh'};

      expect(await service().restore('stale'), 'fresh');
    });

    test('access refused or failing returns null', () async {
      answer = (_) => {'path': '/x', 'granted': false, 'bookmark': null};
      expect(await service().restore('saved'), isNull);

      answer = (_) => PlatformException(code: 'bookmark_failed');
      expect(await service().restore('saved'), isNull);
    });
  });

  test('a channel not registered yet is logged, not thrown', () async {
    final access = FolderAccessService(
      channel: const MethodChannel('test/not-registered'),
      usesBookmarks: true,
    );

    expect(await access.bookmarkFor('/x'), isNull);
    expect(await access.restore('saved'), isNull);
  });
}
