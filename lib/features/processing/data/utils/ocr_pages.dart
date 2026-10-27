/// Per-page OCR text for phase 2: lines printed on every page (letterhead,
/// patient block, footer) kept on the first page only, and the pages grouped
/// into chunks that each fit one prompt.
class OcrPages {
  OcrPages._();

  static final _whitespace = RegExp(r'\s+');

  static String _key(String line) => line.trim().replaceAll(_whitespace, ' ').toLowerCase();

  /// A line long enough to be a header rather than a result cell that
  /// happens to repeat: OCR often gives table columns as separate lines, and
  /// values and units (`11`, `mUI/mL`, `x10^9/L`) are shorter than 8.
  static bool _isHeaderCandidate(String key) => key.length >= 8;

  /// [pages] with every line that appears on all of them (all but one from 3
  /// pages up, for OCR noise) kept only where it first appears. Fewer than 2
  /// pages come back unchanged.
  static List<String> withoutRepeatedLines(List<String> pages) {
    if (pages.length < 2) return pages;
    final counts = <String, int>{};
    for (final page in pages) {
      for (final key in {for (final line in page.split('\n')) _key(line)}) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final threshold = pages.length >= 3 ? pages.length - 1 : pages.length;
    final repeated = {
      for (final e in counts.entries)
        if (e.value >= threshold && _isHeaderCandidate(e.key)) e.key,
    };
    if (repeated.isEmpty) return pages;

    final seen = <String>{};
    return [
      for (final page in pages)
        page.split('\n').where((line) {
          final key = _key(line);
          if (!repeated.contains(key)) return true;
          return seen.add(key);
        }).join('\n'),
    ];
  }

  /// [pages] in order as few chunks as possible of at most [maxChars] each.
  /// A page over [maxChars] is split between lines, and a single longer line
  /// is cut.
  static List<String> chunks(List<String> pages, int maxChars) {
    final pieces = <String>[];
    for (final page in pages) {
      final text = page.trim();
      if (text.isEmpty) continue;
      if (text.length <= maxChars) {
        pieces.add(text);
        continue;
      }
      var current = '';
      for (var line in text.split('\n')) {
        while (line.length > maxChars) {
          if (current.isNotEmpty) pieces.add(current);
          current = '';
          pieces.add(line.substring(0, maxChars));
          line = line.substring(maxChars);
        }
        if (current.isNotEmpty && current.length + 1 + line.length > maxChars) {
          pieces.add(current);
          current = '';
        }
        current = current.isEmpty ? line : '$current\n$line';
      }
      if (current.isNotEmpty) pieces.add(current);
    }

    final result = <String>[];
    for (final piece in pieces) {
      if (result.isNotEmpty && result.last.length + 1 + piece.length <= maxChars) {
        result.last = '${result.last}\n$piece';
      } else {
        result.add(piece);
      }
    }
    return result;
  }
}
