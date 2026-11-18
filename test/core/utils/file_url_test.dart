import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/file_url.dart';

void main() {
  group('filePathOfUrl', () {
    test('drops the scheme and decodes an encoded name', () {
      expect(filePathOfUrl('file://my%20report.pdf'), 'my report.pdf');
      expect(
        filePathOfUrl('file://Scrisoare%20medical%C4%83.pdf'),
        'Scrisoare medicală.pdf',
      );
    });

    test('keeps a name with unencoded accents as it is', () {
      expect(
        filePathOfUrl('file://Scrisoare medicală_1a2b3c4d.pdf'),
        'Scrisoare medicală_1a2b3c4d.pdf',
      );
    });

    test('keeps a literal percent sign that is no encoding', () {
      expect(filePathOfUrl('file://50% off.pdf'), '50% off.pdf');
    });

    test('keeps an encoding that is not UTF-8 as it is', () {
      expect(filePathOfUrl('file://bad%FF.pdf'), 'bad%FF.pdf');
    });

    test('keeps absolute paths and takes a url without scheme as a path', () {
      expect(
        filePathOfUrl('file:///var/mobile/Documents/a.pdf'),
        '/var/mobile/Documents/a.pdf',
      );
      expect(filePathOfUrl('scans/a.pdf'), 'scans/a.pdf');
    });
  });
}
