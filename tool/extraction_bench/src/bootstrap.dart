/// Document-level percentile bootstrap.
library;

import 'rng.dart';

class Ci {
  const Ci(this.mean, this.lo, this.hi);
  final double mean;
  final double lo;
  final double hi;

  Map<String, dynamic> toJson() => {'mean': mean, 'lo': lo, 'hi': hi};
}

double _mean(List<double> v) =>
    v.isEmpty ? 0 : v.fold<double>(0, (a, b) => a + b) / v.length;

(double, double) _percentiles(List<double> sorted) {
  final b = sorted.length;
  final lo = sorted[(0.025 * b).floor().clamp(0, b - 1)];
  final hi = sorted[((0.975 * b).ceil() - 1).clamp(0, b - 1)];
  return (lo, hi);
}

/// 95% percentile CIs of the mean of each metric, resampling documents with
/// replacement [samples] times. All metrics share the same resamples. The
/// stream depends only on [seed] and [label], so groups don't affect each
/// other.
Map<String, Ci> bootstrapMeans(
  Map<String, List<double>> metrics, {
  required int samples,
  required int seed,
  required String label,
}) {
  if (metrics.isEmpty) return const {};
  final n = metrics.values.first.length;
  for (final v in metrics.values) {
    if (v.length != n) throw ArgumentError('metric lists differ in length');
  }
  if (n == 0) return {for (final k in metrics.keys) k: const Ci(0, 0, 0)};
  final rng = BenchRng.derive(seed, label);
  final keys = metrics.keys.toList();
  final values = [for (final k in keys) metrics[k]!];
  final means = [for (final _ in keys) List<double>.filled(samples, 0)];
  final sums = List<double>.filled(keys.length, 0);
  for (var b = 0; b < samples; b++) {
    sums.fillRange(0, sums.length, 0);
    for (var i = 0; i < n; i++) {
      final idx = rng.nextInt(n);
      for (var k = 0; k < keys.length; k++) {
        sums[k] += values[k][idx];
      }
    }
    for (var k = 0; k < keys.length; k++) {
      means[k][b] = sums[k] / n;
    }
  }
  final out = <String, Ci>{};
  for (var k = 0; k < keys.length; k++) {
    final sorted = means[k]..sort();
    final (lo, hi) = _percentiles(sorted);
    out[keys[k]] = Ci(_mean(values[k]), lo, hi);
  }
  return out;
}

class PairedDiff {
  const PairedDiff(this.n, this.meanA, this.meanB, this.diff, this.pDiffLeq0);
  final int n;
  final double meanA;
  final double meanB;

  /// Mean of B − A with its 95% CI.
  final Ci diff;

  /// Share of resamples whose mean difference is ≤ 0 (B not better than A).
  final double pDiffLeq0;

  Map<String, dynamic> toJson() => {
    'docs': n,
    'meanA': meanA,
    'meanB': meanB,
    'diff': diff.toJson(),
    'pDiffLeq0': pDiffLeq0,
  };
}

/// Paired bootstrap of `b[i] − a[i]` over documents.
PairedDiff pairedBootstrap(
  List<double> a,
  List<double> b, {
  required int samples,
  required int seed,
  required String label,
}) {
  if (a.length != b.length) {
    throw ArgumentError('paired lists differ in length');
  }
  final n = a.length;
  if (n == 0) return const PairedDiff(0, 0, 0, Ci(0, 0, 0), 1);
  final d = [for (var i = 0; i < n; i++) b[i] - a[i]];
  final rng = BenchRng.derive(seed, label);
  final means = List<double>.filled(samples, 0);
  var leq0 = 0;
  for (var s = 0; s < samples; s++) {
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      sum += d[rng.nextInt(n)];
    }
    means[s] = sum / n;
    if (means[s] <= 0) leq0++;
  }
  means.sort();
  final (lo, hi) = _percentiles(means);
  return PairedDiff(
    n,
    _mean(a),
    _mean(b),
    Ci(_mean(d), lo, hi),
    leq0 / samples,
  );
}
