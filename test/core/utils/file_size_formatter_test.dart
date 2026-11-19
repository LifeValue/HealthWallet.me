import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/core/utils/file_size_formatter.dart';

void main() {
  final cases = <int, String>{
    0: '0 B',
    512: '512 B',
    1023: '1023 B',
    1024: '1.0 KB',
    1536: '1.5 KB',
    248576: '242.8 KB',
    1048576: '1.0 MB',
    2411724: '2.3 MB',
    1181116006: '1.1 GB',
    1099511627776: '1.0 TB',
  };
  cases.forEach((bytes, text) {
    test('$bytes -> $text', () {
      expect(FileSizeFormatter.format(bytes), text);
    });
  });

  test('moves up a unit instead of showing 1024.0', () {
    // 1048575 B is 1023.999 KB, which rounds to 1024.0 KB.
    expect(FileSizeFormatter.format(1048575), '1.0 MB');
  });
}
