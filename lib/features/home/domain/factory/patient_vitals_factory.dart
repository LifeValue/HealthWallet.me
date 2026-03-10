import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:fhir_r4/fhir_r4.dart' as fhir_r4;
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';

class PatientVitalFactory {
  PatientVitalFactory();

  List<PatientVital> buildFromResources(List<IFhirResource> resources) {
    final Map<String, PatientVital> latestByTitle = <String, PatientVital>{};

    for (final resource in resources) {
      if (resource is! Observation) continue;

      final List<PatientVital> extracted =
          _extractVitalSignsFromObservation(resource);
      for (final vital in extracted) {
        final String normalizedTitle = _normalizeTitle(vital.title);
        final PatientVital normalizedVital = (normalizedTitle == vital.title)
            ? vital
            : PatientVital(
                title: normalizedTitle,
                value: vital.value,
                unit: vital.unit,
                status: vital.status,
                observationId: vital.observationId,
                effectiveDate: vital.effectiveDate,
              );
        final String key = normalizedTitle;
        final PatientVital? existing = latestByTitle[key];
        if (existing == null) {
          latestByTitle[key] = normalizedVital;
          continue;
        }
        final DateTime? existingDate = existing.effectiveDate;
        final DateTime? newDate = normalizedVital.effectiveDate;
        if (existingDate == null && newDate != null) {
          latestByTitle[key] = normalizedVital;
        } else if (existingDate != null && newDate != null) {
          if (newDate.isAfter(existingDate)) {
            latestByTitle[key] = normalizedVital;
          }
        }
      }
    }

    _combineBloodPressure(latestByTitle);

    final List<String> expectedOrder = [
      PatientVitalType.heartRate.title,
      PatientVitalType.bloodPressure.title,
      PatientVitalType.temperature.title,
      PatientVitalType.bloodOxygen.title,
      PatientVitalType.respiratoryRate.title,
      PatientVitalType.weight.title,
      PatientVitalType.height.title,
      PatientVitalType.bmi.title,
      PatientVitalType.bloodGlucose.title,
    ];

    // Add placeholders for missing vitals
    for (final title in expectedOrder) {
      if (!latestByTitle.containsKey(title)) {
        latestByTitle[title] = PatientVital(
          title: title,
          value: 'N/A',
          unit: PatientVitalTypeX.fromTitle(title)?.defaultUnit ?? '',
          status: null,
          observationId: null,
          effectiveDate: null,
        );
      }
    }

    // Return ordered list with placeholders
    final List<PatientVital> ordered = [
      for (final t in expectedOrder) latestByTitle[t]!,
      ...latestByTitle.entries
          .where((e) => !expectedOrder.contains(e.key))
          .map((e) => e.value),
    ];

    return ordered;
  }

  String _normalizeTitle(String title) {
    final t = title.trim().toLowerCase();
    if (t == 'body height' || t == 'height')
      return PatientVitalType.height.title;
    if (t == 'body weight' || t == 'weight')
      return PatientVitalType.weight.title;
    if (t == 'body mass index' || t == 'bmi' || t == 'body mass index (bmi)') {
      return PatientVitalType.bmi.title;
    }
    if (t == 'oxygen saturation' ||
        t == 'oxygen saturation in arterial blood' ||
        t == 'blood oxygen saturation' ||
        t == 'spo2' ||
        t == 'pulse oximetry' ||
        t == 'oximetry') {
      return PatientVitalType.bloodOxygen.title;
    }
    if (t == 'body temperature' || t == 'temperature') {
      return PatientVitalType.temperature.title;
    }
    if (t == 'heart rate' || t == 'pulse rate' || t == 'pulse') {
      return PatientVitalType.heartRate.title;
    }
    if (t == 'respiratory rate') {
      return PatientVitalType.respiratoryRate.title;
    }
    if (t == 'systolic blood pressure') {
      return PatientVitalType.systolicBloodPressure.title;
    }
    if (t == 'diastolic blood pressure') {
      return PatientVitalType.diastolicBloodPressure.title;
    }
    if (t == 'blood pressure') {
      return PatientVitalType.bloodPressure.title;
    }
    if (t == 'blood glucose' || t == 'glucose') {
      return PatientVitalType.bloodGlucose.title;
    }
    return title;
  }

  List<PatientVital> _extractVitalSignsFromObservation(
      Observation observation) {
    final List<PatientVital> vitals = <PatientVital>[];

    final Set<String> primaryCodes = (observation.code?.coding ?? [])
        .where((c) => c.code != null)
        .map((c) => c.code.toString())
        .toSet();
    final bool isBloodPressurePanel =
        primaryCodes.contains('85354-9') || primaryCodes.contains('55284-4');

    if (isBloodPressurePanel && observation.component != null) {
      for (final component in observation.component!) {
        final compCodes = (component.code.coding ?? [])
            .where((c) => c.code != null)
            .map((c) => c.code.toString())
            .toSet();

        for (final code in compCodes) {
          if (code == '8480-6' || code == '8462-4') {
            final String title = code == '8480-6'
                ? 'Systolic Blood Pressure'
                : 'Diastolic Blood Pressure';

            String value = 'N/A';
            String unit = 'mmHg';
            final valueX = component.valueX;
            if (valueX is fhir_r4.Quantity) {
              value = valueX.value?.toString() ?? value;
              unit = valueX.unit?.toString() ?? unit;
            }

            vitals.add(
              PatientVital(
                title: title,
                value: value,
                unit: unit,
                status: FhirFieldExtractor.extractVitalSignStatus(observation),
                observationId: observation.id,
                effectiveDate: observation.date,
              ),
            );
          }
        }
      }
    } else {
      if (FhirFieldExtractor.isVitalSign(observation)) {
        final vital = PatientVital.fromObservation(observation);
        final processedVital = _processVitalSignStatus(vital);
        vitals.add(processedVital);
      }
    }

    return vitals;
  }

  void _combineBloodPressure(Map<String, PatientVital> latestByTitle) {
    final systolic =
        latestByTitle[PatientVitalType.systolicBloodPressure.title];
    final diastolic =
        latestByTitle[PatientVitalType.diastolicBloodPressure.title];

    if (systolic == null || diastolic == null) return;

    final sys = _parseBloodPressureValue(systolic.value);
    final dia = _parseBloodPressureValue(diastolic.value);
    if (sys == null || dia == null) return;

    final combinedStatus =
        _determineBloodPressureStatus(systolic, diastolic, sys, dia);
    final latestDate = _getLatestEffectiveDate(
        systolic.effectiveDate, diastolic.effectiveDate);

    final bp = PatientVital(
      title: PatientVitalType.bloodPressure.title,
      value: '$sys/$dia',
      unit: 'mmHg',
      status: combinedStatus,
      observationId: null,
      effectiveDate: latestDate,
    );

    _updateBloodPressureInMap(latestByTitle, bp);
  }

  int? _parseBloodPressureValue(String value) {
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  String? _determineBloodPressureStatus(
    PatientVital systolic,
    PatientVital diastolic,
    int sysValue,
    int diaValue,
  ) {
    final fhirStatus = _getFhirInterpretationStatus(systolic, diastolic);
    if (fhirStatus != null) return fhirStatus;

    return _calculateThresholdBasedStatus(sysValue, diaValue);
  }

  String? _getFhirInterpretationStatus(
      PatientVital systolic, PatientVital diastolic) {
    if (_isValidFhirStatus(systolic.status)) return systolic.status;

    if (_isValidFhirStatus(diastolic.status)) return diastolic.status;

    return null;
  }

  bool _isValidFhirStatus(String? status) {
    if (status == null || status.isEmpty) return false;

    const validStatuses = {
      'Normal',
      'High',
      'Low',
      'Abnormal',
      'Critically Abnormal',
      'Critically High',
      'Critically Low',
      'Uncertain',
      'Intermediate'
    };

    return validStatuses.contains(status);
  }

  String _calculateThresholdBasedStatus(int systolic, int diastolic) {
    if (systolic >= 140 || diastolic >= 90) return 'High';
    if (systolic >= 130 || diastolic >= 80) return 'Elevated';
    if (systolic >= 120 || diastolic >= 80) return 'Normal';
    return 'Optimal';
  }

  DateTime? _getLatestEffectiveDate(DateTime? date1, DateTime? date2) {
    if (date1 == null && date2 == null) return null;
    if (date1 == null) return date2;
    if (date2 == null) return date1;

    return date1.isAfter(date2) ? date1 : date2;
  }

  void _updateBloodPressureInMap(
      Map<String, PatientVital> latestByTitle, PatientVital bp) {
    latestByTitle
      ..remove(PatientVitalType.systolicBloodPressure.title)
      ..remove(PatientVitalType.diastolicBloodPressure.title)
      ..putIfAbsent(PatientVitalType.bloodPressure.title, () => bp)
      ..update(PatientVitalType.bloodPressure.title, (_) => bp,
          ifAbsent: () => bp);
  }

  PatientVital _processVitalSignStatus(PatientVital vital) {
    if (_isValidFhirStatus(vital.status)) {
      return vital;
    }

    final fallbackStatus = _calculateVitalSignStatus(vital);
    if (fallbackStatus != null) {
      return PatientVital(
        icon: vital.icon,
        title: vital.title,
        value: vital.value,
        unit: vital.unit,
        status: fallbackStatus,
        observationId: vital.observationId,
        effectiveDate: vital.effectiveDate,
      );
    }

    return vital;
  }

  static final _leadingNumberPattern = RegExp(r'^-?[\d.]+');

  String? _calculateVitalSignStatus(PatientVital vital) {
    final title = vital.title.toLowerCase();
    final numMatch = _leadingNumberPattern.firstMatch(vital.value.trim());
    final value = numMatch != null ? double.tryParse(numMatch.group(0)!) : null;

    if (value == null) return null;

    switch (title) {
      case 'heart rate':
        return _calculateHeartRateStatus(value);
      case 'temperature':
        return _calculateTemperatureStatus(value);
      case 'blood oxygen':
        return _calculateBloodOxygenStatus(value);
      case 'respiratory rate':
        return _calculateRespiratoryRateStatus(value);
      case 'blood glucose':
        return _calculateBloodGlucoseStatus(value);
      case 'weight':
        return _calculateWeightStatus(value);
      case 'height':
        return _calculateHeightStatus(value);
      case 'bmi':
        return _calculateBmiStatus(value);
      default:
        return null;
    }
  }

  String? _calculateHeartRateStatus(double value) {
    if (value < 60) return 'Low';
    if (value > 100) return 'High';
    return 'Normal';
  }

  String? _calculateTemperatureStatus(double value) {
    if (value < 95.0) return 'Low';
    if (value > 100.4) return 'High';
    return 'Normal';
  }

  String? _calculateBloodOxygenStatus(double value) {
    if (value < 90) return 'Low';
    if (value < 95) return 'Abnormal';
    return 'Normal';
  }

  String? _calculateRespiratoryRateStatus(double value) {
    if (value < 12) return 'Low';
    if (value > 20) return 'High';
    return 'Normal';
  }

  String? _calculateBloodGlucoseStatus(double value) {
    if (value < 70) return 'Low';
    if (value > 140) return 'High';
    if (value > 100) return 'Elevated';
    return 'Normal';
  }

  String? _calculateWeightStatus(double value) {
    return null;
  }

  String? _calculateHeightStatus(double value) {
    return null;
  }

  String? _calculateBmiStatus(double value) {
    if (value < 18.5) return 'Low';
    if (value >= 25 && value < 30) return 'Elevated';
    if (value >= 30) return 'High';
    return 'Normal';
  }
}
