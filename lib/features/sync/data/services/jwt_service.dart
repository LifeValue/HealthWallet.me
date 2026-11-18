import 'dart:convert';

class JwtService {
  /// Decodes a JWT token and returns the payload
  static Map<String, dynamic>? decodeJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      return payloadMap;
    } catch (e) {
      return null;
    }
  }

  /// Gets the expiration time from a JWT token
  static DateTime? getExpirationTime(String token) {
    try {
      final decoded = decodeJWT(token);
      if (decoded == null) return null;

      final exp = decoded['exp'];
      if (exp == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      return null;
    }
  }

  /// Checks if a JWT token is expired
  static bool isExpired(String token) {
    final expirationTime = getExpirationTime(token);
    if (expirationTime == null) return true;

    return DateTime.now().isAfter(expirationTime);
  }

  /// Checks if a JWT token is valid (not expired)
  static bool isValid(String token) {
    return !isExpired(token);
  }

  /// Gets the time remaining until expiration
  static Duration? getTimeUntilExpiration(String token) {
    final expirationTime = getExpirationTime(token);
    if (expirationTime == null) return null;

    final now = DateTime.now();
    if (now.isAfter(expirationTime)) return Duration.zero;

    return expirationTime.difference(now);
  }

  /// Gets a user-friendly expiration description
  static String getExpirationDescription(String token) {
    final timeUntilExpiration = getTimeUntilExpiration(token);
    if (timeUntilExpiration == null) return 'Invalid token';

    if (timeUntilExpiration.isNegative) {
      final expiredDuration = timeUntilExpiration.abs();
      if (expiredDuration.inDays > 0) {
        return 'Expired ${expiredDuration.inDays} day${expiredDuration.inDays != 1 ? 's' : ''} ago';
      } else if (expiredDuration.inHours > 0) {
        return 'Expired ${expiredDuration.inHours} hour${expiredDuration.inHours != 1 ? 's' : ''} ago';
      } else {
        return 'Expired ${expiredDuration.inMinutes} minute${expiredDuration.inMinutes != 1 ? 's' : ''} ago';
      }
    } else {
      if (timeUntilExpiration.inDays > 0) {
        return 'Expires in ${timeUntilExpiration.inDays} day${timeUntilExpiration.inDays != 1 ? 's' : ''}';
      } else if (timeUntilExpiration.inHours > 0) {
        return 'Expires in ${timeUntilExpiration.inHours} hour${timeUntilExpiration.inHours != 1 ? 's' : ''}';
      } else {
        return 'Expires in ${timeUntilExpiration.inMinutes} minute${timeUntilExpiration.inMinutes != 1 ? 's' : ''}';
      }
    }
  }
}
