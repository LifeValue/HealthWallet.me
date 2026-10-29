import 'package:intl/intl.dart';

/// What the app shows for the FHIR time [iso] on this machine: the moment in
/// the local time zone, formatted like the records screens ("Mar 15, 2024,
/// 10:30 AM"). Tests use it so they pass in any time zone, CI's included.
String localDateTime(
  String iso, {
  String separator = ', ',
  bool withSeconds = false,
}) => _clean(
  DateFormat.yMMMd()
      .addPattern(
        (withSeconds ? DateFormat.jms() : DateFormat.jm()).pattern,
        separator,
      )
      .format(DateTime.parse(iso).toLocal()),
);

/// The local time of day of [iso] ("9:30 AM").
String localTime(String iso) =>
    _clean(DateFormat.jm().format(DateTime.parse(iso).toLocal()));

/// The local date of [iso] ("Mar 15, 2024").
String localDate(String iso) =>
    _clean(DateFormat.yMMMd().format(DateTime.parse(iso).toLocal()));

/// CLDR's narrow no-break space before AM/PM, as the app replaces it.
String _clean(String text) => text.replaceAll(' ', ' ');
