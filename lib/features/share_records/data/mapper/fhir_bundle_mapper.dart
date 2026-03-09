import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';

class FhirBundleMapper {
  static const _uuid = Uuid();

  static Future<SharePayload> toSharePayload({
    required List<IFhirResource> records,
    required String deviceName,
    int expiresInSeconds = 300,
    Map<String, List<RecordNote>> notesMap = const {},
    List<String> activeFilters = const [],
  }) async {
    final entries = <Map<String, dynamic>>[];

    for (final resource in records) {
      final rawResource =
          Map<String, dynamic>.from(resource.rawResource as Map);

      await _embedAttachmentData(rawResource);

      final entry = <String, dynamic>{
        'resource': rawResource,
        '_resourceId': resource.resourceId,
      };

      final notes = notesMap[resource.id];
      if (notes != null && notes.isNotEmpty) {
        entry['_notes'] = notes.map((n) => n.toMap()).toList();
      }

      entries.add(entry);
    }

    return SharePayload(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      senderDeviceName: deviceName,
      expiresInSeconds: expiresInSeconds,
      bundle: SharePayloadBundle(
        entry: entries,
        lastUpdated: DateTime.now(),
      ),
      isViewOnly: true,
      activeFilters: activeFilters,
    );
  }

  static Future<void> _embedAttachmentData(
      Map<String, dynamic> rawResource) async {
    if (rawResource['resourceType'] != 'DocumentReference') return;

    final content = rawResource['content'] as List?;
    if (content == null) return;

    for (final item in content) {
      final attachment = item['attachment'] as Map<String, dynamic>?;
      final url = attachment?['url'] as String?;
      if (url != null && url.startsWith('file://')) {
        final resolvedFile = await _resolveFile(url.substring(7));
        if (resolvedFile != null) {
          final bytes = await resolvedFile.readAsBytes();
          attachment!['data'] = base64Encode(bytes);
          attachment.remove('url');
        }
      }
    }
  }

  static Future<File?> _resolveFile(String storedPath) async {
    final file = File(storedPath);
    if (await file.exists()) return file;

    final match = RegExp(r'/Application/[^/]+/(.+)').firstMatch(storedPath);
    if (match == null) return null;

    final relativePath = match.group(1)!;
    final fileName = storedPath.split('/').last;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final containerBase = docsDir.parent.path;

      final resolvedByRelative = File('$containerBase/$relativePath');
      if (await resolvedByRelative.exists()) return resolvedByRelative;

      for (final dir in [
        docsDir.path,
        '$containerBase/Library/Caches',
        '$containerBase/tmp',
      ]) {
        final candidate = File('$dir/$fileName');
        if (await candidate.exists()) return candidate;
      }
    } catch (_) {}

    return null;
  }

  static Future<ParseBundleResult> parseBundle(
    SharePayloadBundle bundle, {
    String? tempDir,
  }) async {
    final resources = <IFhirResource>[];
    final notesMap = <String, List<RecordNote>>{};
    final tempFilePaths = <String>[];

    for (final entry in bundle.entry) {
      final resourceJson = entry['resource'] as Map<String, dynamic>?;
      if (resourceJson == null) continue;

      try {
        final resourceType = resourceJson['resourceType'] as String?;
        if (resourceType == null) continue;

        final resourceId = entry['_resourceId']?.toString() ??
            resourceJson['id']?.toString() ??
            _uuid.v4();

        await _restoreAttachmentFiles(
          resourceJson,
          resourceType,
          tempDir,
          tempFilePaths,
        );

        final newId = _uuid.v4();

        final dto = FhirResourceLocalDto(
          id: newId,
          sourceId: 'shared',
          resourceType: resourceType,
          resourceId: resourceId,
          title: _extractTitle(resourceJson, resourceType),
          date: _extractDate(resourceJson, resourceType),
          resourceRaw: jsonEncode(resourceJson),
          encounterId: _extractEncounterIdFromJson(resourceJson),
          subjectId: _extractReferenceId(resourceJson, 'subject'),
        );

        resources.add(IFhirResource.fromLocalDto(dto));

        final rawNotes = entry['_notes'] as List?;
        if (rawNotes != null && rawNotes.isNotEmpty) {
          notesMap[newId] = rawNotes
              .map((n) => RecordNote.fromMap(n as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('[ERROR] Failed to parse resource: $e');
        continue;
      }
    }

    return ParseBundleResult(
      resources: resources,
      notes: notesMap,
      tempFilePaths: tempFilePaths,
    );
  }

  static Future<void> _restoreAttachmentFiles(
    Map<String, dynamic> resourceJson,
    String resourceType,
    String? tempDir,
    List<String> tempFilePaths,
  ) async {
    if (resourceType != 'DocumentReference' || tempDir == null) return;

    final content = resourceJson['content'] as List?;
    if (content == null) return;

    for (final item in content) {
      final attachment = item['attachment'] as Map<String, dynamic>?;
      final data = attachment?['data'] as String?;
      if (data != null) {
        final bytes = base64Decode(data);
        final title = attachment?['title'] as String? ?? '${_uuid.v4()}.bin';
        final sanitized = title.replaceAll(RegExp(r'[^\w.\-]'), '_');
        final tempFile = File('$tempDir/$sanitized');
        await tempFile.writeAsBytes(bytes);
        tempFilePaths.add(tempFile.path);
        attachment!['url'] = 'file://${tempFile.path}';
        attachment.remove('data');
      }
    }
  }

  static String _extractTitle(
      Map<String, dynamic> json, String resourceType) {
    switch (resourceType) {
      case 'Encounter':
        final type = json['type'] as List?;
        if (type != null && type.isNotEmpty) {
          final coding = type[0]['coding'] as List?;
          if (coding != null && coding.isNotEmpty) {
            return coding[0]['display']?.toString() ?? 'Encounter';
          }
        }
        return 'Encounter';
      case 'Observation':
        final code = json['code']?['coding'] as List?;
        if (code != null && code.isNotEmpty) {
          return code[0]['display']?.toString() ?? 'Observation';
        }
        return 'Observation';
      case 'Condition':
        final code = json['code']?['coding'] as List?;
        if (code != null && code.isNotEmpty) {
          return code[0]['display']?.toString() ?? 'Condition';
        }
        return 'Condition';
      case 'Procedure':
        final code = json['code']?['coding'] as List?;
        if (code != null && code.isNotEmpty) {
          return code[0]['display']?.toString() ?? 'Procedure';
        }
        return 'Procedure';
      case 'Immunization':
        final code = json['vaccineCode']?['coding'] as List?;
        if (code != null && code.isNotEmpty) {
          return code[0]['display']?.toString() ?? 'Immunization';
        }
        return 'Immunization';
      case 'MedicationRequest':
        final med = json['medicationCodeableConcept']?['coding'] as List?;
        if (med != null && med.isNotEmpty) {
          return med[0]['display']?.toString() ?? 'Medication Request';
        }
        return 'Medication Request';
      case 'DiagnosticReport':
        final code = json['code']?['coding'] as List?;
        if (code != null && code.isNotEmpty) {
          return code[0]['display']?.toString() ?? 'Diagnostic Report';
        }
        return 'Diagnostic Report';
      default:
        return resourceType;
    }
  }

  static DateTime? _extractDate(
      Map<String, dynamic> json, String resourceType) {
    String? dateString;

    switch (resourceType) {
      case 'Encounter':
        dateString = json['period']?['start']?.toString();
        break;
      case 'Observation':
        dateString = json['effectiveDateTime']?.toString() ??
            json['issued']?.toString();
        break;
      case 'Condition':
        dateString = json['onsetDateTime']?.toString() ??
            json['recordedDate']?.toString();
        break;
      case 'Procedure':
        dateString = json['performedDateTime']?.toString() ??
            json['performedPeriod']?['start']?.toString();
        break;
      case 'Immunization':
        dateString = json['occurrenceDateTime']?.toString();
        break;
      case 'MedicationRequest':
        dateString = json['authoredOn']?.toString();
        break;
      case 'DiagnosticReport':
        dateString = json['effectiveDateTime']?.toString() ??
            json['issued']?.toString();
        break;
      default:
        dateString = json['date']?.toString() ??
            json['issued']?.toString() ??
            json['recordedDate']?.toString();
    }

    if (dateString == null) return null;

    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  static String? _parseReferenceString(String? ref) {
    if (ref == null) return null;
    if (ref.contains('/')) return ref.split('/').last;
    if (ref.startsWith('urn:uuid:')) return ref.replaceFirst('urn:uuid:', '');
    if (ref.startsWith('#')) return ref.substring(1);
    return ref;
  }

  static String? _extractEncounterIdFromJson(Map<String, dynamic> json) {
    final directEncounter = _extractReferenceId(json, 'encounter');
    if (directEncounter != null) return directEncounter;

    final context = json['context'] as Map<String, dynamic>?;
    if (context == null) return null;

    final contextEncounter = context['encounter'] as List?;
    if (contextEncounter != null && contextEncounter.isNotEmpty) {
      return _parseReferenceString(
          contextEncounter[0]['reference']?.toString());
    }

    return _extractReferenceId(context, 'encounter');
  }

  static String? _extractReferenceId(
      Map<String, dynamic> json, String fieldName) {
    return _parseReferenceString(json[fieldName]?['reference']?.toString());
  }

  static int estimatePayloadSize(List<IFhirResource> records) {
    int totalSize = 0;
    for (final record in records) {
      totalSize += record.rawResource.toString().length;
    }
    return totalSize + 500;
  }
}

class ParseBundleResult {
  final List<IFhirResource> resources;
  final Map<String, List<RecordNote>> notes;
  final List<String> tempFilePaths;

  const ParseBundleResult({
    required this.resources,
    required this.notes,
    required this.tempFilePaths,
  });
}
