import 'package:intl/intl.dart';

// Record times are shown in the device's time zone, so tests build the text
// they expect from the same instant: the suite passes in any zone.

/// The time of [iso] in the device's time zone ("10:30 AM" in UTC).
String localTime(String iso, {bool seconds = false}) =>
    (seconds ? DateFormat.jms() : DateFormat.jm())
        .format(DateTime.parse(iso).toLocal())
        .replaceAll(' ', ' ');

/// The date and time of [iso] in the device's time zone, as the record
/// views show it ("Mar 15, 2024, 10:30 AM" in UTC).
String localDateTime(
  String iso, {
  String separator = ', ',
  bool seconds = false,
}) =>
    '${DateFormat.yMMMd().format(DateTime.parse(iso).toLocal())}'
    '$separator${localTime(iso, seconds: seconds)}';
