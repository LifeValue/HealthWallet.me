import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/data/utils/ocr_pages.dart';

const _header = 'Laborator Exemplu SRL\nTelefon: 0700 123 456\nNume pacient: Popescu\nCNP: 1850101000000';

void main() {
  group('withoutRepeatedLines', () {
    test('keeps a header printed on every page only on the first page', () {
      final pages = OcrPages.withoutRepeatedLines([
        '$_header\nEstradiol\n< 18.4\npmol/L\nPagina 1 din 3',
        '$_header\nTSH\n4.21\nµUI/mL\nPagina 2 din 3',
        '$_header\nTestosteron\n27.7\nnmol/L\nPagina 3 din 3',
      ]);

      expect(pages[0], startsWith(_header));
      expect(pages[1], 'TSH\n4.21\nµUI/mL\nPagina 2 din 3');
      expect(pages[2], 'Testosteron\n27.7\nnmol/L\nPagina 3 din 3');
    });

    test('keeps short values that repeat, and lines on only some pages', () {
      final pages = OcrPages.withoutRepeatedLines([
        'FSH\n11\nmUI/mL\nSer / ECLIA',
        'LH\n11\nmUI/mL\nother',
        'TSH\n11\nmUI/mL\nSer / ECLIA',
        'Prolactina\n11\nmUI/mL',
      ]);

      // "11" and "mUI/mL" are on every page but too short to be a header
      // (OCR gives table cells as lines); "Ser / ECLIA" is on 2 of 4 pages,
      // under the threshold of 3.
      expect(pages[1], 'LH\n11\nmUI/mL\nother');
      expect(pages[2], 'TSH\n11\nmUI/mL\nSer / ECLIA');
      expect(pages[3], 'Prolactina\n11\nmUI/mL');
    });

    test('tolerates one page where OCR misread the header, from 3 pages up', () {
      final pages = OcrPages.withoutRepeatedLines([
        'Laborator Exemplu SRL\nA',
        'Laborator Exemplu SRL\nB',
        'Laborator Exernplu SRL\nC',
      ]);

      expect(pages, ['Laborator Exemplu SRL\nA', 'B', 'Laborator Exernplu SRL\nC']);
    });

    test('a single page comes back unchanged', () {
      expect(OcrPages.withoutRepeatedLines(['$_header\n$_header']), ['$_header\n$_header']);
    });
  });

  group('chunks', () {
    test('joins pages up to the limit, in order', () {
      expect(OcrPages.chunks(['aaaa', 'bbbb', 'cccc'], 9), ['aaaa\nbbbb', 'cccc']);
      expect(OcrPages.chunks(['aaaa', '', 'bbbb'], 100), ['aaaa\nbbbb']);
    });

    test('splits a long page between lines and cuts a single overlong line', () {
      expect(OcrPages.chunks(['l1\nl2\nl3\nl4'], 5), ['l1\nl2', 'l3\nl4']);
      expect(OcrPages.chunks(['abcdefghij'], 4), ['abcd', 'efgh', 'ij']);
    });

    test('no chunk is longer than the limit', () {
      final page = List.generate(200, (i) => 'Line $i with a value ${i * 3}').join('\n');
      final chunks = OcrPages.chunks([page, page], 500);
      expect(chunks.every((c) => c.length <= 500), isTrue);
      expect(chunks.join('\n'), '$page\n$page');
    });
  });
}
