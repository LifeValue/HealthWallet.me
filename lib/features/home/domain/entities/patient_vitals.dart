import 'package:flutter/material.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/utils/unit_converter.dart';
import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';

enum PatientVitalType {
  heartRate,
  bloodPressure,
  temperature,
  bloodOxygen,
  respiratoryRate,
  weight,
  height,
  bmi,
  bloodGlucose,
  systolicBloodPressure,
  diastolicBloodPressure,
}

extension PatientVitalTypeX on PatientVitalType {
  String get title {
    switch (this) {
      case PatientVitalType.heartRate:
        return 'Heart Rate';
      case PatientVitalType.bloodPressure:
        return 'Blood Pressure';
      case PatientVitalType.temperature:
        return 'Temperature';
      case PatientVitalType.bloodOxygen:
        return 'Blood Oxygen';
      case PatientVitalType.respiratoryRate:
        return 'Respiratory Rate';
      case PatientVitalType.weight:
        return 'Weight';
      case PatientVitalType.height:
        return 'Height';
      case PatientVitalType.bmi:
        return 'BMI';
      case PatientVitalType.bloodGlucose:
        return 'Blood Glucose';
      case PatientVitalType.systolicBloodPressure:
        return 'Systolic Blood Pressure';
      case PatientVitalType.diastolicBloodPressure:
        return 'Diastolic Blood Pressure';
    }
  }

  String get defaultUnit {
    switch (this) {
      case PatientVitalType.bloodPressure:
      case PatientVitalType.systolicBloodPressure:
      case PatientVitalType.diastolicBloodPressure:
        return 'mmHg';
      case PatientVitalType.heartRate:
        return 'BPM';
      case PatientVitalType.temperature:
        return '°F';
      case PatientVitalType.bloodOxygen:
        return '%';
      case PatientVitalType.respiratoryRate:
        return '/min';
      case PatientVitalType.weight:
        return 'kg';
      case PatientVitalType.height:
        return 'cm';
      case PatientVitalType.bmi:
        return 'kg/m²';
      case PatientVitalType.bloodGlucose:
        return 'mg/dL';
    }
  }

  static PatientVitalType? fromTitle(String title) {
    for (final type in PatientVitalType.values) {
      if (type.title == title) return type;
    }
    return null;
  }

  String unitForRegion(RegionPreset region) {
    switch (this) {
      case PatientVitalType.weight:
        return region.weightUnit;
      case PatientVitalType.height:
        return region.heightUnit;
      case PatientVitalType.temperature:
        return region.temperatureUnit;
      case PatientVitalType.bloodGlucose:
        return region.glucoseUnit;
      default:
        return defaultUnit;
    }
  }
}

class PatientVital {
  final Widget? icon;
  final String title;
  final String value;
  final String unit;
  final String? status;
  final String? observationId;
  final DateTime? effectiveDate;

  const PatientVital({
    this.icon,
    required this.title,
    required this.value,
    required this.unit,
    this.status,
    this.observationId,
    this.effectiveDate,
  });

  factory PatientVital.fromObservation(
    Observation observation, {
    RegionPreset? region,
  }) {
    final title = FhirFieldExtractor.extractVitalSignTitle(observation);
    var value = FhirFieldExtractor.extractVitalSignValue(observation);
    var unit = FhirFieldExtractor.extractVitalSignUnit(observation);
    final status = FhirFieldExtractor.extractVitalSignStatus(observation);
    final effectiveDate = observation.date;

    if (region != null) {
      final vitalType = PatientVitalTypeX.fromTitle(title);
      if (vitalType != null) {
        final numericValue = double.tryParse(value.trim());
        if (numericValue != null) {
          if (vitalType == PatientVitalType.height &&
              region.heightUnit == 'ft/in') {
            final normalizedFrom = unit.trim().toLowerCase();
            if (normalizedFrom == 'cm' || normalizedFrom == 'centimeters') {
              value = UnitConverter.cmToFeetInchesString(numericValue);
              unit = '';
              return PatientVital(
                title: title,
                value: value,
                unit: unit,
                status: status,
                observationId: observation.id,
                effectiveDate: effectiveDate,
              );
            }
          }
          final converted = UnitConverter.convertForDisplay(
            value: numericValue,
            fromUnit: unit,
            type: vitalType,
            region: region,
          );
          value = UnitConverter.formatValue(converted.value, vitalType);
          unit = converted.unit;
        }
      }
    }

    return PatientVital(
      title: title,
      value: value,
      unit: unit,
      status: status,
      observationId: observation.id,
      effectiveDate: effectiveDate,
    );
  }
}
