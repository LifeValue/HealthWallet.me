import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'date_range_filter_model.dart';

class DateWideDropdown extends StatefulWidget {
  final String label;
  final int? value;
  final List<DateDropdownItem> items;
  final ValueChanged<int?>? onChanged;
  final bool enabled;
  final GlobalKey containerKey;
  final int? selectedYear;
  final int? selectedMonth;
  final bool openUpward;

  const DateWideDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.containerKey,
    this.enabled = true,
    this.selectedYear,
    this.selectedMonth,
    this.openUpward = false,
  });

  @override
  State<DateWideDropdown> createState() => _DateWideDropdownState();
}

class _DateWideDropdownState extends State<DateWideDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  int _yearPageOffset = 0;

  void _toggleMenu() {
    if (!widget.enabled || widget.onChanged == null) return;

    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _showMenu();
    } else {
      _hideMenu();
    }
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _showMenu() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final containerRenderBox =
        widget.containerKey.currentContext?.findRenderObject() as RenderBox?;
    final containerWidth = containerRenderBox?.size.width ?? size.width;
    final containerPosition =
        containerRenderBox?.localToGlobal(Offset.zero) ?? position;

    final screenSize = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;

    final menuContent = StatefulBuilder(
      builder: (context, setOverlayState) {
        final content = widget.label == 'Year'
            ? _buildYearPicker(setOverlayState)
            : widget.label == 'Day'
                ? _buildDayCalendar()
                : _buildMonthGrid();

        // Calculate menu height based on type
        final menuHeight = widget.label == 'Day' ? 340.0 : 260.0;

        double? top;
        double? bottom;

        if (widget.openUpward) {
          // Position above the dropdown field
          bottom = screenSize.height - position.dy + 4;
          // Ensure menu doesn't overflow above safe area
          final availableAbove = position.dy - viewPadding.top;
          if (menuHeight > availableAbove) {
            bottom = screenSize.height - position.dy - size.height - 4;
            top = viewPadding.top + 4;
          }
        } else {
          // Position below the dropdown field
          top = position.dy + size.height + 4;
          // Ensure menu doesn't overflow below safe area
          final availableBelow =
              screenSize.height - top - viewPadding.bottom;
          if (menuHeight > availableBelow) {
            // Clamp the top so the bottom stays above safe area
            final maxTop =
                screenSize.height - menuHeight - viewPadding.bottom - 4;
            if (maxTop > viewPadding.top) {
              top = maxTop;
            }
          }
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideMenu,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: containerPosition.dx,
              width: containerWidth,
              top: top,
              bottom: bottom,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: context.colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.isDarkMode
                          ? AppColors.borderDark
                          : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    _overlayEntry = OverlayEntry(builder: (_) => menuContent);

    overlay.insert(_overlayEntry!);
  }

  Widget _buildYearPicker(StateSetter setOverlayState) {
    final currentYear = DateTime.now().year;
    final minYear = currentYear - 200;

    final pageStartYear = currentYear - (_yearPageOffset * 25) - 24;
    final years = List.generate(25, (index) => pageStartYear + index)
        .where((year) => year >= minYear && year <= currentYear)
        .toList()
        .reversed
        .toList();

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          if (pageStartYear + 24 < currentYear) {
            setOverlayState(() {
              _yearPageOffset--;
            });
          }
        } else if (details.primaryVelocity! < 0) {
          if (pageStartYear > minYear) {
            setOverlayState(() {
              _yearPageOffset++;
            });
          }
        }
      },
      child: SizedBox(
        height: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: pageStartYear + 24 < currentYear
                        ? () {
                            setOverlayState(() {
                              _yearPageOffset--;
                            });
                          }
                        : null,
                  ),
                  Text(
                    years.isNotEmpty ? '${years.last} - ${years.first}' : '',
                    style: AppTextStyle.titleSmall.copyWith(
                      color: context.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: pageStartYear > minYear
                        ? () {
                            setOverlayState(() {
                              _yearPageOffset++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: years.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildClearButton();
                    }
                    final year = years[index - 1];
                    return _buildYearItem(year);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    return SizedBox(
      height: 260,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            return _buildGridItem(widget.items[index]);
          },
        ),
      ),
    );
  }

  Widget _buildDayCalendar() {
    final now = DateTime.now();
    final year = widget.selectedYear ?? now.year;
    final monthValue = widget.selectedMonth ?? now.month;

    final firstDayOfMonth = DateTime(year, monthValue, 1);
    final daysInMonth = DateTime(year, monthValue + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7;

    final dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    const double cellHeight = 36;
    // 6 rows max + header + gaps + padding
    const double maxCalendarHeight = (cellHeight + 4) * 6 + 16 + 1 + 12 + 16;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: maxCalendarHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
            child: Row(
              children: dayNames
                  .map((name) => Expanded(
                        child: Center(
                          child: Text(
                            name,
                            style: AppTextStyle.labelSmall.copyWith(
                              color: context.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: Theme.of(context).platform == TargetPlatform.iOS ? 4 : 4),
          Transform.translate(
            offset: Offset(0, Theme.of(context).platform == TargetPlatform.iOS ? -28 : -12),
            child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: cellHeight,
            ),
            itemCount: startWeekday + daysInMonth + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildClearButton();
              }

              if (index <= startWeekday) {
                return const SizedBox.shrink();
              }

              final day = index - startWeekday;
              return _buildDayItem(day);
            },
          ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildClearButton() {
    return InkWell(
      onTap: widget.onChanged != null
          ? () {
              widget.onChanged!(null);
              _hideMenu();
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.theme.dividerColor,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            '-',
            style: AppTextStyle.labelMedium.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearItem(int year) {
    final isSelected = year == widget.value;

    return InkWell(
      onTap: widget.onChanged != null
          ? () {
              widget.onChanged!(year);
              _hideMenu();
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.colorScheme.primary
                : context.theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            year.toString(),
            style: AppTextStyle.labelMedium.copyWith(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayItem(int day) {
    final isSelected = day == widget.value;

    return InkWell(
      onTap: widget.onChanged != null
          ? () {
              widget.onChanged!(day);
              _hideMenu();
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.colorScheme.primary
                : context.theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: AppTextStyle.labelMedium.copyWith(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(DateDropdownItem item) {
    final isSelected = item.value == widget.value;

    return InkWell(
      onTap: widget.onChanged != null
          ? () {
              widget.onChanged!(item.value);
              _hideMenu();
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.colorScheme.primary
                : context.theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            item.displayText,
            style: AppTextStyle.labelMedium.copyWith(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchingItem = widget.items.cast<DateDropdownItem?>().firstWhere(
          (item) => item!.value == widget.value,
          orElse: () => null,
        );
    final displayValue = matchingItem?.displayText ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyle.labelSmall.copyWith(
            color: context.colorScheme.onSurface
                .withValues(alpha: widget.enabled ? 0.7 : 0.4),
          ),
        ),
        const SizedBox(height: 4),
        CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            onTap: _toggleMenu,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.small, vertical: Insets.small),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? context.colorScheme.surface
                    : context.colorScheme.onSurface.withValues(alpha: 0.05),
                border: Border.all(
                  color: _isOpen
                      ? context.colorScheme.primary
                      : context.isDarkMode
                          ? AppColors.borderDark
                          : AppColors.border,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayValue,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.labelLarge.copyWith(
                        color: widget.enabled
                            ? context.colorScheme.onSurface
                            : context.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Icon(
                    _isOpen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: widget.enabled
                        ? context.colorScheme.onSurface.withValues(alpha: 0.7)
                        : context.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
