import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a patient without a birth date is read with none, not today', () {
    final read = MappingPatient.fromFhirResource(
      const Patient(id: 'p1', rawResource: {'resourceType': 'Patient'}),
    );
    expect(read.dateOfBirth.value, isEmpty);
  });

  test('a scanned patient without a gender is saved without one', () {
    final saved = const MappingPatient(
      id: 'p1',
      givenName: MappedProperty(value: 'Ana'),
    ).toFhirResource();
    expect(saved.rawResource.containsKey('gender'), isFalse);
  });
}
