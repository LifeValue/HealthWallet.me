/// Minimum-cost one-to-one assignment (Kuhn–Munkres) on a rectangular cost
/// matrix.
library;

/// Assigns min(rows, cols) row/column pairs with the smallest total cost.
/// Returns `(row, col)` pairs sorted by row.
List<(int, int)> hungarian(List<List<double>> cost) {
  final rows = cost.length;
  if (rows == 0) return const [];
  final cols = cost.first.length;
  if (cols == 0) return const [];
  for (final r in cost) {
    if (r.length != cols) throw ArgumentError('cost matrix is not rectangular');
  }
  if (rows > cols) {
    final transposed = [
      for (var j = 0; j < cols; j++) [for (var i = 0; i < rows; i++) cost[i][j]],
    ];
    return [for (final (c, r) in hungarian(transposed)) (r, c)]
      ..sort((a, b) => a.$1.compareTo(b.$1));
  }

  // Potentials method (rows <= cols), 1-based with a virtual column 0.
  const inf = double.infinity;
  final n = rows;
  final m = cols;
  final u = List<double>.filled(n + 1, 0);
  final v = List<double>.filled(m + 1, 0);
  final match = List<int>.filled(m + 1, 0); // column -> row
  final way = List<int>.filled(m + 1, 0);
  for (var i = 1; i <= n; i++) {
    match[0] = i;
    var j0 = 0;
    final minv = List<double>.filled(m + 1, inf);
    final used = List<bool>.filled(m + 1, false);
    do {
      used[j0] = true;
      final i0 = match[j0];
      var delta = inf;
      var j1 = 0;
      for (var j = 1; j <= m; j++) {
        if (used[j]) continue;
        final cur = cost[i0 - 1][j - 1] - u[i0] - v[j];
        if (cur < minv[j]) {
          minv[j] = cur;
          way[j] = j0;
        }
        if (minv[j] < delta) {
          delta = minv[j];
          j1 = j;
        }
      }
      for (var j = 0; j <= m; j++) {
        if (used[j]) {
          u[match[j]] += delta;
          v[j] -= delta;
        } else {
          minv[j] -= delta;
        }
      }
      j0 = j1;
    } while (match[j0] != 0);
    do {
      final j1 = way[j0];
      match[j0] = match[j1];
      j0 = j1;
    } while (j0 != 0);
  }
  final result = <(int, int)>[
    for (var j = 1; j <= m; j++)
      if (match[j] != 0) (match[j] - 1, j - 1),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return result;
}
