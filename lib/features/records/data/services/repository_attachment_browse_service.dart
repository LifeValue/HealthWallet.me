import 'dart:io';

import 'package:injectable/injectable.dart';

import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/services/attachment_browse_service.dart';

@Injectable(as: AttachmentBrowseService)
class RepositoryAttachmentBrowseService implements AttachmentBrowseService {
  final RecordsRepository _repository;
  final PathResolver _pathResolver;
  final SpecialtyClassifier _specialtyClassifier;

  RepositoryAttachmentBrowseService(this._repository, this._pathResolver, this._specialtyClassifier);

  @override
  Future<List<AttachmentBrowseEntry>> loadEntries({
    String? sourceId,
    List<String>? sourceIds,
    List<FhirType> resourceTypes = const [],
  }) async {
    final records = await _repository.getResources(
      resourceTypes: resourceTypes,
      sourceId: sourceId,
      sourceIds: sourceIds,
      limit: 1000,
      offset: 0,
    );

    records.sort((a, b) {
      final dateA = a.date;
      final dateB = b.date;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    final documentReferences = await _repository.getResources(
      resourceTypes: [FhirType.DocumentReference],
      sourceId: sourceId,
      sourceIds: sourceIds,
      limit: 2000,
      offset: 0,
    );

    final docsByEncounter = <String, List<IFhirResource>>{};
    final docsByRelated = <String, List<IFhirResource>>{};
    for (final doc in documentReferences) {
      final encId = doc.encounterId;
      if (encId.isNotEmpty) {
        docsByEncounter.putIfAbsent(encId, () => []).add(doc);
      }
      final ctx = doc.rawResource['context'];
      if (ctx != null) {
        final encounters = ctx['encounter'] as List?;
        if (encounters != null) {
          for (final enc in encounters) {
            final refStr = enc['reference'] as String?;
            if (refStr != null) {
              final id = refStr.contains('/') ? refStr.split('/').last : refStr;
              docsByEncounter.putIfAbsent(id, () => []).add(doc);
            }
          }
        }
        final related = ctx['related'] as List?;
        if (related != null) {
          for (final ref in related) {
            final refStr = ref['reference'] as String?;
            if (refStr != null) {
              final id = refStr.contains('/') ? refStr.split('/').last : refStr;
              docsByRelated.putIfAbsent(id, () => []).add(doc);
            }
          }
        }
      }
    }

    final entries = <AttachmentBrowseEntry>[];
    for (final record in records) {
      if (FhirType.supportingTypes.contains(record.fhirType)) continue;
      List<IFhirResource> docs = [];
      if (FhirType.mainRecordTypes.contains(record.fhirType)) {
        final directDocs = docsByRelated[record.resourceId] ?? [];
        final encounterDocs = record.fhirType == FhirType.Encounter
            ? (docsByEncounter[record.resourceId] ?? [])
                .where((d) => _hasNoRelatedRef(d) ||
                    _relatedRefPointsTo(d, record.resourceId))
                .toList()
            : <IFhirResource>[];
        final seen = <String>{};
        docs = [...directDocs, ...encounterDocs]
            .where((d) => seen.add(d.resourceId))
            .toList();
      }
      String? thumbnailPath;

      for (final doc in docs) {
        final content = doc.rawResource['content'] as List<dynamic>?;
        if (content == null || content.isEmpty) continue;

        for (final item in content) {
          final attachment = item['attachment'] as Map<String, dynamic>?;
          if (attachment == null) continue;

          final contentType = attachment['contentType'] as String?;
          if (contentType != null &&
              (contentType.startsWith('image/') ||
                  contentType == 'application/pdf')) {
            final url = attachment['url'] as String?;
            if (url != null && url.isNotEmpty) {
              final rawPath = Uri.decodeComponent(
                  url.startsWith('file://') ? url.substring(7) : url);
              try {
                final resolved = await _pathResolver.toAbsolute(rawPath);
                if (await File(resolved).exists()) {
                  thumbnailPath = resolved;
                }
              } catch (_) {}
            }
          }
          if (thumbnailPath != null) break;
        }
        if (thumbnailPath != null) break;
      }

      entries.add(AttachmentBrowseEntry(
        record: record,
        thumbnailPath: thumbnailPath,
        attachmentCount: docs.length,
      ));
    }

    return entries;
  }

  @override
  Future<AttachmentBrowseDetail> loadDetail(
    IFhirResource record, {
    String? sourceId,
  }) async {
    List<IFhirResource> related = [];
    try {
      final encId = record.fhirType == FhirType.Encounter
          ? record.resourceId
          : record.encounterId;
      if (encId.isNotEmpty) {
        related = await _repository.getRelatedResourcesForEncounter(
          encounterId: encId,
        );
      }
    } catch (_) {}

    String? patientName;
    String? organizationName;
    String? practitionerName;
    final String? specialtyName = _extractSpecialtyName(record.rawResource) ?? _classifySpecialtyName(record);
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
            if (_isDocDirectlyLinked(resource, record)) {
              final docAttachments =
                  await _resolveDocumentAttachments(resource);
              attachments.addAll(docAttachments);
            }
          default:
            break;
        }
      } catch (_) {}
    }

    try {
      final existingIds = attachments.map((a) => a.id).toSet();
      final allDocs = await _repository.getResources(
        resourceTypes: [FhirType.DocumentReference],
        limit: 500,
      );
      for (final doc in allDocs) {
        if (existingIds.contains(doc.resourceId)) continue;
        if (!_isDocDirectlyLinked(doc, record)) continue;
        final docAttachments = await _resolveDocumentAttachments(doc);
        attachments.addAll(docAttachments);
      }
    } catch (_) {}

    if (patientName == null &&
        organizationName == null &&
        practitionerName == null) {
      _extractContextFromRecord(record, (p, o, pr) {
        patientName = p;
        organizationName = o;
        practitionerName = pr;
      });

      if (patientName == null) {
        final subjectRef =
            record.rawResource['subject']?['reference'] as String?;
        if (subjectRef != null) {
          try {
            final resolved =
                await _repository.resolveReference(subjectRef);
            if (resolved != null) {
              patientName = _extractPersonName(resolved.rawResource);
            }
          } catch (_) {}
        }
      }
    }

    return AttachmentBrowseDetail(
      record: record,
      attachments: attachments,
      patientName: patientName,
      organizationName: organizationName,
      practitionerName: practitionerName,
      specialtyName: specialtyName,
    );
  }

  bool _isDocDirectlyLinked(IFhirResource doc, IFhirResource record) {
    final relatedList = doc.rawResource['context']?['related'] as List?;

    if (record.fhirType == FhirType.Encounter &&
        doc.encounterId == record.resourceId) {
      return _hasNoRelatedRef(doc) ||
          _relatedRefPointsTo(doc, record.resourceId);
    }

    if (relatedList != null) {
      for (final ref in relatedList) {
        final refStr = ref['reference'] as String?;
        if (refStr == null) continue;
        final id = refStr.contains('/') ? refStr.split('/').last : refStr;
        if (id == record.resourceId) return true;
      }
    }

    return false;
  }

  bool _hasNoRelatedRef(IFhirResource doc) {
    final related = doc.rawResource['context']?['related'] as List?;
    return related == null || related.isEmpty;
  }

  bool _relatedRefPointsTo(IFhirResource doc, String resourceId) {
    final related = doc.rawResource['context']?['related'] as List?;
    if (related == null) return false;
    for (final ref in related) {
      final refStr = ref['reference'] as String?;
      if (refStr == null) continue;
      final id = refStr.contains('/') ? refStr.split('/').last : refStr;
      if (id == resourceId) return true;
    }
    return false;
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

  Future<List<AttachmentBrowseFile>> _resolveDocumentAttachments(
    IFhirResource docRef,
  ) async {
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
          final absolute = await _pathResolver.toAbsolute(rawPath);
          if (await File(absolute).exists()) {
            resolvedPath = absolute;
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
}
