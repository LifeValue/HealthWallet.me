import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/attachment_browse_service.dart';
import 'package:health_wallet/features/records/domain/services/fhir_resource_relationship_service.dart';

class EphemeralAttachmentBrowseService implements AttachmentBrowseService {
  final List<IFhirResource> _records;
  final SpecialtyClassifier _specialtyClassifier;

  EphemeralAttachmentBrowseService(this._records, this._specialtyClassifier);

  @override
  Future<List<AttachmentBrowseEntry>> loadEntries({
    String? sourceId,
    List<String>? sourceIds,
    List<FhirType> resourceTypes = const [],
  }) async {
    debugPrint('[EPHEMERAL_BROWSE] loadEntries resourceTypes=$resourceTypes, records=${_records.length}');

    var filtered = _records.toList();
    if (resourceTypes.isNotEmpty) {
      filtered = filtered.where((r) => resourceTypes.contains(r.fhirType)).toList();
    }

    filtered.sort((a, b) {
      final dateA = a.date;
      final dateB = b.date;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    final entries = <AttachmentBrowseEntry>[];
    for (final record in filtered) {
      if (record.fhirType == FhirType.DocumentReference) continue;

      final related = FhirResourceRelationshipService.findRelatedInMemory(
        resource: record,
        allRecords: _records,
      );
      final docs = related
          .where((r) => r.fhirType == FhirType.DocumentReference)
          .toList();
      debugPrint('[EPHEMERAL_BROWSE] record=${record.resourceId} type=${record.fhirType} related=${related.length} docs=${docs.length}');

      String? thumbnailPath;
      for (final doc in docs) {
        final content = doc.rawResource['content'] as List<dynamic>?;
        debugPrint('[EPHEMERAL_BROWSE]   doc=${doc.resourceId} contentItems=${content?.length}');
        if (content == null || content.isEmpty) continue;

        for (final item in content) {
          final attachment = item['attachment'] as Map<String, dynamic>?;
          if (attachment == null) continue;

          final contentType = attachment['contentType'] as String?;
          final url = attachment['url'] as String?;
          debugPrint('[EPHEMERAL_BROWSE]   contentType=$contentType url=$url');
          if (contentType != null &&
              (contentType.startsWith('image/') ||
                  contentType == 'application/pdf')) {
            if (url != null && url.isNotEmpty) {
              final rawPath = Uri.decodeComponent(
                  url.startsWith('file://') ? url.substring(7) : url);
              final exists = File(rawPath).existsSync();
              debugPrint('[EPHEMERAL_BROWSE]   rawPath=$rawPath exists=$exists');
              if (exists) {
                thumbnailPath = rawPath;
              }
            }
          }
          if (thumbnailPath != null) break;
        }
        if (thumbnailPath != null) break;
      }

      debugPrint('[EPHEMERAL_BROWSE]   thumbnailPath=$thumbnailPath');
      entries.add(AttachmentBrowseEntry(
        record: record,
        thumbnailPath: thumbnailPath,
        attachmentCount: docs.length,
      ));
    }

    debugPrint('[EPHEMERAL_BROWSE] built ${entries.length} entries');
    return entries;
  }

  @override
  Future<AttachmentBrowseDetail> loadDetail(
    IFhirResource record, {
    String? sourceId,
  }) async {
    debugPrint('[EPHEMERAL_DETAIL] loadDetail record=${record.resourceId} type=${record.fhirType}');

    final related = FhirResourceRelationshipService.findRelatedInMemory(
      resource: record,
      allRecords: _records,
    );
    debugPrint('[EPHEMERAL_DETAIL] related resources: ${related.length} (types: ${related.map((r) => r.fhirType).toList()})');

    String? patientName;
    String? organizationName;
    String? practitionerName;
    final attachments = <AttachmentBrowseFile>[];

    for (final resource in related) {
      try {
        switch (resource.fhirType) {
          case FhirType.Patient:
            patientName = _extractPersonName(resource.rawResource);
          case FhirType.Organization:
            final name = resource.rawResource['name'];
            if (name is String) {
              organizationName = name;
            } else if (name is List && name.isNotEmpty) {
              organizationName = name[0].toString();
            }
          case FhirType.Practitioner:
            practitionerName = _extractPersonName(resource.rawResource);
          case FhirType.DocumentReference:
            final docAttachments = _resolveDocumentAttachments(resource);
            debugPrint('[EPHEMERAL_DETAIL] encounter DocRef ${resource.resourceId}: ${docAttachments.length} files');
            attachments.addAll(docAttachments);
          default:
            break;
        }
      } catch (_) {}
    }
    debugPrint('[EPHEMERAL_DETAIL] after encounter lookup: ${attachments.length} attachments');

    try {
      final existingIds = attachments.map((a) => a.id).toSet();
      final allDocs = _records
          .where((r) => r.fhirType == FhirType.DocumentReference)
          .toList();
      debugPrint('[EPHEMERAL_DETAIL] context.related search: ${allDocs.length} total DocRefs, existingIds=$existingIds');

      for (final doc in allDocs) {
        if (existingIds.contains(doc.resourceId)) continue;
        final relatedList = doc.rawResource['context']?['related'] as List?;
        if (relatedList == null) continue;
        final matches = relatedList.any((ref) {
          final refStr = ref['reference'] as String?;
          if (refStr == null) return false;
          final id = refStr.contains('/') ? refStr.split('/').last : refStr;
          return id == record.resourceId;
        });
        if (matches) {
          final docAttachments = _resolveDocumentAttachments(doc);
          debugPrint('[EPHEMERAL_DETAIL] related DocRef ${doc.resourceId}: ${docAttachments.length} files');
          attachments.addAll(docAttachments);
        }
      }
    } catch (_) {}
    debugPrint('[EPHEMERAL_DETAIL] final attachments: ${attachments.length} (titles: ${attachments.map((a) => a.title).toList()})');

    if (patientName == null && organizationName == null && practitionerName == null) {
      _extractContextFromRecord(record, (p, o, pr) {
        patientName = p;
        organizationName = o;
        practitionerName = pr;
      });

      if (patientName == null) {
        final subjectRef = record.rawResource['subject']?['reference'] as String?;
        if (subjectRef != null) {
          final refId = subjectRef.contains('/') ? subjectRef.split('/').last : subjectRef;
          final resolved = _records
              .where((r) => r.resourceId == refId && r.fhirType == FhirType.Patient)
              .firstOrNull;
          if (resolved != null) {
            patientName = _extractPersonName(resolved.rawResource);
          }
        }
      }
    }

    return AttachmentBrowseDetail(
      record: record,
      attachments: attachments,
      patientName: patientName,
      organizationName: organizationName,
      practitionerName: practitionerName,
      specialtyName: _extractSpecialtyName(record.rawResource) ?? _classifySpecialtyName(record),
    );
  }

  static const _specialtySystem = 'http://healthwallet.me/specialty';

  String? _classifySpecialtyName(IFhirResource record) {
    final specialties = _specialtyClassifier.classify(record);
    final specialty = specialties.firstOrNull;
    if (specialty == null) return null;
    return specialty.displayName;
  }

  String? _extractSpecialtyName(Map<String, dynamic> rawResource) {
    try {
      final tags = rawResource['meta']?['tag'] as List?;
      if (tags == null) return null;
      for (final tag in tags) {
        if (tag is Map && tag['system'] == _specialtySystem) {
          return tag['display'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  List<AttachmentBrowseFile> _resolveDocumentAttachments(IFhirResource docRef) {
    final result = <AttachmentBrowseFile>[];
    final content = docRef.rawResource['content'] as List<dynamic>?;
    if (content == null) return result;

    for (final item in content) {
      final attachment = item['attachment'] as Map<String, dynamic>?;
      if (attachment == null) continue;

      final contentType = attachment['contentType'] as String?;
      final url = attachment['url'] as String?;
      String? resolvedPath;

      if (url != null && url.isNotEmpty) {
        final rawPath = Uri.decodeComponent(
            url.startsWith('file://') ? url.substring(7) : url);
        try {
          if (File(rawPath).existsSync()) {
            resolvedPath = rawPath;
          }
        } catch (_) {}
      }

      result.add(AttachmentBrowseFile(
        id: docRef.resourceId,
        resource: docRef,
        title: docRef.title,
        filePath: resolvedPath,
        contentType: contentType,
      ));
    }

    return result;
  }

  String? _extractPersonName(Map<String, dynamic> rawResource) {
    try {
      final name = rawResource['name'];
      if (name is String) return name;
      if (name is! List || name.isEmpty) return null;

      final nameObj = name[0];
      if (nameObj is! Map<String, dynamic>) return nameObj?.toString();

      final givenList = nameObj['given'] as List<dynamic>?;
      final family = nameObj['family'] as String?;

      final given =
          (givenList != null && givenList.isNotEmpty) ? givenList[0] : null;

      if (given != null && family != null) return '$given $family';
      if (given != null) return given.toString();
      if (family != null) return family;
    } catch (_) {}
    return null;
  }

  void _extractContextFromRecord(
    IFhirResource record,
    void Function(String? patient, String? org, String? practitioner) callback,
  ) {
    try {
      final raw = record.rawResource;

      String? patient;
      final subjectDisplay = raw['subject']?['display'] as String?;
      if (subjectDisplay != null && subjectDisplay.isNotEmpty) {
        patient = subjectDisplay;
      }

      String? org;
      final performer = raw['performer'] as List?;
      if (performer != null) {
        for (final p in performer) {
          final display = p['display'] as String?;
          if (display != null) {
            org ??= display;
          }
        }
      }

      String? practitioner;
      final participant = raw['participant'] as List?;
      if (participant != null) {
        for (final p in participant) {
          final individual = p['individual'];
          if (individual != null) {
            final display = individual['display'] as String?;
            if (display != null) {
              practitioner ??= display;
            }
          }
        }
      }

      callback(patient, org, practitioner);
    } catch (_) {}
  }
}
