// Runs scripts/release_tag.sh and scripts/gitlab_release.sh, which the desktop release jobs in
// .gitlab-ci.yml use, against a local HttpServer that fakes GitLab's API. The scripts are copied
// next to a pubspec.yaml of the test's own, so the tag doesn't follow the app's version.
@TestOn('linux || mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _token = 'job-token-123';
const _sha = '0123456789abcdef0123456789abcdef01234567';

void main() {
  late Directory root;
  late _FakeGitLab gitLab;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('release_scripts_test');
    await Directory('${root.path}/scripts').create();
    for (final script in ['release_tag.sh', 'gitlab_release.sh']) {
      // cp -p keeps the executable bit: gitlab_release.sh runs release_tag.sh directly.
      final copy = await Process.run('cp', [
        '-p',
        'scripts/$script',
        '${root.path}/scripts/$script',
      ]);
      expect(copy.exitCode, 0, reason: '${copy.stderr}');
    }
    await File(
      '${root.path}/pubspec.yaml',
    ).writeAsString('name: health_wallet\nversion: 1.3.0+42\n');
    gitLab = await _FakeGitLab.start();
  });

  tearDown(() async {
    await gitLab.close();
    await root.delete(recursive: true);
  });

  /// Environment with only what the scripts need, so the CI variables of a pipeline running
  /// these tests can't leak in.
  Map<String, String> ciEnvironment({
    String branch = 'master',
    String? pipelineIid = '17',
  }) => {
    'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin',
    'CI_COMMIT_BRANCH': branch,
    'CI_PIPELINE_IID': ?pipelineIid,
    'CI_API_V4_URL': gitLab.apiUrl,
    'CI_PROJECT_ID': '42',
    'CI_JOB_TOKEN': _token,
    'CI_COMMIT_SHA': _sha,
  };

  Future<ProcessResult> run(
    String script,
    List<String> arguments,
    Map<String, String> environment,
  ) => Process.run(
    '${root.path}/scripts/$script',
    arguments,
    environment: environment,
    includeParentEnvironment: false,
    workingDirectory: root.path,
  );

  group('release_tag.sh', () {
    test('tags master with the version without its build number', () async {
      final result = await run('release_tag.sh', [], ciEnvironment());

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, 'v1.3.0\n');
    });

    for (final branch in ['develop', 'release/1.3.0']) {
      test('tags $branch as a dev pre-release of the pipeline', () async {
        final result = await run(
          'release_tag.sh',
          [],
          ciEnvironment(branch: branch),
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stdout, 'v1.3.0-dev.17\n');
      });
    }

    test('fails off master without a pipeline iid', () async {
      final result = await run(
        'release_tag.sh',
        [],
        ciEnvironment(branch: 'develop', pipelineIid: null),
      );

      expect(result.exitCode, isNot(0));
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains('CI_PIPELINE_IID'));
    });

    test('fails when pubspec.yaml has no version', () async {
      await File(
        '${root.path}/pubspec.yaml',
      ).writeAsString('name: health_wallet\n');

      final result = await run('release_tag.sh', [], ciEnvironment());

      expect(result.exitCode, isNot(0));
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains('No version found'));
    });
  });

  group('gitlab_release.sh', () {
    late Directory packages;

    setUp(() async {
      packages = await Directory('${root.path}/packages').create();
      await File(
        '${packages.path}/HealthWallet-Linux-v1.3.0-amd64.deb',
      ).writeAsString('deb bytes');
      await File(
        '${packages.path}/HealthWallet-Linux-v1.3.0-amd64.tar.gz',
      ).writeAsString('tar bytes');
      // Folders are not packages.
      await Directory('${packages.path}/tarball').create();
    });

    Future<ProcessResult> release({String branch = 'master'}) => run(
      'gitlab_release.sh',
      ['healthwallet-linux', packages.path],
      ciEnvironment(branch: branch),
    );

    String packageUrl(String tag, String name) =>
        '${gitLab.apiUrl}/projects/42/packages/generic/healthwallet-linux/'
        '$tag/$name';

    test(
      'uploads the packages, creates the release and links the packages',
      () async {
        final result = await release();

        expect(result.exitCode, 0, reason: '${result.stderr}');
        final requests = gitLab.requests;
        expect(requests.map((r) => '${r.method} ${r.path}'), [
          'PUT /api/v4/projects/42/packages/generic/healthwallet-linux/v1.3.0/'
              'HealthWallet-Linux-v1.3.0-amd64.deb',
          'PUT /api/v4/projects/42/packages/generic/healthwallet-linux/v1.3.0/'
              'HealthWallet-Linux-v1.3.0-amd64.tar.gz',
          'POST /api/v4/projects/42/releases',
          'POST /api/v4/projects/42/releases/v1.3.0/assets/links',
          'POST /api/v4/projects/42/releases/v1.3.0/assets/links',
        ]);
        expect(requests.map((r) => r.token), everyElement(_token));
        expect(requests[0].body, 'deb bytes');
        expect(requests[1].body, 'tar bytes');

        final create = requests[2];
        expect(create.contentType, 'application/x-www-form-urlencoded');
        final form = create.form;
        expect(form['tag_name'], 'v1.3.0');
        expect(form['ref'], _sha);
        expect(form['name'], 'v1.3.0');
        final description = form['description']!;
        expect(description, startsWith('## HealthWallet v1.3.0\n'));
        expect(description, contains('Branch: `master`, commit: `$_sha`'));
        expect(description, contains('**macOS (.dmg):**'));
        expect(description, contains('**Windows portable (.zip):**'));
        expect(description, contains('**Linux (.deb):**'));
        expect(description, contains('**Linux portable (.tar.gz):**'));

        expect(requests.sublist(3).map((r) => r.form), [
          {
            'name': 'HealthWallet-Linux-v1.3.0-amd64.deb',
            'url': packageUrl('v1.3.0', 'HealthWallet-Linux-v1.3.0-amd64.deb'),
            'link_type': 'package',
          },
          {
            'name': 'HealthWallet-Linux-v1.3.0-amd64.tar.gz',
            'url': packageUrl(
              'v1.3.0',
              'HealthWallet-Linux-v1.3.0-amd64.tar.gz',
            ),
            'link_type': 'package',
          },
        ]);
      },
    );

    test('releases a develop pipeline under its dev tag', () async {
      final result = await release(branch: 'develop');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final requests = gitLab.requests;
      expect(
        requests.first.path,
        '/api/v4/projects/42/packages/generic/healthwallet-linux/'
        'v1.3.0-dev.17/HealthWallet-Linux-v1.3.0-amd64.deb',
      );
      expect(requests[2].form['tag_name'], 'v1.3.0-dev.17');
      expect(requests[2].form['description'], contains('Branch: `develop`'));
      expect(
        requests.last.path,
        '/api/v4/projects/42/releases/v1.3.0-dev.17/assets/links',
      );
    });

    test(
      'accepts a release another platform already created (409) and links its packages',
      () async {
        gitLab.releaseStatus = HttpStatus.conflict;
        gitLab.releaseBody = '{"message":"Release already exists"}';

        final result = await release();

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(result.stdout, contains('Release v1.3.0 exists already'));
        expect(
          gitLab.requests.where((r) => r.path.endsWith('/assets/links')),
          hasLength(2),
        );
      },
    );

    test(
      'fails with GitLab\'s reason when creating the release fails',
      () async {
        gitLab.releaseStatus = HttpStatus.forbidden;
        gitLab.releaseBody = '{"message":"403 Forbidden"}';

        final result = await release();

        expect(result.exitCode, isNot(0));
        expect(
          result.stderr,
          contains('Creating release v1.3.0 failed (HTTP 403)'),
        );
        expect(result.stderr, contains('{"message":"403 Forbidden"}'));
        expect(
          gitLab.requests.where((r) => r.path.endsWith('/assets/links')),
          isEmpty,
        );
      },
    );

    test(
      'fails with GitLab\'s reason before creating the release when an upload fails',
      () async {
        gitLab.uploadStatus = HttpStatus.requestEntityTooLarge;
        gitLab.uploadBody = '{"message":"File is too large"}';

        final result = await release();

        expect(result.exitCode, isNot(0));
        expect(
          result.stderr,
          contains(
            'Uploading HealthWallet-Linux-v1.3.0-amd64.deb failed (HTTP 413)',
          ),
        );
        expect(result.stderr, contains('File is too large'));
        expect(gitLab.requests.map((r) => r.method), ['PUT']);
      },
    );

    test('fails with GitLab\'s reason when linking a package fails', () async {
      gitLab.linkStatus = HttpStatus.badRequest;
      gitLab.linkBody = '{"message":{"name":["has already been taken"]}}';

      final result = await release();

      expect(result.exitCode, isNot(0));
      expect(
        result.stderr,
        contains(
          'Linking HealthWallet-Linux-v1.3.0-amd64.deb failed (HTTP 400)',
        ),
      );
      expect(result.stderr, contains('has already been taken'));
    });

    test('fails listing the missing CI variables without a request', () async {
      final environment = ciEnvironment()
        ..remove('CI_JOB_TOKEN')
        ..remove('CI_COMMIT_SHA');

      final result = await run('gitlab_release.sh', [
        'healthwallet-linux',
        packages.path,
      ], environment);

      expect(result.exitCode, isNot(0));
      expect(
        result.stderr,
        contains('Missing CI variables: CI_JOB_TOKEN CI_COMMIT_SHA'),
      );
      expect(gitLab.requests, isEmpty);
    });

    test('fails without a request when the folder has no files', () async {
      final empty = await Directory('${root.path}/empty').create();

      final result = await run('gitlab_release.sh', [
        'healthwallet-linux',
        empty.path,
      ], ciEnvironment());

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('No files to release in ${empty.path}'));
      expect(gitLab.requests, isEmpty);
    });

    test('prints its usage without both arguments', () async {
      final result = await run('gitlab_release.sh', [
        'healthwallet-linux',
      ], ciEnvironment());

      expect(result.exitCode, 2);
      expect(result.stderr, contains('Usage:'));
      expect(gitLab.requests, isEmpty);
    });
  });

  // publish_cdn.sh finds the packages by name and publishes without macOS when the DMG is
  // missing, so a package renamed on one side only would silently drop it from the downloads.
  group('package names', () {
    /// The package names a file spells out, with its version and architecture variables
    /// replaced by {version} and {arch}.
    Set<String> packageNames(String path) =>
        RegExp(
          r'HealthWallet-(?:macOS|Windows|Linux)-v[^"\s\\/]*',
        ).allMatches(File(path).readAsStringSync()).map((match) {
          return match[0]!
              .replaceAll(
                RegExp(r'#\{version_name\}|\$\{?[Vv]ersion\}?'),
                '{version}',
              )
              .replaceAll(RegExp(r'\$\{?(?:linux_)?arch\}?'), '{arch}');
        }).toSet();

    test(
      'publish_cdn.sh looks for the names the builds give their packages',
      () {
        // Names with a literal architecture are only in its error messages.
        final published = packageNames(
          'scripts/publish_cdn.sh',
        ).where((name) => !RegExp('amd64|arm64').hasMatch(name)).toSet();
        final producers = {
          'macOS': packageNames('macos/fastlane/Fastfile'),
          'Windows': packageNames('scripts/build_windows.ps1'),
          'Linux': packageNames('scripts/package_linux.sh'),
        };

        expect(
          published.map((name) => name.substring(name.lastIndexOf('.'))),
          containsAll(['.dmg', '.zip', '.deb', '.gz']),
          reason: 'publish_cdn.sh names: $published',
        );
        for (final name in published) {
          final platform = name.split('-')[1];
          expect(
            producers[platform],
            contains(name),
            reason:
                'publish_cdn.sh fetches $name, which no $platform build makes',
          );
        }
      },
    );
  });
}

class _Request {
  _Request(this.method, this.path, this.token, this.contentType, this.body);

  final String method;
  final String path;
  final String? token;
  final String? contentType;
  final String body;

  Map<String, String> get form => Uri.splitQueryString(body);
}

/// Answers the requests gitlab_release.sh makes the way GitLab does and records them.
class _FakeGitLab {
  _FakeGitLab._(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeGitLab> start() async =>
      _FakeGitLab._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final requests = <_Request>[];

  int uploadStatus = HttpStatus.created;
  String uploadBody = '{"message":"201 Created"}';
  int releaseStatus = HttpStatus.created;
  String releaseBody = '{"tag_name":"v1.3.0"}';
  int linkStatus = HttpStatus.created;
  String linkBody = '{"id":1}';

  String get apiUrl => 'http://127.0.0.1:${_server.port}/api/v4';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final path = request.uri.path;
    requests.add(
      _Request(
        request.method,
        path,
        request.headers.value('JOB-TOKEN'),
        request.headers.contentType?.mimeType,
        body,
      ),
    );
    final (status, response) = switch (path) {
      _ when path.contains('/packages/generic/') => (uploadStatus, uploadBody),
      _ when path.endsWith('/releases') => (releaseStatus, releaseBody),
      _ when path.endsWith('/assets/links') => (linkStatus, linkBody),
      _ => (HttpStatus.notFound, '{"message":"404 Not Found"}'),
    };
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(response);
    await request.response.close();
  }
}
