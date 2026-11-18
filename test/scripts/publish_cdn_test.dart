// Runs scripts/publish_cdn.sh, which the CI job cdn:publish uses, against a local HttpServer
// that fakes GitLab's generic package registry and a fake `rclone` first on PATH that copies into
// a temporary "bucket" and records the headers of each upload. The scripts are copied next to a
// pubspec.yaml of the test's own, so the version doesn't follow the app's.
@TestOn('linux || mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 'job-token-123';
const _sha = '0123456789abcdef0123456789abcdef01234567';
const _publicUrl = 'https://downloads.example.test';

const _dmg = 'HealthWallet-macOS-v1.3.0.dmg';
const _zip = 'HealthWallet-Windows-v1.3.0-portable.zip';
const _deb = 'HealthWallet-Linux-v1.3.0-amd64.deb';
const _tar = 'HealthWallet-Linux-v1.3.0-amd64.tar.gz';

/// Copies `copyto <file> cdn:<path>` into `$FAKE_BUCKET/<path>`, writes the `--header-upload`
/// values to `$FAKE_HEADERS/<path>` and the other flags to `$FAKE_HEADERS/<path>.flags`, appends
/// `<path>` to `$FAKE_LOG` and the rclone config it was given to `$FAKE_CONFIG`.
/// `cat cdn:<path>` prints a file of the bucket, or nothing for a missing object, as rclone
/// 1.75.2 does against RustFS. Any command on `$FAKE_FAIL` fails as access denied.
const _fakeRclone = r'''#!/usr/bin/env bash
set -euo pipefail
command=$1
shift
headers=()
flags=()
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
  --header-upload)
    headers+=("$2")
    shift 2
    ;;
  --*)
    flags+=("$1")
    shift
    ;;
  *)
    paths+=("$1")
    shift
    ;;
  esac
done
remote() {
  case "$1" in
  cdn:*) echo "${1#cdn:}" ;;
  *)
    echo "not a cdn: remote: $1" >&2
    exit 2
    ;;
  esac
}
target=${paths[1]:-${paths[0]}}
if [ "$(remote "$target")" = "${FAKE_FAIL:-}" ]; then
  echo "AccessDenied: Access Denied" >&2
  exit 1
fi
case "$command" in
copyto)
  path=$(remote "${paths[1]}")
  mkdir -p "$(dirname "$FAKE_BUCKET/$path")" "$(dirname "$FAKE_HEADERS/$path")"
  cp "${paths[0]}" "$FAKE_BUCKET/$path"
  printf '%s\n' ${headers[@]+"${headers[@]}"} >"$FAKE_HEADERS/$path"
  printf '%s\n' ${flags[@]+"${flags[@]}"} >"$FAKE_HEADERS/$path.flags"
  echo "$path" >>"$FAKE_LOG"
  env | grep '^RCLONE_CONFIG_CDN_' | sort >"$FAKE_CONFIG"
  ;;
cat)
  path=$(remote "${paths[0]}")
  if [ -f "$FAKE_BUCKET/$path" ]; then
    cat "$FAKE_BUCKET/$path"
  fi
  ;;
*)
  echo "fake rclone does not support $command" >&2
  exit 2
  ;;
esac
''';

void main() {
  late Directory root;
  late Directory bucket;
  late Directory headers;
  late File uploadLog;
  late File rcloneConfig;
  late _FakeRegistry registry;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('publish_cdn_test');
    await Directory('${root.path}/scripts').create();
    for (final script in ['release_tag.sh', 'publish_cdn.sh']) {
      // cp -p keeps the executable bit: publish_cdn.sh runs release_tag.sh directly.
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

    final bin = await Directory('${root.path}/bin').create();
    final rclone = File('${bin.path}/rclone');
    await rclone.writeAsString(_fakeRclone);
    final chmod = await Process.run('chmod', ['+x', rclone.path]);
    expect(chmod.exitCode, 0, reason: '${chmod.stderr}');

    bucket = await Directory('${root.path}/bucket').create();
    headers = await Directory('${root.path}/headers').create();
    uploadLog = File('${root.path}/uploads.log');
    rcloneConfig = File('${root.path}/rclone.env');
    registry = await _FakeRegistry.start();
  });

  tearDown(() async {
    await registry.close();
    await root.delete(recursive: true);
  });

  /// Environment with only what the script needs, so the variables of a pipeline running these
  /// tests can't leak in.
  Map<String, String> environment({
    String branch = 'master',
    String channel = 'stable',
    String? region,
    String? fail,
  }) => {
    'PATH':
        '${root.path}/bin:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
    'HOME': root.path,
    'FAKE_BUCKET': bucket.path,
    'FAKE_HEADERS': headers.path,
    'FAKE_LOG': uploadLog.path,
    'FAKE_CONFIG': rcloneConfig.path,
    'CI_COMMIT_BRANCH': branch,
    'CI_PIPELINE_IID': '17',
    'CI_API_V4_URL': registry.apiUrl,
    'CI_PROJECT_ID': '42',
    'CI_JOB_TOKEN': _token,
    'CI_COMMIT_SHA': _sha,
    'CDN_CHANNEL': channel,
    'CDN_S3_ENDPOINT': 'https://s3.example.test',
    'CDN_S3_REGION': ?region,
    'CDN_BUCKET': 'downloads',
    'CDN_ACCESS_KEY_ID': 'access-key',
    'CDN_SECRET_ACCESS_KEY': 'secret-key',
    'CDN_PUBLIC_URL': '$_publicUrl/',
    'FAKE_FAIL': ?fail,
  };

  Future<ProcessResult> publish(Map<String, String> environment) => Process.run(
    'bash',
    ['${root.path}/scripts/publish_cdn.sh'],
    environment: environment,
    includeParentEnvironment: false,
  );

  /// Every object in the bucket, by its path.
  Map<String, List<int>> objects() => {
    for (final file
        in bucket.listSync(recursive: true).whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      file.path.substring(bucket.path.length + 1): file.readAsBytesSync(),
  };

  List<String> headersOf(String path) =>
      File('${headers.path}/$path').readAsLinesSync();

  List<String> flagsOf(String path) =>
      File('${headers.path}/$path.flags').readAsLinesSync();

  Map<String, dynamic> versionsJson(String channel) => jsonDecode(
    File('${bucket.path}/downloads/$channel/versions.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<String> uploads() =>
      uploadLog.existsSync() ? uploadLog.readAsLinesSync() : [];

  /// Puts a package file for [tag] in the fake registry and returns its content.
  List<int> addPackage(String package, String tag, String name) {
    final content = utf8.encode('$name for $tag');
    registry.files['$package/$tag/$name'] = content;
    return content;
  }

  void addDesktopPackages(String tag) {
    addPackage('healthwallet-windows', tag, _zip);
    addPackage('healthwallet-linux', tag, _deb);
    addPackage('healthwallet-linux', tag, _tar);
  }

  Map<String, dynamic> expectedEntry(
    String channel,
    String tag,
    String name,
    List<int> content, {
    String? arch,
  }) => {
    'name': name,
    'url': '$_publicUrl/$channel/$tag/$name',
    'size': content.length,
    'sha256': sha256.convert(content).toString(),
    'arch': ?arch,
  };

  test('publishes every desktop package of a master pipeline to stable, '
      'versions.json last', () async {
    final dmg = addPackage('healthwallet-macos', 'v1.3.0', _dmg);
    final zip = addPackage('healthwallet-windows', 'v1.3.0', _zip);
    final deb = addPackage('healthwallet-linux', 'v1.3.0', _deb);
    final tar = addPackage('healthwallet-linux', 'v1.3.0', _tar);

    final result = await publish(environment());

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(objects().keys, [
      'downloads/stable/v1.3.0/$_deb',
      'downloads/stable/v1.3.0/$_tar',
      'downloads/stable/v1.3.0/$_zip',
      'downloads/stable/v1.3.0/$_dmg',
      'downloads/stable/v1.3.0/SHA256SUMS',
      'downloads/stable/versions.json',
    ]);
    for (final (name, content) in [
      (_dmg, dmg),
      (_zip, zip),
      (_deb, deb),
      (_tar, tar),
    ]) {
      expect(objects()['downloads/stable/v1.3.0/$name'], content);
      expect(headersOf('downloads/stable/v1.3.0/$name'), [
        'Cache-Control: public, max-age=31536000, immutable',
        'Content-Disposition: attachment; filename="$name"',
      ]);
    }
    expect(
      File(
        '${bucket.path}/downloads/stable/v1.3.0/SHA256SUMS',
      ).readAsStringSync(),
      [
        for (final (name, content) in [
          (_dmg, dmg),
          (_zip, zip),
          (_deb, deb),
          (_tar, tar),
        ])
          '${sha256.convert(content)}  $name\n',
      ].join(),
    );
    expect(
      headersOf('downloads/stable/v1.3.0/SHA256SUMS'),
      contains('Cache-Control: no-cache'),
    );
    expect(
      headersOf('downloads/stable/versions.json'),
      contains('Cache-Control: no-cache'),
    );
    expect(uploads().length, 6);
    for (final path in uploads()) {
      expect(flagsOf(path), contains('--ignore-times'), reason: path);
    }
    expect(uploads().sublist(4), [
      'downloads/stable/v1.3.0/SHA256SUMS',
      'downloads/stable/versions.json',
    ]);

    final versions = versionsJson('stable');
    expect(
      versions['published'],
      matches(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$'),
    );
    expect(versions..remove('published'), {
      'channel': 'stable',
      'version': '1.3.0',
      'tag': 'v1.3.0',
      'commit': _sha,
      'macos': expectedEntry('stable', 'v1.3.0', _dmg, dmg),
      'windows': expectedEntry('stable', 'v1.3.0', _zip, zip),
      'linux': {
        'deb': expectedEntry('stable', 'v1.3.0', _deb, deb, arch: 'amd64'),
        'tar': expectedEntry('stable', 'v1.3.0', _tar, tar, arch: 'amd64'),
      },
    });

    expect(registry.tokens, everyElement(_token));
    expect(rcloneConfig.readAsLinesSync(), [
      'RCLONE_CONFIG_CDN_ACCESS_KEY_ID=access-key',
      'RCLONE_CONFIG_CDN_ENDPOINT=https://s3.example.test',
      'RCLONE_CONFIG_CDN_ENV_AUTH=false',
      'RCLONE_CONFIG_CDN_FORCE_PATH_STYLE=true',
      'RCLONE_CONFIG_CDN_NO_CHECK_BUCKET=true',
      'RCLONE_CONFIG_CDN_PROVIDER=Other',
      'RCLONE_CONFIG_CDN_SECRET_ACCESS_KEY=secret-key',
      'RCLONE_CONFIG_CDN_TYPE=s3',
    ]);
  });

  test('publishes without macOS when macos:direct has not uploaded the DMG, '
      'to beta from develop', () async {
    addDesktopPackages('v1.3.0-dev.17');

    final result = await publish(
      environment(branch: 'develop', channel: 'beta', region: 'eu-central-1'),
    );

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('publishing without macOS'));
    expect(objects().keys, [
      'downloads/beta/v1.3.0-dev.17/$_deb',
      'downloads/beta/v1.3.0-dev.17/$_tar',
      'downloads/beta/v1.3.0-dev.17/$_zip',
      'downloads/beta/v1.3.0-dev.17/SHA256SUMS',
      'downloads/beta/versions.json',
    ]);
    final versions = versionsJson('beta');
    expect(versions, isNot(contains('macos')));
    expect(versions['channel'], 'beta');
    expect(versions['tag'], 'v1.3.0-dev.17');
    expect(
      (versions['windows'] as Map<String, dynamic>)['url'],
      '$_publicUrl/beta/v1.3.0-dev.17/$_zip',
    );
    expect(
      rcloneConfig.readAsLinesSync(),
      contains('RCLONE_CONFIG_CDN_REGION=eu-central-1'),
    );
  });

  test(
    'uploads nothing and names the file when the Windows zip is missing',
    () async {
      addPackage('healthwallet-macos', 'v1.3.0', _dmg);
      addPackage('healthwallet-linux', 'v1.3.0', _deb);
      addPackage('healthwallet-linux', 'v1.3.0', _tar);

      final result = await publish(environment());

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('healthwallet-windows/v1.3.0/$_zip'));
      expect(objects(), isEmpty);
    },
  );

  test(
    'uploads nothing and names the file when a Linux package is missing',
    () async {
      addPackage('healthwallet-windows', 'v1.3.0', _zip);
      addPackage('healthwallet-linux', 'v1.3.0', _deb);

      final result = await publish(environment());

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('healthwallet-linux/v1.3.0/$_tar'));
      expect(objects(), isEmpty);
    },
  );

  test('takes the arm64 Linux packages when the runner built arm64', () async {
    addPackage('healthwallet-windows', 'v1.3.0', _zip);
    const deb = 'HealthWallet-Linux-v1.3.0-arm64.deb';
    const tar = 'HealthWallet-Linux-v1.3.0-arm64.tar.gz';
    addPackage('healthwallet-linux', 'v1.3.0', deb);
    addPackage('healthwallet-linux', 'v1.3.0', tar);

    final result = await publish(environment());

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final linux = versionsJson('stable')['linux'] as Map<String, dynamic>;
    expect((linux['deb'] as Map<String, dynamic>)['name'], deb);
    expect((linux['tar'] as Map<String, dynamic>)['arch'], 'arm64');
  });

  test('fails with the registry answer when a download fails', () async {
    addDesktopPackages('v1.3.0');
    registry.failures['healthwallet-windows/v1.3.0/$_zip'] = 403;

    final result = await publish(environment());

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('HTTP 403'));
    expect(result.stderr, contains('403 Forbidden'));
    expect(objects(), isEmpty);
  });

  test('lists every missing variable and contacts nothing', () async {
    addDesktopPackages('v1.3.0');
    final env = environment()
      ..remove('CDN_S3_ENDPOINT')
      ..remove('CDN_BUCKET')
      ..remove('CDN_ACCESS_KEY_ID')
      ..remove('CDN_SECRET_ACCESS_KEY')
      ..remove('CDN_PUBLIC_URL')
      ..remove('CDN_CHANNEL');

    final result = await publish(env);

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr,
      contains(
        'Missing CI/CD variables: CDN_CHANNEL CDN_S3_ENDPOINT CDN_BUCKET '
        'CDN_ACCESS_KEY_ID CDN_SECRET_ACCESS_KEY CDN_PUBLIC_URL',
      ),
    );
    expect(registry.tokens, isEmpty);
    expect(objects(), isEmpty);
  });

  test('refuses a channel that does not match the branch', () async {
    addDesktopPackages('v1.3.0-dev.17');

    final result = await publish(environment(branch: 'develop'));

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('v1.3.0-dev.17 is a pre-release'));
    expect(objects(), isEmpty);
  });

  test(
    'a re-run uploads the same objects again and rewrites versions.json',
    () async {
      addDesktopPackages('v1.3.0');
      final first = await publish(environment());
      expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
      final published = objects();

      final second = await publish(environment());

      expect(second.exitCode, 0, reason: '${second.stdout}${second.stderr}');
      final republished = objects();
      expect(republished.keys, published.keys);
      for (final path in published.keys.where((p) => !p.endsWith('.json'))) {
        expect(republished[path], published[path], reason: path);
      }
      expect(uploads().length, 10);
      expect(uploads().last, 'downloads/stable/versions.json');
      expect(
        uploads().where((p) => p == 'downloads/stable/versions.json'),
        hasLength(2),
      );
    },
  );

  test(
    'a re-run after macos:direct adds the DMG to the published tag',
    () async {
      addDesktopPackages('v1.3.0');
      final first = await publish(environment());
      expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
      expect(versionsJson('stable'), isNot(contains('macos')));

      addPackage('healthwallet-macos', 'v1.3.0', _dmg);
      final second = await publish(environment());

      expect(second.exitCode, 0, reason: '${second.stdout}${second.stderr}');
      expect(objects(), contains('downloads/stable/v1.3.0/$_dmg'));
      expect(
        (versionsJson('stable')['macos'] as Map<String, dynamic>)['name'],
        _dmg,
      );
    },
  );

  test('never replaces a published file with different content', () async {
    addDesktopPackages('v1.3.0');
    final first = await publish(environment());
    expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
    final published = objects();

    registry.files['healthwallet-windows/v1.3.0/$_zip'] = utf8.encode(
      'another build',
    );
    final second = await publish(environment());

    expect(second.exitCode, isNot(0));
    expect(second.stderr, contains('already published with different content'));
    expect(objects(), published);
  });

  test('refuses an unknown channel', () async {
    addDesktopPackages('v1.3.0');

    final result = await publish(environment(channel: 'nightly'));

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('CDN_CHANNEL must be stable or beta'));
    expect(objects(), isEmpty);
  });

  test('refuses a master tag on the beta channel', () async {
    addDesktopPackages('v1.3.0');

    final result = await publish(environment(channel: 'beta'));

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('Tag v1.3.0 is a release'));
    expect(objects(), isEmpty);
  });

  test('stops with rclone\'s error when the bucket cannot be read', () async {
    addDesktopPackages('v1.3.0');

    final result = await publish(
      environment(fail: 'downloads/stable/v1.3.0/SHA256SUMS'),
    );

    expect(result.exitCode, 1);
    expect(result.stderr, contains('AccessDenied'));
    expect(result.stderr, contains('Reading stable/v1.3.0/SHA256SUMS'));
    expect(uploads(), isEmpty);
  });

  test(
    'stops before SHA256SUMS and versions.json when an upload fails',
    () async {
      addDesktopPackages('v1.3.0');

      final result = await publish(
        environment(fail: 'downloads/stable/v1.3.0/$_zip'),
      );

      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('AccessDenied'));
      expect(objects(), isNot(contains('downloads/stable/v1.3.0/SHA256SUMS')));
      expect(objects(), isNot(contains('downloads/stable/versions.json')));
    },
  );

  test('uploads nothing when a download breaks off after its 200', () async {
    addDesktopPackages('v1.3.0');
    registry.truncated.add('healthwallet-windows/v1.3.0/$_zip');

    final result = await publish(environment());

    expect(result.exitCode, isNot(0));
    expect(
      result.stderr,
      contains('$_zip from the package registry failed (curl exit'),
    );
    expect(uploads(), isEmpty);
  });

  test('fails naming a published file this run no longer has', () async {
    addDesktopPackages('v1.3.0');
    addPackage('healthwallet-macos', 'v1.3.0', _dmg);
    final first = await publish(environment());
    expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
    final published = objects();

    registry.files.remove('healthwallet-macos/v1.3.0/$_dmg');
    final second = await publish(environment());

    expect(second.exitCode, isNot(0));
    expect(
      second.stderr,
      contains('stable/v1.3.0/$_dmg is already published but not part'),
    );
    expect(objects(), published);
  });
}

/// GitLab's generic package registry: serves [files] by `<package>/<tag>/<file>` under
/// `/api/v4/projects/42/packages/generic/`, 404 for anything else, and records the JOB-TOKEN
/// of every request.
class _FakeRegistry {
  _FakeRegistry._(this._server);

  final HttpServer _server;
  final Map<String, List<int>> files = {};
  final Map<String, int> failures = {};
  final Set<String> truncated = {};
  final List<String?> tokens = [];

  String get apiUrl => 'http://127.0.0.1:${_server.port}/api/v4';

  static Future<_FakeRegistry> start() async {
    final registry = _FakeRegistry._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    registry._server.listen(registry._handle);
    return registry;
  }

  Future<void> _handle(HttpRequest request) async {
    tokens.add(request.headers.value('JOB-TOKEN'));
    const prefix = '/api/v4/projects/42/packages/generic/';
    final path = request.uri.path;
    final key = path.startsWith(prefix) ? path.substring(prefix.length) : '';
    final failure = failures[key];
    final content = files[key];
    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
    } else if (failure != null) {
      request.response
        ..statusCode = failure
        ..write('{"message":"$failure Forbidden"}');
    } else if (content == null) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('{"message":"404 Not Found"}');
    } else if (truncated.contains(key)) {
      // Promises more bytes than it sends, then drops the connection.
      request.response.contentLength = content.length + 100;
      final socket = await request.response.detachSocket();
      socket.add(content);
      await socket.flush();
      socket.destroy();
      return;
    } else {
      request.response.add(content);
    }
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}
