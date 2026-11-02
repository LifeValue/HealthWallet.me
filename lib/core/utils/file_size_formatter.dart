abstract final class FileSizeFormatter {
  static const List<String> _units = ['KB', 'MB', 'GB', 'TB'];

  /// [bytes] in the largest unit that keeps the number at 1 or more, with
  /// one decimal: "512 B", "1.5 KB", "2.3 MB", "1.1 GB" (1 KB = 1024 B).
  static String format(int bytes) {
    if (bytes < 1024) return '$bytes B';
    var value = bytes / 1024;
    var unit = 0;
    // Move up while the rounded number would reach 1024 ("1024.0 KB").
    while (unit < _units.length - 1 && value >= 1023.95) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(1)} ${_units[unit]}';
  }
}
