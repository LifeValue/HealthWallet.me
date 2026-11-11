/// How many whole days a "Before restore" safety copy is kept, counted from
/// when it was made. Set per desktop; see `BackupService
/// .getSafetyCopyRetentionDays`.
abstract final class SafetyCopyRetention {
  /// Used until the user sets a value, or when the stored one is invalid.
  static const defaultDays = 30;
  static const minDays = 1;
  static const maxDays = 365;

  static final _wholeNumber = RegExp(r'^\d+$');

  /// Whether [days] is a retention the user may set.
  static bool isValid(int days) => days >= minDays && days <= maxDays;

  /// The days typed in [input] (surrounding spaces allowed), or null when it
  /// isn't a whole number from [minDays] to [maxDays].
  static int? parseDays(String input) {
    final trimmed = input.trim();
    if (!_wholeNumber.hasMatch(trimmed)) return null;
    final days = int.tryParse(trimmed);
    return days != null && isValid(days) ? days : null;
  }
}
