import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:intl/intl.dart';

class DateFormatUtils {
  DateFormatUtils._();

  static String humanReadable(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat.yMMMMd().format(dateTime);
  }

  static String isoCompact(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  static String formatDate(DateTime? dateTime, RegionPreset region) {
    if (dateTime == null) return '';
    return DateFormat(region.dateFormat).format(dateTime);
  }

  static String formatDateTime(DateTime? dateTime, RegionPreset region) {
    if (dateTime == null) return '';
    return DateFormat(region.dateTimeFormat).format(dateTime);
  }

  static String formatIsoForDisplay(String isoDate, RegionPreset region) {
    if (isoDate.isEmpty) return isoDate;
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    return DateFormat(region.dateFormat).format(parsed);
  }

  static DateTime? tryParseIso(String value) {
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    try {
      return DateFormat('yyyy-MM-dd').parse(value);
    } catch (_) {
      return null;
    }
  }

  static String getSincePretty(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return l10n.timeAgoDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.timeAgoHours(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return l10n.timeAgoMinutes(difference.inMinutes);
    } else {
      return l10n.justNow;
    }
  }
}
