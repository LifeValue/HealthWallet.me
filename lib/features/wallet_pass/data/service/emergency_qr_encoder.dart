import 'dart:convert';

import 'package:health_wallet/features/wallet_pass/domain/entity/emergency_card_data.dart';
import 'package:intl/intl.dart';

abstract final class EmergencyQrEncoder {
  static const _host = 'emergency.healthwallet.me';

  static String encode(EmergencyCardData data) {
    final params = <String, String>{
      'name': data.patientName,
    };

    if (data.bloodType != null) params['blood'] = data.bloodType!;
    if (data.dateOfBirth != null) {
      params['dob'] = DateFormat('MM/dd/yyyy').format(data.dateOfBirth!);
    }
    if (data.gender != null) params['gender'] = data.gender!;
    if (data.patientPhone != null) params['phone'] = data.patientPhone!;
    if (data.allergies.isNotEmpty) {
      params['allergies'] = data.allergies.join(', ');
    }
    if (data.conditions.isNotEmpty) {
      params['conditions'] = data.conditions.join(', ');
    }
    if (data.medications.isNotEmpty) {
      params['meds'] = data.medications.join(', ');
    }
    if (data.emergencyContactName != null) {
      params['ec_name'] = data.emergencyContactName!;
    }
    if (data.emergencyContactPhone != null) {
      params['ec_phone'] = data.emergencyContactPhone!;
    }

    return Uri.https(_host, '/', params).toString();
  }

  static EmergencyCardData decode(String uriString) {
    final uri = Uri.parse(uriString);
    final q = uri.queryParameters;

    if (q.containsKey('data')) return _decodeBase64(q['data']!);

    return EmergencyCardData(
      patientName: q['name'] ?? '',
      bloodType: q['blood'],
      dateOfBirth: q['dob'] != null ? _parseDate(q['dob']!) : null,
      gender: q['gender'],
      patientPhone: q['phone'],
      allergies: _splitList(q['allergies']),
      conditions: _splitList(q['conditions']),
      medications: _splitList(q['meds']),
      emergencyContactName: q['ec_name'],
      emergencyContactPhone: q['ec_phone'],
    );
  }

  static EmergencyCardData decodeFromDataParam(String base64Data) {
    return _decodeBase64(base64Data);
  }

  static List<String> _splitList(String? value) {
    if (value == null || value.isEmpty) return const [];
    return value.split(', ');
  }

  static DateTime? _parseDate(String value) {
    try {
      return DateFormat('MM/dd/yyyy').parse(value);
    } catch (_) {
      return DateTime.tryParse(value);
    }
  }

  static EmergencyCardData _decodeBase64(String base64Data) {
    final padded = base64Data.padRight(
      base64Data.length + (4 - base64Data.length % 4) % 4,
      '=',
    );
    final jsonStr = utf8.decode(base64Url.decode(padded));
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;

    return EmergencyCardData(
      patientName: map['n'] as String? ?? '',
      bloodType: map['b'] as String?,
      dateOfBirth:
          map['d'] != null ? DateTime.tryParse(map['d'] as String) : null,
      gender: map['g'] as String?,
      patientPhone: map['p'] as String?,
      allergies: (map['a'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      conditions: (map['c'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      medications: (map['m'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      emergencyContactName: map['en'] as String?,
      emergencyContactPhone: map['ep'] as String?,
    );
  }
}
