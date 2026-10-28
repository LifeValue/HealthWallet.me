import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/services/pdf_conversion_mixin.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';

import '../../../share_records/share_test_helpers.dart';

class _Converter extends Fake
    with PdfConversionMixin
    implements TextRecognitionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late _Converter converter;

  setUp(() {
    root = mockPathProvider();
    converter = _Converter();
  });

  File cacheFile(String key) =>
      File('${root.path}/Documents/pdf_preview_cache/$key.json');

  File page(String name) =>
      File('${root.path}/tmp/$name')..writeAsStringSync('png');

  test('the cache directory is created under Documents', () async {
    final dir = await converter.getCacheDirectory();

    expect(dir.path, '${root.path}/Documents/pdf_preview_cache');
    expect(dir.existsSync(), isTrue);
  });

  test('the cache key changes with every input', () {
    final modified = DateTime(2026, 10, 28);
    final key = converter.generateCacheKey('/a.pdf', 10, modified, 72);

    expect(key, hasLength(64));
    expect(converter.generateCacheKey('/a.pdf', 10, modified, 72), key);
    expect(converter.generateCacheKey('/b.pdf', 10, modified, 72), isNot(key));
    expect(converter.generateCacheKey('/a.pdf', 11, modified, 72), isNot(key));
    expect(
      converter.generateCacheKey('/a.pdf', 10, modified, 200),
      isNot(key),
    );
  });

  test('saved pages come back from the cache while they exist', () async {
    final pages = [page('p1.png').path, page('p2.png').path];

    await converter.saveToCache('key', pages);

    expect(await converter.getCachedImages('key'), pages);
  });

  test('a missing cache entry returns null', () async {
    expect(await converter.getCachedImages('unknown'), isNull);
  });

  test('a stale entry is dropped with the pages that remain', () async {
    final kept = page('p1.png');
    final gone = '${root.path}/tmp/p2.png';
    await converter.saveToCache('key', [kept.path, gone]);

    expect(await converter.getCachedImages('key'), isNull);
    expect(cacheFile('key').existsSync(), isFalse);
    expect(kept.existsSync(), isFalse);
  });

  test('an empty entry is dropped', () async {
    await converter.saveToCache('key', []);

    expect(await converter.getCachedImages('key'), isNull);
    expect(cacheFile('key').existsSync(), isFalse);
  });

  test('a corrupt entry reads as a cache miss', () async {
    await converter.getCacheDirectory();
    cacheFile('key').writeAsStringSync('{not json');

    expect(await converter.getCachedImages('key'), isNull);
  });

  test('saving does not throw when the cache cannot be written', () async {
    await converter.getCacheDirectory();
    // A directory where the metadata file should go makes the write fail.
    Directory(cacheFile('key').path).createSync();

    await expectLater(converter.saveToCache('key', ['/x.png']), completes);
    expect(await converter.getCachedImages('key'), isNull);
  });

  test('converting a missing PDF for preview returns no pages', () async {
    expect(
      await converter.convertPdfToImagesForPreview('${root.path}/none.pdf'),
      isEmpty,
    );
  });

  test('converting an unreadable PDF returns no pages', () async {
    expect(await converter.convertPdfToImages('${root.path}/none.pdf'), []);
  });
}
