import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';

class SpecialtyCard {
  final MedicalSpecialty specialty;
  final int count;

  const SpecialtyCard({
    required this.specialty,
    required this.count,
  });
}
