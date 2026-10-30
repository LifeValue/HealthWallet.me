import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/services/pdf_conversion_mixin.dart';
import 'package:health_wallet/features/processing/domain/services/text_recognition_service.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
// The plugin exports no other way to replace its platform, which the
// rasterizer needs to run without a native PDF engine.
// ignore: implementation_imports
import 'package:printing/src/interface.dart';

import '../../../../helpers/log_capture.dart';
import '../../../share_records/share_test_helpers.dart';

class _Converter extends Fake
    with PdfConversionMixin
    implements TextRecognitionService {}

/// A rendered page whose PNG comes from [png], or fails when it is null.
class _Page extends PdfRaster {
  _Page(this.png) : super(2, 2, Uint8List(16));

  final Uint8List? png;

  @override
  Future<Uint8List> toPng() async => png ?? (throw Exception('bad page'));
}

/// Renders the pages it is given instead of running a native PDF engine.
class _FakePrinting extends PrintingPlatform {
  _FakePrinting(this.pages);

  final List<PdfRaster> pages;

  @override
  Stream<PdfRaster> raster(Uint8List document, List<int>? pages, double dpi) =>
      Stream.fromIterable(this.pages);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
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

  test('a page that cannot be converted is skipped and logged', () async {
    final realPrinting = PrintingPlatform.instance;
    addTearDown(() => PrintingPlatform.instance = realPrinting);
    final goodPng = img.encodePng(img.Image(width: 2, height: 2));
    PrintingPlatform.instance = _FakePrinting([_Page(null), _Page(goodPng)]);
    final pdf = File('${root.path}/scan.pdf')..writeAsBytesSync([1, 2, 3]);

    final pages = await converter.convertPdfToImages(pdf.path);

    expect(pages, hasLength(1));
    expect(pages.single, endsWith('_2.png'));
    expect(File(pages.single).existsSync(), isTrue);
    expect(logs, loggedWarning('Could not convert PDF page 1'));
  });
}
