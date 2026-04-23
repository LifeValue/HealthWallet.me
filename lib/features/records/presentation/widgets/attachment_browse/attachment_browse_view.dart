import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_detail_panel.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_timeline_scrubber.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_thumbnail_strip.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

const double kThumbnailItemWidth = 100.0;
const double kThumbnailGap = 16.0;
const double kThumbnailPadding = 24.0;

const double _kTimelineHeight = 72.0;
const double _kThumbnailHeight = 100.0;
const double _kTimelineTopPad = 12.0;
const double _kThumbnailTopPad = 8.0;
const double _kBottomNavHeight = 80.0;

class AttachmentBrowseView extends StatefulWidget {
  const AttachmentBrowseView({super.key});

  @override
  State<AttachmentBrowseView> createState() => _AttachmentBrowseViewState();
}

class _AttachmentBrowseViewState extends State<AttachmentBrowseView> {
  final ScrollController _thumbnailScrollController = ScrollController();
  bool _didInit = false;
  bool _isThumbnailSyncing = false;
  List<FhirType> _lastFilters = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _loadWithCurrentFilters();
    }
  }

  ({String? sourceId, List<String>? sourceIds}) _resolveSource() {
    final homeState = context.read<HomeBloc>().state;
    final sourceId =
        homeState.selectedSource == 'All' ? null : homeState.selectedSource;
    List<String>? sourceIds;
    if (sourceId == null) {
      try {
        final patientState = context.read<PatientBloc>().state;
        final selectedPatientId = patientState.selectedPatientId;
        if (selectedPatientId != null) {
          final group = patientState.patientGroups[selectedPatientId];
          if (group != null) sourceIds = group.sourceIds;
        }
      } catch (_) {}
    }
    return (sourceId: sourceId, sourceIds: sourceIds);
  }

  void _loadWithCurrentFilters() {
    final source = _resolveSource();
    List<FhirType> filters = [];
    try {
      filters = context.read<RecordsBloc>().state.activeFilters;
    } catch (_) {}
    _lastFilters = filters;
    context.read<AttachmentBrowseBloc>().add(
          AttachmentBrowseInitialised(
            sourceId: source.sourceId,
            sourceIds: source.sourceIds,
            resourceTypes: filters,
          ),
        );
  }

  void _swipeRecord(int direction) {
    final bloc = context.read<AttachmentBrowseBloc>();
    final idx = bloc.state.selectedIndex;
    final max = bloc.state.records.length - 1;
    final newIdx = (idx + direction).clamp(0, max);
    if (newIdx != idx) {
      bloc.add(AttachmentBrowseSelected(newIdx));
    }
  }

  @override
  void dispose() {
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _scrollThumbnailTo(int index) {
    if (!_thumbnailScrollController.hasClients) return;
    if (!_thumbnailScrollController.position.hasContentDimensions) return;
    _isThumbnailSyncing = true;
    final targetOffset =
        kThumbnailPadding + index * (kThumbnailItemWidth + kThumbnailGap) - kThumbnailGap;
    final maxScroll = _thumbnailScrollController.position.maxScrollExtent;
    _thumbnailScrollController
        .animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .then((_) => _isThumbnailSyncing = false);
  }

  void _checkFiltersChanged(List<FhirType> currentFilters) {
    final changed = currentFilters.length != _lastFilters.length ||
        !currentFilters.every((f) => _lastFilters.contains(f));
    if (changed) {
      _lastFilters = currentFilters;
      _loadWithCurrentFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordsBloc, RecordsState>(
      buildWhen: (prev, curr) =>
          prev.activeFilters != curr.activeFilters ||
          prev.isSelectionMode != curr.isSelectionMode ||
          prev.selectedResourceIds != curr.selectedResourceIds,
      builder: (context, recordsState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkFiltersChanged(recordsState.activeFilters);
        });
        return BlocConsumer<AttachmentBrowseBloc, AttachmentBrowseState>(
        listenWhen: (prev, curr) =>
            prev.selectedIndex != curr.selectedIndex &&
            curr.status == AttachmentBrowseStatus.success,
        listener: (context, state) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollThumbnailTo(state.selectedIndex);
          });
        },
        builder: (context, state) {
          if (state.status == AttachmentBrowseStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.records.isEmpty) {
            return Center(
              child: Text(
                'No records',
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
            );
          }

          final detail = state.selectedDetail;
          final hasTimeline = state.timelineYears.isNotEmpty;
          final bottomInset = MediaQuery.of(context).padding.bottom;
          final timelineSpace =
              hasTimeline ? _kTimelineTopPad + _kTimelineHeight : 0.0;
          final bottomBarHeight =
              timelineSpace + _kThumbnailTopPad + _kThumbnailHeight;

          return Stack(
            children: [
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < 200) return;
                  _swipeRecord(velocity < 0 ? 1 : -1);
                },
                child: detail != null
                    ? SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: bottomBarHeight +
                              _kBottomNavHeight +
                              bottomInset,
                        ),
                        child: AttachmentDetailPanel(detail: detail),
                      )
                    : const SizedBox.expand(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: _kBottomNavHeight + bottomInset,
                child: _BottomOverlay(
                  hasTimeline: hasTimeline,
                  state: state,
                  thumbnailScrollController: _thumbnailScrollController,
                  onSwipe: _swipeRecord,
                  isSelectionMode: recordsState.isSelectionMode,
                  selectedResourceIds: recordsState.selectedResourceIds,
                  onSelectionToggle: (id) {
                    context.read<RecordsBloc>().add(
                          RecordsSelectionToggled(id),
                        );
                  },
                ),
              ),
            ],
          );
        },
      );
      },
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  final bool hasTimeline;
  final AttachmentBrowseState state;
  final ScrollController thumbnailScrollController;
  final void Function(int direction) onSwipe;
  final bool isSelectionMode;
  final Set<String> selectedResourceIds;
  final ValueChanged<String>? onSelectionToggle;

  const _BottomOverlay({
    required this.hasTimeline,
    required this.state,
    required this.thumbnailScrollController,
    required this.onSwipe,
    this.isSelectionMode = false,
    this.selectedResourceIds = const {},
    this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        onSwipe(velocity < 0 ? 1 : -1);
      },
      child: Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                    colors: context.isDarkMode
                        ? [
                            context.colorScheme.surface
                                .withValues(alpha: 0.02),
                            context.colorScheme.surface
                                .withValues(alpha: 0.5),
                            context.colorScheme.surface,
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.02),
                            Colors.white.withValues(alpha: 0.5),
                            Colors.white,
                          ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTimeline) ...[
              const SizedBox(height: _kTimelineTopPad),
              SizedBox(
                height: _kTimelineHeight,
                child: AttachmentTimelineScrubber(
                  timelineYears: state.timelineYears,
                  selectedIndex: state.selectedIndex,
                  records: state.records,
                  onYearSelected: (year) {
                    final yearEntry = state.timelineYears
                        .where((y) => y.year == year)
                        .firstOrNull;
                    if (yearEntry != null && yearEntry.months.isNotEmpty) {
                      context.read<AttachmentBrowseBloc>().add(
                            AttachmentBrowseSelected(
                              yearEntry.months.first.firstRecordIndex,
                            ),
                          );
                    }
                  },
                  onMonthSelected: (year, month) {
                    context.read<AttachmentBrowseBloc>().add(
                          AttachmentBrowseMonthSelected(year, month),
                        );
                  },
                ),
              ),
            ],
            const SizedBox(height: _kThumbnailTopPad),
            SizedBox(
              height: _kThumbnailHeight,
              child: AttachmentThumbnailStrip(
                records: state.records,
                selectedIndex: state.selectedIndex,
                scrollController: thumbnailScrollController,
                isSelectionMode: isSelectionMode,
                selectedResourceIds: selectedResourceIds,
                onSelectionToggle: onSelectionToggle,
                onSelected: (index) {
                  context.read<AttachmentBrowseBloc>().add(
                        AttachmentBrowseSelected(index),
                      );
                },
              ),
            ),
          ],
        ),
      ],
    ),
    );
  }
}
