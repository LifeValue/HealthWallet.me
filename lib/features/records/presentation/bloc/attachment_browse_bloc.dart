import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/attachment_browse_service.dart';
import 'package:injectable/injectable.dart';

part 'attachment_browse_event.dart';
part 'attachment_browse_state.dart';
part 'attachment_browse_bloc.freezed.dart';

@injectable
class AttachmentBrowseBloc
    extends Bloc<AttachmentBrowseEvent, AttachmentBrowseState> {
  final AttachmentBrowseService _service;
  final SpecialtyClassifier _specialtyClassifier;

  AttachmentBrowseBloc(this._service, this._specialtyClassifier)
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
    final sourceRecords = event.sourceRecords.isNotEmpty
        ? event.sourceRecords
        : state.sourceRecords;
    emit(state.copyWith(
      status: AttachmentBrowseStatus.loading,
      readOnly: event.readOnly || state.readOnly,
      sourceRecords: sourceRecords,
    ));

    try {
      var entries = await _service.loadEntries(
        sourceId: event.sourceId,
        sourceIds: event.sourceIds,
        resourceTypes: event.resourceTypes,
      );

      if (event.specialty != null) {
        _specialtyClassifier.buildEncounterIndex(
            entries.map((e) => e.record).toList());
        entries = entries
            .where((e) {
              final override = MedicalSpecialty.values
                  .where((s) => s.name == e.record.specialtyOverride)
                  .firstOrNull;
              return _specialtyClassifier
                  .classify(e.record, override: override)
                  .contains(event.specialty);
            })
            .toList();
      }

      final timelineYears = _buildTimeline(entries);

      AttachmentBrowseDetail? detail;
      if (entries.isNotEmpty) {
        detail = await _service.loadDetail(
          entries[0].record,
          sourceId: event.sourceId,
        );
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
    final detail = await _service.loadDetail(
      entry.record,
      sourceId: entry.record.sourceId,
    );

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
          final detail = await _service.loadDetail(
            entry.record,
            sourceId: entry.record.sourceId,
          );
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
        detail = await _service.loadDetail(
          entries[0].record,
          sourceId: entries[0].record.sourceId,
        );
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
      detail = await _service.loadDetail(
        filtered[0].record,
        sourceId: filtered[0].record.sourceId,
      );
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
        await _service.loadDetail(entry.record, sourceId: entry.record.sourceId);

    final updatedEntry = AttachmentBrowseEntry(
      record: entry.record,
      thumbnailPath: detail.attachments.isNotEmpty
          ? detail.attachments.first.filePath
          : null,
    );

    final updatedRecords = List<AttachmentBrowseEntry>.from(state.records);
    updatedRecords[index] = updatedEntry;
    final updatedAll = List<AttachmentBrowseEntry>.from(state.allRecords);
    final allIndex = updatedAll.indexWhere((e) => e.record.id == entry.record.id);
    if (allIndex >= 0) updatedAll[allIndex] = updatedEntry;

    emit(state.copyWith(
      selectedDetail: detail,
      records: updatedRecords,
      allRecords: updatedAll,
    ));
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
