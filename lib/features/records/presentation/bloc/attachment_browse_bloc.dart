import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/services/path_resolver.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:injectable/injectable.dart';

part 'attachment_browse_event.dart';
part 'attachment_browse_state.dart';
part 'attachment_browse_bloc.freezed.dart';

@injectable
class AttachmentBrowseBloc
    extends Bloc<AttachmentBrowseEvent, AttachmentBrowseState> {
  final RecordsRepository _recordsRepository;
  final PathResolver _pathResolver;

  AttachmentBrowseBloc(this._recordsRepository, this._pathResolver)
      : super(const AttachmentBrowseState()) {
    on<AttachmentBrowseInitialised>(_onInitialised);
    on<AttachmentBrowseSelected>(_onRecordSelected);
    on<AttachmentBrowseMonthSelected>(_onMonthSelected);
    on<AttachmentBrowseSearchChanged>(_onSearchChanged);
    on<AttachmentBrowseDetailRefreshed>(_onDetailRefreshed);
  }

  Future<void> _onInitialised(
    AttachmentBrowseInitialised event,
    Emitter<AttachmentBrowseState> emit,
  ) async {
    await _loadRecords(
      emit,
      sourceId: event.sourceId,
      sourceIds: event.sourceIds,
      resourceTypes: event.resourceTypes,
    );
  }

  Future<void> _loadRecords(
    Emitter<AttachmentBrowseState> emit, {
    String? sourceId,
    List<String>? sourceIds,
    List<FhirType> resourceTypes = const [],
  }) async {
    debugPrint('[BROWSE] _loadRecords sourceId=$sourceId, resourceTypes=$resourceTypes');
    emit(state.copyWith(status: AttachmentBrowseStatus.loading));

    try {
      final records = await _recordsRepository.getResources(
        resourceTypes: resourceTypes,
        sourceId: sourceId,
        sourceIds: sourceIds,
        limit: 1000,
        offset: 0,
      );
      debugPrint('[BROWSE] loaded ${records.length} records');

      records.sort((a, b) {
        final dateA = a.date;
        final dateB = b.date;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      final documentReferences = await _recordsRepository.getResources(
        resourceTypes: [FhirType.DocumentReference],
        sourceId: sourceId,
        sourceIds: sourceIds,
        limit: 2000,
        offset: 0,
      );
      debugPrint('[BROWSE] loaded ${documentReferences.length} DocumentReferences');

      final docsByEncounter = <String, List<IFhirResource>>{};
      final docsByRelated = <String, List<IFhirResource>>{};
      for (final doc in documentReferences) {
        final encId = doc.encounterId;
        if (encId.isNotEmpty) {
          docsByEncounter.putIfAbsent(encId, () => []).add(doc);
        }
        final related = doc.rawResource['context']?['related'] as List?;
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
      debugPrint('[BROWSE] docsByEncounter keys: ${docsByEncounter.keys.toList()}');
      debugPrint('[BROWSE] docsByRelated keys: ${docsByRelated.keys.toList()}');

      final entries = <AttachmentBrowseEntry>[];
      for (final record in records) {
        if (record.fhirType == FhirType.DocumentReference) continue;
        final docs = docsByEncounter[record.resourceId] ??
            docsByEncounter[record.encounterId] ??
            docsByRelated[record.resourceId] ??
            [];
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

      final timelineYears = _buildTimeline(entries);

      AttachmentBrowseDetail? detail;
      if (entries.isNotEmpty) {
        detail = await _loadDetail(entries[0].record, sourceId: sourceId);
      }

      emit(state.copyWith(
        status: AttachmentBrowseStatus.success,
        allRecords: entries,
        records: entries,
        selectedIndex: 0,
        selectedDetail: detail,
        timelineYears: timelineYears,
        searchQuery: '',
      ));
    } catch (_) {
      emit(state.copyWith(status: AttachmentBrowseStatus.error));
    }
  }

  Future<void> _onRecordSelected(
    AttachmentBrowseSelected event,
    Emitter<AttachmentBrowseState> emit,
  ) async {
    if (event.index < 0 || event.index >= state.records.length) return;

    emit(state.copyWith(selectedIndex: event.index));

    final entry = state.records[event.index];
    final detail = await _loadDetail(entry.record,
        sourceId: entry.record.sourceId);

    emit(state.copyWith(selectedDetail: detail));
  }

  Future<void> _onMonthSelected(
    AttachmentBrowseMonthSelected event,
    Emitter<AttachmentBrowseState> emit,
  ) async {
    for (final yearEntry in state.timelineYears) {
      if (yearEntry.year != event.year) continue;
      for (final monthEntry in yearEntry.months) {
        if (monthEntry.month != event.month) continue;

        final index = monthEntry.firstRecordIndex;
        if (index >= 0 && index < state.records.length) {
          emit(state.copyWith(selectedIndex: index));

          final entry = state.records[index];
          final detail = await _loadDetail(entry.record,
              sourceId: entry.record.sourceId);
          emit(state.copyWith(selectedDetail: detail));
        }
        return;
      }
    }
  }

  Future<void> _onSearchChanged(
    AttachmentBrowseSearchChanged event,
    Emitter<AttachmentBrowseState> emit,
  ) async {
    final query = event.query.trim().toLowerCase();
    emit(state.copyWith(searchQuery: query));

    if (query.isEmpty) {
      final entries = state.allRecords;
      final timelineYears = _buildTimeline(entries);
      AttachmentBrowseDetail? detail;
      if (entries.isNotEmpty) {
        detail = await _loadDetail(entries[0].record,
            sourceId: entries[0].record.sourceId);
      }
      emit(state.copyWith(
        records: entries,
        selectedIndex: 0,
        selectedDetail: detail,
        timelineYears: timelineYears,
      ));
      return;
    }

    final filtered = state.allRecords.where((entry) {
      return entry.record.title.toLowerCase().contains(query);
    }).toList();

    final timelineYears = _buildTimeline(filtered);
    AttachmentBrowseDetail? detail;
    if (filtered.isNotEmpty) {
      detail = await _loadDetail(filtered[0].record,
          sourceId: filtered[0].record.sourceId);
    }

    emit(state.copyWith(
      records: filtered,
      selectedIndex: 0,
      selectedDetail: detail,
      timelineYears: timelineYears,
    ));
  }

  Future<void> _onDetailRefreshed(
    AttachmentBrowseDetailRefreshed event,
    Emitter<AttachmentBrowseState> emit,
  ) async {
    final index = state.selectedIndex;
    if (index < 0 || index >= state.records.length) return;

    final entry = state.records[index];
    final detail =
        await _loadDetail(entry.record, sourceId: entry.record.sourceId);
    emit(state.copyWith(selectedDetail: detail));
  }

  Future<AttachmentBrowseDetail> _loadDetail(
    IFhirResource record, {
    String? sourceId,
  }) async {
    debugPrint('[DETAIL] _loadDetail record=${record.resourceId} type=${record.fhirType} sourceId=$sourceId');
    List<IFhirResource> related = [];
    try {
      final encId = record.fhirType == FhirType.Encounter
          ? record.resourceId
          : record.encounterId;
      debugPrint('[DETAIL] encId=$encId');
      if (encId.isNotEmpty) {
        related = await _recordsRepository.getRelatedResourcesForEncounter(
          encounterId: encId,
        );
      }
    } catch (_) {}
    debugPrint('[DETAIL] related resources: ${related.length} (types: ${related.map((r) => r.fhirType).toList()})');

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
            final docAttachments = await _resolveDocumentAttachments(resource);
            debugPrint('[DETAIL] encounter DocRef ${resource.resourceId}: ${docAttachments.length} files');
            attachments.addAll(docAttachments);
          default:
            break;
        }
      } catch (_) {}
    }
    debugPrint('[DETAIL] after encounter lookup: ${attachments.length} attachments');

    try {
      final existingIds = attachments.map((a) => a.id).toSet();
      final allDocs = await _recordsRepository.getResources(
        resourceTypes: [FhirType.DocumentReference],
        limit: 500,
      );
      debugPrint('[DETAIL] context.related search: ${allDocs.length} total DocRefs, existingIds=$existingIds');
      for (final doc in allDocs) {
        if (existingIds.contains(doc.resourceId)) continue;
        final relatedList =
            doc.rawResource['context']?['related'] as List?;
        if (relatedList == null) continue;
        final matches = relatedList.any((ref) {
          final refStr = ref['reference'] as String?;
          if (refStr == null) return false;
          final id = refStr.contains('/') ? refStr.split('/').last : refStr;
          return id == record.resourceId;
        });
        if (matches) {
          final docAttachments = await _resolveDocumentAttachments(doc);
          debugPrint('[DETAIL] related DocRef ${doc.resourceId}: ${docAttachments.length} files');
          attachments.addAll(docAttachments);
        }
      }
    } catch (_) {}
    debugPrint('[DETAIL] final attachments: ${attachments.length} (titles: ${attachments.map((a) => a.title).toList()})');

    if (patientName == null && organizationName == null && practitionerName == null) {
      _extractContextFromRecord(record, (p, o, pr) {
        patientName = p;
        organizationName = o;
        practitionerName = pr;
      });

      if (patientName == null) {
        final subjectRef = record.rawResource['subject']?['reference'] as String?;
        if (subjectRef != null) {
          try {
            final resolved = await _recordsRepository.resolveReference(subjectRef);
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
    );
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

  List<TimelineYear> _buildTimeline(List<AttachmentBrowseEntry> entries) {
    final yearMap = <int, Map<int, List<int>>>{};

    for (var i = 0; i < entries.length; i++) {
      final date = entries[i].record.date;
      if (date == null) continue;

      final year = date.year;
      final month = date.month;

      yearMap.putIfAbsent(year, () => {});
      yearMap[year]!.putIfAbsent(month, () => []);
      yearMap[year]![month]!.add(i);
    }

    final sortedYears = yearMap.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedYears.map((year) {
      final monthMap = yearMap[year]!;
      final sortedMonths = monthMap.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      final months = sortedMonths.map((month) {
        final indices = monthMap[month]!;
        return TimelineMonth(
          month: month,
          recordCount: indices.length,
          firstRecordIndex: indices.first,
        );
      }).toList();

      return TimelineYear(year: year, months: months);
    }).toList();
  }
}
