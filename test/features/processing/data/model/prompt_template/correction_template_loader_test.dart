import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/model/prompt_template/correction_template_loader.dart';

import '../../../../../helpers/log_capture.dart';

// The loader is a singleton that caches what it loaded, and each test file
// runs in its own isolate, so this file sees a cold cache.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
  const broken = 'assets/correction_templates/ro/lab_report_male.json';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == broken) return null;
          final bytes = await File(key).readAsBytes();
          return ByteData.sublistView(bytes);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test(
    'a template that cannot be loaded is logged and the rest still work',
    () async {
      final example = await CorrectionTemplateLoader().getBestExample(
        documentCategory: 'lab_report',
      );

      expect(example, isNotNull);
      expect(logs, loggedWarning('Could not load the correction template'));
      expect(logs, loggedWarning(broken));
    },
  );
}
