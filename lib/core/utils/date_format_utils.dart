import 'package:health_wallet/core/config/constants/region_preset.dart';
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

  static String getSincePretty(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes != 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
