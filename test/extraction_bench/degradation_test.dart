import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../integration_test/extraction_bench/degradation.dart';

void main() {
  late Directory tmp;
  late String page;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bench_degrade_');
    final image = img.Image(width: 240, height: 320);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(image, x1: 20, y1: 40, x2: 200, y2: 60, color: img.ColorRgb8(0, 0, 0));
    page = p.join(tmp.path, 'page.png');
    File(page).writeAsBytesSync(img.encodePng(image));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('clean returns the page untouched', () async {
    expect(await degradePage(page, mode: 'clean', seed: 1, pageIndex: 0, outDir: tmp.path), page);
  });

  for (final mode in ['scan', 'photo']) {
    test('$mode writes a decodable JPEG, deterministic for the seed', () async {
      final a = Directory(p.join(tmp.path, 'a'))..createSync();
      final b = Directory(p.join(tmp.path, 'b'))..createSync();
      final c = Directory(p.join(tmp.path, 'c'))..createSync();
      final outA = await degradePage(page, mode: mode, seed: 42, pageIndex: 0, outDir: a.path);
      final outB = await degradePage(page, mode: mode, seed: 42, pageIndex: 0, outDir: b.path);
      final outC = await degradePage(page, mode: mode, seed: 43, pageIndex: 0, outDir: c.path);
      expect(p.extension(outA), '.jpg');
      expect(File(outA).readAsBytesSync(), File(outB).readAsBytesSync());
      expect(File(outA).readAsBytesSync(), isNot(File(outC).readAsBytesSync()));
      final decoded = img.decodeJpg(File(outA).readAsBytesSync())!;
      expect(decoded.width, greaterThanOrEqualTo(240));
    });
  }

  test('an unknown mode is rejected', () {
    expect(degradePage(page, mode: 'blurry', seed: 1, pageIndex: 0, outDir: tmp.path), throwsArgumentError);
  });
}
