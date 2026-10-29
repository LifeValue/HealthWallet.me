import 'package:intl/intl.dart';

/// The date in a default backup name, in the app's language and in the same
/// short-month style as the backup history (`yMMMd`): "Oct 28, 2026" in
/// English, "28 oct. 2026" in Romanian. With [withTime], the time follows,
/// as in the history list ("Oct 28, 2026 14:05").
String backupNameDate(
  DateTime time,
  String localeName, {
  bool withTime = false,
}) {
  final format = DateFormat.yMMMd(localeName);
  return (withTime ? format.add_Hm() : format).format(time);
}
