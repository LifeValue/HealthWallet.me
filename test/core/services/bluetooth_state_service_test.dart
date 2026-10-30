import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/bluetooth_state_service.dart';

import '../../helpers/log_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.techstackapps.healthwallet/bluetooth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final logs = captureLogs();
  late BluetoothStateService service;
  late List<String> calls;

  setUp(() {
    service = BluetoothStateService();
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    service.dispose();
  });

  test('requestEnable asks the native side to turn Bluetooth on', () async {
    await service.requestEnable();

    expect(calls, ['requestEnable']);
    expect(logs, isEmpty);
  });

  test('requestEnable completes and logs when the native side fails', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'denied');
    });

    await service.requestEnable();

    expect(logs, loggedWarning('Could not ask the system to turn Bluetooth'));
  });

  test(
    'isEnabled reports true without asking on a desktop host',
    () async {
      expect(await service.isEnabled(), isTrue);
      expect(calls, isEmpty);
    },
    skip: Platform.isAndroid || Platform.isIOS,
  );

  test('startListening does nothing on a desktop host', () {
    service.startListening();
    service.stopListening();

    expect(calls, isEmpty);
  });
}
