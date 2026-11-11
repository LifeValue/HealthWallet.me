import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/stored_file_name.dart';
import 'package:health_wallet/features/desktop/communication/data/services/message_router.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../desktop_test_fakes.dart';

/// A document the phone names like a Windows device (`CON.pdf`, `aux.jpg`)
/// is received under a name a Windows desktop opens as a file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late FakeTcpService tcp;
  late MessageRouter router;
  late HandoverService receiver;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('handover_reserved_names');
    SharedPreferences.setMockInitialValues({});
    tcp = FakeTcpService();
    router = MessageRouter(tcp);
    receiver =
        HandoverService(tcp, router, await SharedPreferences.getInstance())
          ..temporaryDirectory = (() async => tmp)
          ..start();
  });

  tearDown(() async {
    await receiver.dispose();
    router.dispose();
    await tcp.close();
    await tmp.delete(recursive: true);
  });

  test('a page named like a Windows device is stored under another name, '
      'and its title is still that name', () async {
    final received = receiver.phoneEvents.first;
    tcp.deliver(HandoverMessage.offer, {
      'session_id': 's',
      'v': HandoverProtocol.version,
      'files': [
        // As the phone sends them: its stored copy, with a unique suffix.
        {'name': 'CON_1a2b3c4d.pdf', 'size': 0},
        {'name': 'aux_1a2b3c4d.jpg', 'size': 0},
        // Or without one.
        {'name': 'NUL.pdf', 'size': 0},
        {'name': 'com1.tar.gz', 'size': 0},
        {'name': 'LPT9 .pdf', 'size': 0},
        {'name': 'Console.pdf', 'size': 0},
      ],
    });
    final paths = ((await received) as IncomingHandoverReceived).filePaths;

    expect(paths.map(p.basename), [
      'CON_.pdf',
      'aux_.jpg',
      'NUL_.pdf',
      'com1_.tar.gz',
      'LPT9_.pdf',
      'Console.pdf',
    ]);
    expect(paths.every((path) => File(path).existsSync()), isTrue);

    // What processing does with the file: a unique stored name, whose stem
    // is the document's title.
    final imports = Directory(p.join(tmp.path, 'imports'))..createSync();
    final titles = [
      for (final path in paths)
        originalFileStem(
          p.join(
            imports.path,
            await uniqueStoredFileName(imports.path, p.basename(path)),
          ),
        ),
    ];
    expect(titles, ['CON', 'aux', 'NUL', 'com1.tar', 'LPT9', 'Console']);
  });
}
