import 'package:freezed_annotation/freezed_annotation.dart';

part 'emergency_card_data.freezed.dart';

@freezed
class EmergencyCardData with _$EmergencyCardData {
  const factory EmergencyCardData({
    @Default('') String patientName,
    String? bloodType,
    DateTime? dateOfBirth,
    String? gender,
    @Default([]) List<String> allergies,
    @Default([]) List<String> conditions,
    @Default([]) List<String> medications,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? patientPhone,
  }) = _EmergencyCardData;
}
