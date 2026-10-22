/// Deterministic pseudo-random numbers for the benchmark.
///
/// mulberry32 on 32-bit arithmetic, so a seed gives the same stream on every
/// platform and SDK version (`dart:math` `Random(seed)` makes no such promise).
class BenchRng {
  BenchRng(int seed) : _state = seed & _mask;

  /// A generator for [label] under [seed], independent of call order elsewhere.
  factory BenchRng.derive(int seed, String label) =>
      BenchRng(fnv1a32('$seed/$label'));

  static const int _mask = 0xFFFFFFFF;
  int _state;

  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ (t + _imul(t ^ (t >>> 7), t | 61))) & _mask;
    return (t ^ (t >>> 14)) & _mask;
  }

  /// Uniform in [0, max).
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return nextUint32() % max;
  }

  /// Uniform in [min, max] inclusive.
  int intBetween(int min, int max) => min + nextInt(max - min + 1);

  /// Uniform in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  double doubleBetween(double min, double max) =>
      min + (max - min) * nextDouble();

  bool chance(double p) => nextDouble() < p;

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// [count] distinct items in their original order.
  List<T> sample<T>(List<T> items, int count) {
    final indices = List<int>.generate(items.length, (i) => i);
    for (var i = indices.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = indices[i];
      indices[i] = indices[j];
      indices[j] = tmp;
    }
    final chosen = indices.take(count).toList()..sort();
    return [for (final i in chosen) items[i]];
  }

  /// A UUID-shaped (version 4 layout) hex string.
  String uuid() {
    final hex = StringBuffer();
    for (var i = 0; i < 4; i++) {
      hex.write(nextUint32().toRadixString(16).padLeft(8, '0'));
    }
    final h = hex.toString().split('');
    h[12] = '4';
    h[16] = '89ab'[int.parse(h[16], radix: 16) & 3];
    final s = h.join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-'
        '${s.substring(16, 20)}-${s.substring(20)}';
  }

  static int _imul(int a, int b) => (a * b) & _mask;
}

/// FNV-1a over the UTF-16 code units of [s], 32 bits.
int fnv1a32(String s) {
  var hash = 0x811C9DC5;
  for (final unit in s.codeUnits) {
    hash ^= unit & 0xFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
    hash ^= unit >> 8;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
