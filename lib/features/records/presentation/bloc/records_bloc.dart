import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/services/temp_file_sweeper.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/services/records_filter_store.dart';
import 'package:health_wallet/features/records/domain/services/specialty_matcher.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'records_bloc.freezed.dart';
part 'records_event.dart';
part 'records_state.dart';

@injectable
class RecordsBloc extends Bloc<RecordsEvent, RecordsState> {
  final RecordsRepository _recordsRepository;
  final SpecialtyClassifier _specialtyClassifier;
  RecordsRepository get recordsRepository => _recordsRepository;
  Timer? _searchDebounceTimer;

  /// Counts loads; a load whose number is no longer the latest drops its
  /// result, so an earlier, slower load can't replace a newer one.
  int _loadGeneration = 0;

  /// Where the next page starts, in stored rows (see [ResourcePage]).
  int _nextOffset = 0;

  /// The specialty filter of the current list, kept for its next pages.
  SpecialtyMatcher? _specialtyMatcher;

  /// Keeps each person's chosen filters; without it (tests, previews) the
  /// filters last only as long as this bloc.
  final RecordsFilterStore? _filterStore;

  /// The person whose filters are shown and saved, or null in a share.
  String? _personId;

  /// Whether the filters shown were set by a Home card for this visit only,
  /// so the person's own come back when Records is left.
  bool _visitOnly = false;
  String? _lastIpsPdfPath;

  static const _pageSize = 20;
  static const _searchLimit = 100;
  static const _minSearchLength = 2;

  RecordsBloc(
    this._recordsRepository,
    this._specialtyClassifier, [
    this._filterStore,
  ]) : super(const RecordsState()) {
    // A newer event of the same kind replaces one still loading; across
    // kinds, _loadResources keeps only the latest load's records.
    on<RecordsInitialised>(_onInitialised, transformer: restartable());
    // A page asked for again while it loads would be listed twice.
    on<RecordsLoadMore>(_onLoadMore, transformer: droppable());
    on<RecordsSourceChanged>(_onSourceChanged, transformer: restartable());
    on<RecordsFiltersApplied>(_onFiltersApplied, transformer: restartable());
    on<RecordsFilterRemoved>(_onFilterRemoved, transformer: restartable());
    on<RecordDetailLoaded>(_onRecordDetailLoaded, transformer: restartable());
    on<RecordsSearch>(_onSearch, transformer: restartable());
    on<RecordsSearchExecuted>(_onSearchExecuted, transformer: restartable());
    on<RecordsSharePressed>(_onRecordsSharePressed, transformer: droppable());
    on<RecordsSelectionToggled>(
      _onSelectionToggled,
      transformer: sequential(),
    );
    on<RecordsSelectionCleared>(
      _onSelectionCleared,
      transformer: sequential(),
    );
    on<RecordsSelectionModeToggled>(
      _onSelectionModeToggled,
      transformer: sequential(),
    );
    on<RecordsDateRangeCleared>(
      _onDateRangeCleared,
      transformer: restartable(),
    );
    // Every deletion asked for is made, one after the other.
    on<RecordsResourceDeleted>(_onResourceDeleted, transformer: sequential());
    on<RecordsSpecialtyApplied>(
      _onSpecialtyApplied,
      transformer: restartable(),
    );
    on<RecordsRefreshRequested>(
      _onRefreshRequested,
      transformer: restartable(),
    );
    on<RecordsClearAllFilters>(
      _onClearAllFilters,
      transformer: restartable(),
    );
    // One leave at a time: the next waits for the reload the last started.
    on<RecordsVisitEnded>(_onVisitEnded, transformer: sequential());
  }

  @override
  Future<void> close() {
    _searchDebounceTimer?.cancel();
    return super.close();
  }

  bool get _isSearching => state.searchQuery.length >= _minSearchLength;

  /// Loads the first page of the current scope, filters and search, or with
  /// [more] the next page, shown below the list while it loads.
  Future<void> _loadResources(
    Emitter<RecordsState> emit, {
    bool more = false,
  }) async {
    final generation = ++_loadGeneration;
    bool isLatest() => generation == _loadGeneration && !emit.isDone;

    emit(
      more
          ? state.copyWith(isLoadingMore: true)
          : state.copyWith(
              status: const RecordsStatus.loading(),
              isLoadingMore: false,
            ),
    );
    try {
      // One source, or the selected patient's sources; every query uses the
      // same scope.
      final sourceId = state.sourceId;
      final sourceIds = sourceId == null ? state.sourceIds : null;

      if (!more) {
        _specialtyMatcher = null;
        if (state.activeSpecialties.isNotEmpty) {
          final encounters = await _recordsRepository.getResourcePage(
            resourceTypes: [FhirType.Encounter],
            sourceId: sourceId,
            sourceIds: sourceIds,
            limit: null,
          );
          if (!isLatest()) return;
          _specialtyMatcher = SpecialtyMatcher(
            _specialtyClassifier,
            state.activeSpecialties,
            encounters.resources,
          );
        }
      }

      if (_isSearching) {
        final found = await _recordsRepository.searchResources(
          query: state.searchQuery,
          resourceTypes: state.activeFilters,
          sourceId: sourceId,
          sourceIds: sourceIds,
          dateFilter: state.dateFilter,
          where: _specialtyMatcher?.matches,
          limit: _searchLimit,
        );
        if (!isLatest()) return;
        emit(
          state.copyWith(
            status: const RecordsStatus.success(),
            resources: found,
            hasMorePages: false,
            isLoadingMore: false,
          ),
        );
        return;
      }

      final page = await _recordsRepository.getResourcePage(
        resourceTypes: state.activeFilters,
        sourceId: sourceId,
        sourceIds: sourceIds,
        dateFilter: state.dateFilter,
        where: _specialtyMatcher?.matches,
        limit: _pageSize,
        offset: more ? _nextOffset : 0,
      );
      if (!isLatest()) return;

      _nextOffset = page.nextOffset;
      emit(
        state.copyWith(
          status: const RecordsStatus.success(),
          resources: more
              ? [...state.resources, ...page.resources]
              : page.resources,
          hasMorePages: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e, s) {
      if (!isLatest()) return;
      logger.e('Loading records failed', e, s);
      emit(
        state.copyWith(status: RecordsStatus.failure(e), isLoadingMore: false),
      );
    }
  }

  /// Keeps the filters now shown for this person, for their next visit.
  Future<void> _saveFilters() async {
    final personId = _personId;
    final store = _filterStore;
    if (personId == null || store == null) return;
    await store.save(
      personId,
      RecordsFilters(
        types: state.activeFilters,
        specialties: state.activeSpecialties,
        dateFilter: state.dateFilter,
      ),
    );
  }

  /// [from] with [personId]'s own filters, or none, when they are not the
  /// person shown; the app adds no filters itself. A new person ends a
  /// visit a Home card filtered.
  RecordsState _showPerson(RecordsState from, String? personId) {
    if (personId == _personId) return from;
    _personId = personId;
    _visitOnly = false;
    final store = _filterStore;
    if (store == null) return from;
    final saved = personId == null ? RecordsFilters.none : store.load(personId);
    return from.copyWith(
      activeFilters: saved.types,
      activeSpecialties: saved.specialties,
      dateFilter: saved.dateFilter,
    );
  }

  /// The state a filter event changes: a Home card's person's own filters
  /// when the card names someone else than the person shown.
  RecordsState _baseFor(String? personId) =>
      personId == null ? state : _showPerson(state, personId);

  Future<void> _onInitialised(
    RecordsInitialised event,
    Emitter<RecordsState> emit,
  ) async {
    await _loadResources(emit);
  }

  Future<void> _onLoadMore(
    RecordsLoadMore event,
    Emitter<RecordsState> emit,
  ) async {
    if (_isSearching ||
        !state.hasMorePages ||
        state.isLoadingMore ||
        state.status == const RecordsStatus.loading()) {
      return;
    }

    await _loadResources(emit, more: true);
  }

  Future<void> _onSourceChanged(
    RecordsSourceChanged event,
    Emitter<RecordsState> emit,
  ) async {
    final personId = event.isShareContext ? null : event.personId;
    final sameScope =
        event.sourceId == state.sourceId &&
        listEquals(event.sourceIds, state.sourceIds) &&
        personId == _personId;

    // The same scope again is a refresh: the list stays until the new one
    // arrives. Another person's or source's list starts over, without the
    // previous selection, which Share would otherwise send.
    final nextState = sameScope
        ? state
        : state.copyWith(
            sourceId: event.sourceId,
            sourceIds: event.sourceIds,
            resources: [],
            hasMorePages: false,
            selectedResourceIds: {},
          );

    // The same person again (each visit, a sync) keeps the filters shown,
    // also those a Home card set for this visit.
    emit(_showPerson(nextState, personId));

    await _loadResources(emit);
  }

  Future<void> _onFiltersApplied(
    RecordsFiltersApplied event,
    Emitter<RecordsState> emit,
  ) async {
    emit(
      _baseFor(event.personId).copyWith(
        activeFilters: event.filters,
        dateFilter: event.dateFilter,
        activeSpecialties: event.specialties,
        resources: [],
      ),
    );

    _visitOnly = !event.remember;
    if (event.remember) await _saveFilters();

    await _loadResources(emit);
  }

  Future<void> _onFilterRemoved(
    RecordsFilterRemoved event,
    Emitter<RecordsState> emit,
  ) async {
    final updatedFilters = [...state.activeFilters]..remove(event.filter);
    emit(
      state.copyWith(
        activeFilters: updatedFilters,
        resources: [],
      ),
    );

    _visitOnly = false;
    await _saveFilters();

    await _loadResources(emit);
  }

  Future<void> _onRecordDetailLoaded(
    RecordDetailLoaded event,
    Emitter<RecordsState> emit,
  ) async {
    emit(
      state.copyWith(recordDetailStatus: const RecordDetailStatus.loading()),
    );
    try {
      final relatedResources =
          (event.resource.fhirType == FhirType.Encounter ||
              event.resource.fhirType == FhirType.DiagnosticReport)
          ? await _recordsRepository.getRelatedResourcesForEncounter(
              encounterId: event.resource.resourceId,
            )
          : await _recordsRepository.getRelatedResources(
              resource: event.resource,
            );

      emit(
        state.copyWith(
          recordDetailStatus: const RecordDetailStatus.success(),
          relatedResources: relatedResources,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          recordDetailStatus: RecordDetailStatus.failure(e),
        ),
      );
    }
  }

  Future<void> _onSearch(
    RecordsSearch event,
    Emitter<RecordsState> emit,
  ) async {
    final query = event.query.trim();
    final wasSearching = _isSearching;
    emit(state.copyWith(searchQuery: query));

    _searchDebounceTimer?.cancel();

    // Too short to search: the list without a search, which a previous
    // search may have replaced.
    if (query.isEmpty || (query.length < _minSearchLength && wasSearching)) {
      emit(state.copyWith(resources: []));
      await _loadResources(emit);
      return;
    }

    if (query.length < _minSearchLength) {
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!isClosed) {
        add(RecordsSearchExecuted(query));
      }
    });
  }

  Future<void> _onSearchExecuted(
    RecordsSearchExecuted event,
    Emitter<RecordsState> emit,
  ) async {
    emit(
      state.copyWith(
        resources: [],
        hasMorePages: false,
      ),
    );
    await _loadResources(emit);
  }

  Future<void> _onRecordsSharePressed(
    RecordsSharePressed event,
    Emitter<RecordsState> emit,
  ) async {
    emit(state.copyWith(ipsExportStatus: IpsExportStatus.exporting));
    try {
      final export = await _recordsRepository.buildIpsExport(
        sourceId: event.sourceId,
        sourceIds: event.sourceIds,
        patientId: event.patientId,
      );

      final name = (event.patientName ?? export.patientName).replaceAll(
        RegExp(r'[^\w\s-]'),
        '',
      );
      final prefs = await SharedPreferences.getInstance();
      final region = RegionPreset.fromString(
        prefs.getString(SharedPrefsConstants.regionPreset),
      );
      final date = region.formatDate(DateTime.now());
      final fileName = TempFileSweeper.ipsSummaryName(name, date);

      // The previous export has been shared by now; Android targets read the
      // file lazily, so the newest one stays until the next export or start.
      await _deletePreviousIpsPdf();
      final File pdfFile = await File(
        '${(await getTemporaryDirectory()).path}/$fileName.pdf',
      ).writeAsBytes(export.bytes);
      _lastIpsPdfPath = pdfFile.path;

      // Awaited so a share sheet that fails to open counts as a failed
      // export; it returns once the sheet is dismissed.
      await SharePlus.instance.share(
        ShareParams(
          title: fileName,
          files: [XFile(pdfFile.path)],
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
        ),
      );
      emit(state.copyWith(ipsExportStatus: IpsExportStatus.idle));
    } catch (e, s) {
      logger.e('IPS export failed', e, s);
      emit(state.copyWith(ipsExportStatus: IpsExportStatus.failed));
    }
  }

  Future<void> _deletePreviousIpsPdf() async {
    final path = _lastIpsPdfPath;
    if (path == null) return;
    _lastIpsPdfPath = null;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e, s) {
      // The startup sweep deletes it next time.
      logger.w('Deleting the previous IPS PDF failed', e, s);
    }
  }

  /// The selected records, read from the database: the selection can hold
  /// records that aren't in the loaded pages.
  Future<List<IFhirResource>> loadSelectedResources() =>
      _recordsRepository.getResourcesByIds(state.selectedResourceIds);

  void _onSelectionToggled(
    RecordsSelectionToggled event,
    Emitter<RecordsState> emit,
  ) {
    final updated = Set<String>.from(state.selectedResourceIds);
    if (!updated.remove(event.resourceId)) {
      updated.add(event.resourceId);
    }
    emit(state.copyWith(selectedResourceIds: updated));
  }

  void _onSelectionCleared(
    RecordsSelectionCleared event,
    Emitter<RecordsState> emit,
  ) {
    emit(state.copyWith(selectedResourceIds: {}));
  }

  void _onSelectionModeToggled(
    RecordsSelectionModeToggled event,
    Emitter<RecordsState> emit,
  ) {
    final newSelectionMode = !state.isSelectionMode;
    emit(
      state.copyWith(
        isSelectionMode: newSelectionMode,
        selectedResourceIds: newSelectionMode ? state.selectedResourceIds : {},
      ),
    );
  }

  Future<void> _onDateRangeCleared(
    RecordsDateRangeCleared event,
    Emitter<RecordsState> emit,
  ) async {
    emit(
      state.copyWith(
        dateFilter: null,
        resources: [],
      ),
    );

    _visitOnly = false;
    await _saveFilters();

    await _loadResources(emit);
  }

  Future<void> _onResourceDeleted(
    RecordsResourceDeleted event,
    Emitter<RecordsState> emit,
  ) async {
    emit(state.copyWith(status: const RecordsStatus.loading()));

    try {
      if (event.selectedRelatedIds.isNotEmpty) {
        final allIds = <String>[event.resourceId, ...event.selectedRelatedIds];
        await _recordsRepository.deleteResourcesByIds(allIds);
      } else {
        await _recordsRepository.deleteResource(event.resourceId);
      }

      emit(
        state.copyWith(
          status: const RecordsStatus.deleted(),
          resources: [],
        ),
      );

      final remainingPatients = await _recordsRepository.getResources(
        resourceTypes: [FhirType.Patient],
        limit: 1,
      );

      if (remainingPatients.isEmpty) {
        emit(
          state.copyWith(
            status: const RecordsStatus.success(),
            resources: [],
            hasMorePages: false,
          ),
        );
      } else {
        await _loadResources(emit);
      }
    } catch (e) {
      emit(state.copyWith(status: RecordsStatus.failure(e)));
    }
  }

  Future<void> _onSpecialtyApplied(
    RecordsSpecialtyApplied event,
    Emitter<RecordsState> emit,
  ) async {
    emit(
      _baseFor(event.personId).copyWith(
        activeSpecialties: event.specialties,
        resources: [],
      ),
    );

    _visitOnly = !event.remember;
    if (event.remember) await _saveFilters();

    await _loadResources(emit);
  }

  Future<void> _onRefreshRequested(
    RecordsRefreshRequested event,
    Emitter<RecordsState> emit,
  ) async {
    emit(state.copyWith(resources: []));

    await _loadResources(emit);
  }

  Future<void> _onClearAllFilters(
    RecordsClearAllFilters event,
    Emitter<RecordsState> emit,
  ) async {
    emit(
      state.copyWith(
        activeFilters: [],
        activeSpecialties: [],
        dateFilter: null,
        resources: [],
      ),
    );

    _visitOnly = false;
    await _saveFilters();

    await _loadResources(emit);
  }

  Future<void> _onVisitEnded(
    RecordsVisitEnded event,
    Emitter<RecordsState> emit,
  ) async {
    final personId = _personId;
    final store = _filterStore;
    if (!_visitOnly || personId == null || store == null) return;
    _visitOnly = false;
    final saved = store.load(personId);
    emit(
      state.copyWith(
        activeFilters: saved.types,
        activeSpecialties: saved.specialties,
        dateFilter: saved.dateFilter,
        resources: [],
      ),
    );
    await _loadResources(emit);
  }
}
