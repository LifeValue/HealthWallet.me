import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/deep_link_service.dart';
import 'package:health_wallet/core/services/external_files_service.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import '../../features/desktop/desktop_test_fakes.dart';

class _FakeRouter extends Fake implements AppRouter {
  final pushed = <PageRouteInfo>[];
  final replacedWith = <List<PageRouteInfo>>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }

  @override
  Future<void> replaceAll(
    List<PageRouteInfo> routes, {
    OnNavigationFailure? onFailure,
    bool updateExistingRoutes = true,
  }) async {
    replacedWith.add(routes);
  }
}

class _FakeNavigation extends Fake implements PageViewNavigationController {
  @override
  int currentPage = 0;
  final calls = <String>[];

  @override
  void jumpToPage(int pageIndex) {
    calls.add('jump:$pageIndex');
    currentPage = pageIndex;
  }

  @override
  Future<void> navigateToPage(
    int pageIndex, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
  }) async {
    calls.add('navigate:$pageIndex');
    currentPage = pageIndex;
  }
}

class _FakeAppLinks extends Fake implements AppLinks {
  /// Closes its stream when the test that made it ends.
  _FakeAppLinks({this.initial, this.initialError}) {
    addTearDown(close);
  }

  final Uri? initial;
  final Error? initialError;
  final links = StreamController<Uri>.broadcast();
  var initialLinkReads = 0;

  @override
  Future<Uri?> getInitialLink() async {
    initialLinkReads++;
    if (initialError != null) throw initialError!;
    return initial;
  }

  /// Like app_links 6+: the stream delivers the link the app was opened
  /// with first, then the later ones.
  @override
  Stream<Uri> get uriLinkStream async* {
    if (initialError != null) throw initialError!;
    if (initial != null) yield initial!;
    yield* links.stream;
  }

  Future<void> close() => links.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late _FakeRouter router;
  late _FakeNavigation navigation;
  late ExternalFilesService externalFiles;
  late List<Uri> requests;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('deep_link_test_');
    mockPathProvider(docs);
    router = _FakeRouter();
    navigation = _FakeNavigation();
    externalFiles = ExternalFilesService();
    requests = [];
  });

  tearDown(() {
    clearPathProviderMock();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  DeepLinkService service({AppLinks? appLinks}) => DeepLinkService(
    router,
    externalFiles,
    navigation,
    appLinks: appLinks ?? _FakeAppLinks(),
  );

  /// Runs [body] with `package:http` answering [status] and [body] bytes.
  Future<T> withHttp<T>(
    Future<T> Function() body, {
    int status = 200,
    List<int> bytes = const [1, 2, 3],
  }) => http.runWithClient(
    body,
    () => MockClient((request) async {
      requests.add(request.url);
      return http.Response.bytes(bytes, status);
    }),
  );

  String downloads() => p.join(docs.path, 'provider_downloads');

  Uri addLink({
    String? file = 'https://provider.example/doc.pdf',
    String? name,
  }) => Uri.https('add.healthwallet.me', '/', {
    'file': ?file,
    'name': ?name,
  });

  group('safeFileName', () {
    test('keeps a normal name as it is', () {
      expect(DeepLinkService.safeFileName('Lab report.pdf'), 'Lab report.pdf');
    });

    test('keeps unicode names', () {
      expect(
        DeepLinkService.safeFileName('Résultat analyse 血液 ✓.pdf'),
        'Résultat analyse 血液 ✓.pdf',
      );
    });

    test('reduces a traversal to its last segment', () {
      expect(DeepLinkService.safeFileName('../../db.sqlite'), 'db.sqlite');
      expect(DeepLinkService.safeFileName(r'..\..\db.sqlite'), 'db.sqlite');
    });

    test('reduces an absolute path to its file name', () {
      expect(DeepLinkService.safeFileName('/etc/passwd'), 'passwd');
      expect(
        DeepLinkService.safeFileName(r'C:\Users\me\evil.pdf'),
        'evil.pdf',
      );
    });

    test('drops control characters and surrounding spaces', () {
      expect(DeepLinkService.safeFileName(' a\nb\x00c.pdf '), 'abc.pdf');
    });

    test('gives null when nothing usable is left', () {
      for (final name in [null, '', '   ', '.', '..', 'a/..', 'dir/', '\x01']) {
        expect(DeepLinkService.safeFileName(name), isNull, reason: '$name');
      }
    });
  });

  group('downloadFile', () {
    test(
      'saves the bytes under provider_downloads with the given name',
      () async {
        final path = await withHttp(
          () => service().downloadFile(
            'https://provider.example/doc.pdf',
            customFileName: 'Lab report.pdf',
          ),
          bytes: utf8.encode('pdf bytes'),
        );

        expect(path, p.join(downloads(), 'Lab report.pdf'));
        expect(File(path).readAsStringSync(), 'pdf bytes');
        expect(requests, [Uri.parse('https://provider.example/doc.pdf')]);
      },
    );

    test('a traversal name stays inside provider_downloads', () async {
      final path = await withHttp(
        () => service().downloadFile(
          'https://provider.example/doc.pdf',
          customFileName: '../../db.sqlite',
        ),
      );

      expect(path, p.join(downloads(), 'db.sqlite'));
      expect(File(path).existsSync(), isTrue);
      expect(File(p.join(docs.path, 'db.sqlite')).existsSync(), isFalse);
      expect(docs.listSync().map((e) => p.basename(e.path)), [
        'provider_downloads',
      ]);
    });

    test('an absolute name stays inside provider_downloads', () async {
      final path = await withHttp(
        () => service().downloadFile(
          'https://provider.example/doc.pdf',
          customFileName: '/etc/passwd',
        ),
      );

      expect(path, p.join(downloads(), 'passwd'));
    });

    for (final name in [null, '', '.', '..']) {
      test('generates a name from the URL when the name is "$name"', () async {
        final path = await withHttp(
          () => service().downloadFile(
            'https://provider.example/files/scan.png?x=1',
            customFileName: name,
          ),
        );

        expect(p.dirname(path), downloads());
        expect(p.basename(path), matches(RegExp(r'^provider_doc_\d+\.png$')));
      });
    }

    test('defaults to .pdf when the URL has no extension', () async {
      final path = await withHttp(
        () => service().downloadFile('https://provider.example/download'),
      );

      expect(p.basename(path), matches(RegExp(r'^provider_doc_\d+\.pdf$')));
    });

    test('reuses an existing provider_downloads directory', () async {
      Directory(downloads()).createSync();
      File(p.join(downloads(), 'old.pdf')).writeAsStringSync('old');

      await withHttp(
        () => service().downloadFile(
          'https://provider.example/doc.pdf',
          customFileName: 'new.pdf',
        ),
      );

      expect(
        Directory(downloads()).listSync().map((e) => p.basename(e.path)),
        unorderedEquals(['old.pdf', 'new.pdf']),
      );
    });

    test('throws on an HTTP error and writes nothing', () async {
      await expectLater(
        withHttp(
          () => service().downloadFile(
            'https://provider.example/doc.pdf',
            customFileName: 'x.pdf',
          ),
          status: 404,
        ),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('404')),
        ),
      );
      expect(Directory(downloads()).existsSync(), isFalse);
    });
  });

  group('handleDeepLink', () {
    test('an add link downloads the file and opens the import page', () async {
      await withHttp(
        () => service().handleDeepLink(addLink(name: 'Discharge.pdf')),
      );

      expect(externalFiles.consumeFilePaths(), [
        p.join(downloads(), 'Discharge.pdf'),
      ]);
      expect(router.replacedWith.single.single.routeName, DashboardRoute.name);
      expect(navigation.calls, ['navigate:3']);
    });

    test('an add link with a traversal name saves a basename', () async {
      await withHttp(
        () => service().handleDeepLink(addLink(name: '../../db.sqlite')),
      );

      expect(externalFiles.consumeFilePaths(), [
        p.join(downloads(), 'db.sqlite'),
      ]);
    });

    test('an add link without a name gets a generated one', () async {
      await withHttp(() => service().handleDeepLink(addLink()));

      final paths = externalFiles.consumeFilePaths();
      expect(p.basename(paths.single), matches(r'^provider_doc_\d+\.pdf$'));
    });

    test('already on the import page, it jumps away first so the page '
        'reloads', () async {
      navigation.currentPage = 3;

      await withHttp(() => service().handleDeepLink(addLink(name: 'a.pdf')));

      expect(navigation.calls, ['jump:0', 'navigate:3']);
    });

    test('an add link without a file is ignored', () async {
      await withHttp(() => service().handleDeepLink(addLink(file: null)));
      await withHttp(() => service().handleDeepLink(addLink(file: '')));

      expect(requests, isEmpty);
      expect(externalFiles.hasPendingFiles, isFalse);
      expect(router.replacedWith, isEmpty);
    });

    test('a failed download changes nothing', () async {
      await withHttp(
        () => service().handleDeepLink(addLink(name: 'a.pdf')),
        status: 500,
      );

      expect(externalFiles.hasPendingFiles, isFalse);
      expect(router.replacedWith, isEmpty);
      expect(navigation.calls, isEmpty);
    });

    test('an http add link and unknown hosts are ignored', () async {
      for (final uri in [
        Uri.parse('http://add.healthwallet.me/?file=https://x/doc.pdf'),
        Uri.parse('https://evil.example/?file=https://x/doc.pdf'),
        Uri.parse('healthwallet://add?file=https://x/doc.pdf'),
        Uri.parse('mailto:someone@example.com'),
      ]) {
        await withHttp(() => service().handleDeepLink(uri));
      }

      expect(requests, isEmpty);
      expect(router.pushed, isEmpty);
      expect(router.replacedWith, isEmpty);
    });

    test('a healthwallet://emergency link opens the emergency card', () async {
      await service().handleDeepLink(
        Uri.parse('healthwallet://emergency?name=Jane%20Doe&blood=A%2B'),
      );

      final route = router.pushed.single as EmergencyCardRoute;
      expect(route.args!.cardData.patientName, 'Jane Doe');
      expect(route.args!.cardData.bloodType, 'A+');
    });

    test(
      'an emergency.healthwallet.me link opens the emergency card',
      () async {
        final data = base64Url
            .encode(utf8.encode(jsonEncode({'n': 'Ion Pop', 'b': '0-'})))
            .replaceAll('=', '');
        await service().handleDeepLink(
          Uri.parse('https://emergency.healthwallet.me/?data=$data'),
        );

        final route = router.pushed.single as EmergencyCardRoute;
        expect(route.args!.cardData.patientName, 'Ion Pop');
        expect(route.args!.cardData.bloodType, '0-');
      },
    );

    test('an unreadable emergency link is ignored', () async {
      await service().handleDeepLink(
        Uri.parse('https://emergency.healthwallet.me/?data=%%%not-base64'),
      );

      expect(router.pushed, isEmpty);
    });
  });

  group('initialize', () {
    test(
      'handles the link the app was opened with, then later links',
      () async {
        final links = _FakeAppLinks(
          initial: Uri.parse('healthwallet://emergency?name=First'),
        );
        final deepLinks = service(appLinks: links);

        await deepLinks.initialize();
        await flushEvents();
        links.links.add(Uri.parse('healthwallet://emergency?name=Second'));
        await flushEvents();

        expect(
          router.pushed.map(
            (r) => (r as EmergencyCardRoute).args!.cardData.patientName,
          ),
          ['First', 'Second'],
        );
        deepLinks.dispose();
      },
    );

    test('initialises once', () async {
      final links = _FakeAppLinks(
        initial: Uri.parse('healthwallet://emergency?name=Once'),
      );
      final deepLinks = service(appLinks: links);

      await deepLinks.initialize();
      await deepLinks.initialize();
      await flushEvents();

      expect(router.pushed, hasLength(1));
      deepLinks.dispose();
    });

    test('handles the link the app was opened with only once', () async {
      final links = _FakeAppLinks(
        initial: Uri.parse('healthwallet://emergency?name=Once'),
      );
      final deepLinks = service(appLinks: links);

      await deepLinks.initialize();
      await flushEvents();

      // One emergency card, so back leaves it instead of showing a copy.
      expect(router.pushed, hasLength(1));
      expect(links.initialLinkReads, 0);
      deepLinks.dispose();
    });

    test('a failing link stream is logged, not thrown', () async {
      final links = _FakeAppLinks(initialError: StateError('no channel'));
      final deepLinks = service(appLinks: links);

      await deepLinks.initialize();
      await flushEvents();

      expect(router.pushed, isEmpty);
      deepLinks.dispose();
    });

    test('dispose stops listening', () async {
      final links = _FakeAppLinks();
      final deepLinks = service(appLinks: links);

      await deepLinks.initialize();
      deepLinks.dispose();
      links.links.add(Uri.parse('healthwallet://emergency?name=Late'));
      await flushEvents();

      expect(router.pushed, isEmpty);
    });

    test('without an injected AppLinks it uses the plugin', () {
      expect(
        () => DeepLinkService(router, externalFiles, navigation),
        returnsNormally,
      );
    });
  });
}
