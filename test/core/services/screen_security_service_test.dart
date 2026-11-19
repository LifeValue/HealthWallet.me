import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/services/screen_security_service.dart';

import '../../helpers/log_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.screen_security');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final logs = captureLogs();
  late List<String> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('enable and disable call the native channel', () async {
    await ScreenSecurityService.enable();
    await ScreenSecurityService.disable();

    expect(calls, ['enable', 'disable']);
    expect(logs, isEmpty);
  });

  group('when the native side fails', () {
    setUp(() {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'unavailable');
      });
    });

    test('enable completes and logs the failure', () async {
      await ScreenSecurityService.enable();

      expect(logs, loggedWarning('Could not turn on screen capture'));
    });

    test('disable completes and logs the failure', () async {
      await ScreenSecurityService.disable();

      expect(logs, loggedWarning('Could not turn off screen capture'));
    });
  });
}
