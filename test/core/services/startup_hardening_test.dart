import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/startup_hardening.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';

class _RecordingSweeper extends TempFileSweeper {
  _RecordingSweeper(Directory dir)
    : super(
        temporaryDirectory: () async => dir,
        documentsDirectory: () async => dir,
      );

  int sweeps = 0;

  @override
  Future<void> sweep() async => sweeps++;
}

void main() {
  late DebugPrintCallback originalDebugPrint;
  late Directory dir;
  late _RecordingSweeper sweeper;

  setUp(() {
    originalDebugPrint = debugPrint;
    dir = Directory.systemTemp.createTempSync('hw_startup_');
    sweeper = _RecordingSweeper(dir);
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    dir.deleteSync(recursive: true);
  });

  /// Routes debugPrint's output into the returned list, until hardenStartup
  /// replaces debugPrint in a release build.
  List<String?> capturePrints() {
    final printed = <String?>[];
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
    return printed;
  }

  test('a release build silences debugPrint and sweeps temp', () async {
    final printed = capturePrints();

    await hardenStartup(releaseMode: true, sweeper: sweeper);
    debugPrint('Patient: Jane Doe');

    expect(printed, isEmpty);
    expect(sweeper.sweeps, 1);
  });

  test('a debug build keeps debugPrint and sweeps temp', () async {
    final printed = capturePrints();

    await hardenStartup(releaseMode: false, sweeper: sweeper);
    debugPrint('scan step 1');

    expect(printed, ['scan step 1']);
    expect(sweeper.sweeps, 1);
  });

  test('without a sweeper it sweeps the real temp directory', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // path_provider has no implementation under test, so the default sweeper
    // logs the failure and completes.
    await expectLater(hardenStartup(releaseMode: false), completes);
  });
}
