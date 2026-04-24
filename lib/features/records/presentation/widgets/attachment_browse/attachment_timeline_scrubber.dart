import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';

class _TimelineItem {
  final bool isYear;
  final int year;
  final int? month;
  final int recordCount;
  final int firstRecordIndex;

  _TimelineItem({
    required this.isYear,
    required this.year,
    this.month,
    this.recordCount = 0,
    required this.firstRecordIndex,
  });
}

class AttachmentTimelineScrubber extends StatefulWidget {
  final List<TimelineYear> timelineYears;
  final int selectedIndex;
  final List<AttachmentBrowseEntry> records;
  final ValueChanged<int> onYearSelected;
  final void Function(int year, int month) onMonthSelected;

  const AttachmentTimelineScrubber({
    super.key,
    required this.timelineYears,
    required this.selectedIndex,
    required this.records,
    required this.onYearSelected,
    required this.onMonthSelected,
  });

  @override
  State<AttachmentTimelineScrubber> createState() =>
      _AttachmentTimelineScrubberState();
}

class _AttachmentTimelineScrubberState
    extends State<AttachmentTimelineScrubber> {
  late final ScrollController _scrollController;
  bool _isSyncing = false;
  List<_TimelineItem> _items = [];
  int _currentItemIndex = 0;

  static const double _yearWidth = 64.0;
  static const double _dotSpacing = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _buildTimelineItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedIndex();
    });
  }

  @override
  void didUpdateWidget(AttachmentTimelineScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timelineYears != widget.timelineYears) {
      _buildTimelineItems();
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelectedIndex();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _buildTimelineItems() {
    _items = [];
    for (final year in widget.timelineYears) {
      final firstMonthIndex =
          year.months.isNotEmpty ? year.months.first.firstRecordIndex : 0;
      _items.add(_TimelineItem(
        isYear: true,
        year: year.year,
        firstRecordIndex: firstMonthIndex,
      ));
      for (final month in year.months) {
        _items.add(_TimelineItem(
          isYear: false,
          year: year.year,
          month: month.month,
          recordCount: month.recordCount,
          firstRecordIndex: month.firstRecordIndex,
        ));
      }
    }
  }

  int _dotsForMonth(int recordCount) {
    if (recordCount <= 0) return 0;
    if (recordCount == 1) return 1;
    if (recordCount <= 3) return 2;
    if (recordCount <= 6) return 3;
    if (recordCount <= 10) return 4;
    return 5;
  }

  double _widthForItem(_TimelineItem item) {
    if (item.isYear) return _yearWidth;
    final dotCount = _dotsForMonth(item.recordCount);
    return dotCount * _dotSpacing + _dotSpacing;
  }

  double _offsetForItemIndex(int itemIndex) {
    double offset = 0;
    for (int i = 0; i < itemIndex && i < _items.length; i++) {
      offset += _widthForItem(_items[i]);
    }
    return offset;
  }

  int _itemIndexForRecordIndex(int recordIndex) {
    int best = 0;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].firstRecordIndex <= recordIndex) {
        best = i;
      }
    }
    return best;
  }

  void _scrollToSelectedIndex() {
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    _isSyncing = true;
    final itemIndex = _itemIndexForRecordIndex(widget.selectedIndex);
    final target = _offsetForItemIndex(itemIndex);
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    setState(() => _currentItemIndex = itemIndex);
    Future.delayed(const Duration(milliseconds: 250), () {
      _isSyncing = false;
    });
  }

  void _onScroll() {
    if (_isSyncing) return;
    if (!_scrollController.hasClients) return;

    double offset = _scrollController.offset;
    double cumulative = 0;
    int foundIndex = 0;
    for (int i = 0; i < _items.length; i++) {
      final w = _widthForItem(_items[i]);
      if (cumulative + w / 2 > offset) {
        foundIndex = i;
        break;
      }
      cumulative += w;
      foundIndex = i;
    }

    if (foundIndex != _currentItemIndex) {
      setState(() => _currentItemIndex = foundIndex);
      final item = _items[foundIndex];
      if (item.firstRecordIndex != widget.selectedIndex) {
        if (item.month != null) {
          widget.onMonthSelected(item.year, item.month!);
        } else {
          widget.onYearSelected(item.year);
        }
      }
    }
  }

  String _currentLabel() {
    if (_items.isEmpty || _currentItemIndex >= _items.length) return '';
    final item = _items[_currentItemIndex];
    if (item.month != null) return '${item.year}/${item.month}';
    return '${item.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final isDark = context.isDarkMode;
    final onSurface = context.colorScheme.onSurface;
    final label = _currentLabel();
    final halfScreen = MediaQuery.of(context).size.width / 2;

    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 32,
            height: 24,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: halfScreen),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return _buildTimelineItem(index, onSurface, isDark);
              },
            ),
          ),
          if (label.isNotEmpty) _buildLabel(label, onSurface, isDark),
          _buildCursorLine(onSurface),
          _buildCursorDot(onSurface),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(int index, Color onSurface, bool isDark) {
    final item = _items[index];
    final pillColor = isDark
        ? onSurface.withValues(alpha: 0.16)
        : Colors.grey.shade300;

    if (item.isYear) {
      return GestureDetector(
        onTap: () => widget.onYearSelected(item.year),
        child: SizedBox(
          width: _yearWidth,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(222),
              ),
              child: Text(
                '${item.year}',
                style: AppTextStyle.labelSmall.copyWith(
                  color: onSurface,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final dotCount = _dotsForMonth(item.recordCount);
    return GestureDetector(
      onTap: () {
        if (item.month != null) {
          widget.onMonthSelected(item.year, item.month!);
        }
      },
      child: SizedBox(
        width: _widthForItem(item),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(dotCount, (i) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: _dotSpacing / 2 - 2),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? onSurface.withValues(alpha: 0.5)
                      : Colors.grey.shade500,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLabel(String label, Color onSurface, bool isDark) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? onSurface.withValues(alpha: 0.24)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: AppTextStyle.labelSmall.copyWith(
                color: isDark ? onSurface : Colors.black87,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCursorLine(Color onSurface) {
    return Positioned(
      left: 0,
      right: 0,
      top: 26,
      child: IgnorePointer(
        child: Center(
          child: Container(width: 1, height: 10, color: onSurface),
        ),
      ),
    );
  }

  Widget _buildCursorDot(Color onSurface) {
    return Positioned(
      left: 0,
      right: 0,
      top: 41,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: onSurface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
