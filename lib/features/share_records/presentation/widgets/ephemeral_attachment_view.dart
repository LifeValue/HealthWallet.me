import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_detail_panel_ephemeral.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_timeline_scrubber.dart';
import 'package:health_wallet/features/records/presentation/widgets/attachment_browse/attachment_thumbnail_strip.dart';

const double _kThumbnailItemWidth = 100.0;
const double _kThumbnailGap = 16.0;
const double _kThumbnailPadding = 24.0;
const double _kTimelineHeight = 72.0;
const double _kThumbnailHeight = 100.0;
const double _kTimelineTopPad = 12.0;
const double _kThumbnailTopPad = 8.0;

class EphemeralAttachmentView extends StatefulWidget {
  const EphemeralAttachmentView({super.key});

  @override
  State<EphemeralAttachmentView> createState() =>
      _EphemeralAttachmentBrowseState();
}

class _EphemeralAttachmentBrowseState
    extends State<EphemeralAttachmentView> {
  final ScrollController _thumbnailScrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  bool _isThumbnailSyncing = false;
  int _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    _thumbnailScrollController.addListener(_onThumbnailScroll);
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
    _thumbnailScrollController.removeListener(_onThumbnailScroll);
    _thumbnailScrollController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  void _onThumbnailScroll() {
    if (_isThumbnailSyncing) return;
    if (!_thumbnailScrollController.hasClients) return;

    final bloc = context.read<AttachmentBrowseBloc>();
    final max = bloc.state.records.length - 1;
    if (max <= 0) return;

    final maxScroll = _thumbnailScrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final progress =
        (_thumbnailScrollController.offset / maxScroll).clamp(0.0, 1.0);
    final index = (progress * max).round();
    if (index != _visibleIndex) {
      setState(() => _visibleIndex = index);
    }
  }

  void _scrollThumbnailTo(int index) {
    if (!_thumbnailScrollController.hasClients) return;
    if (!_thumbnailScrollController.position.hasContentDimensions) return;
    _isThumbnailSyncing = true;
    final targetOffset =
        _kThumbnailPadding + index * (_kThumbnailItemWidth + _kThumbnailGap) - _kThumbnailGap;
    final maxScroll = _thumbnailScrollController.position.maxScrollExtent;
    _thumbnailScrollController
        .animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .then((_) => _isThumbnailSyncing = false);
  }

  void _scrollDetailToTop() {
    if (!_detailScrollController.hasClients) return;
    _detailScrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttachmentBrowseBloc, AttachmentBrowseState>(
      listenWhen: (prev, curr) =>
          prev.selectedIndex != curr.selectedIndex &&
          curr.status == AttachmentBrowseStatus.success,
      listener: (context, state) {
        _visibleIndex = state.selectedIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollThumbnailTo(state.selectedIndex);
          _scrollDetailToTop();
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
        final overlayBottomPad = bottomInset > 0 ? bottomInset : 8.0;
        final timelineSpace =
            hasTimeline ? _kTimelineTopPad + _kTimelineHeight : 0.0;
        final bottomBarHeight =
            timelineSpace + _kThumbnailTopPad + _kThumbnailHeight;

        return Stack(
          children: [
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 200) return;
                _swipeRecord(velocity < 0 ? 1 : -1);
              },
              child: detail != null
                  ? SingleChildScrollView(
                      controller: _detailScrollController,
                      padding: EdgeInsets.only(
                        bottom: bottomBarHeight + overlayBottomPad,
                      ),
                      child: AttachmentDetailPanelEphemeral(detail: detail),
                    )
                  : const SizedBox.expand(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _EphemeralBottomOverlay(
                hasTimeline: hasTimeline,
                state: state,
                visibleIndex: _visibleIndex,
                thumbnailScrollController: _thumbnailScrollController,
                onSwipe: _swipeRecord,
                bottomPadding: overlayBottomPad,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EphemeralBottomOverlay extends StatelessWidget {
  final bool hasTimeline;
  final AttachmentBrowseState state;
  final int visibleIndex;
  final ScrollController thumbnailScrollController;
  final void Function(int direction) onSwipe;
  final double bottomPadding;

  const _EphemeralBottomOverlay({
    required this.hasTimeline,
    required this.state,
    required this.visibleIndex,
    required this.thumbnailScrollController,
    required this.onSwipe,
    this.bottomPadding = 0,
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
                    selectedIndex: visibleIndex,
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
                  onSelected: (index) {
                    context.read<AttachmentBrowseBloc>().add(
                          AttachmentBrowseSelected(index),
                        );
                  },
                ),
              ),
              SizedBox(height: bottomPadding),
            ],
          ),
        ],
      ),
    );
  }
}
