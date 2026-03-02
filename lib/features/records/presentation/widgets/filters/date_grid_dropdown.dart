import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'date_range_filter_model.dart';

class DateGridDropdown extends StatefulWidget {
  final String label;
  final int? value;
  final List<DateDropdownItem> items;
  final ValueChanged<int?>? onChanged;
  final bool enabled;
  final int crossAxisCount;

  const DateGridDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.crossAxisCount = 4,
  });

  @override
  State<DateGridDropdown> createState() => _DateGridDropdownState();
}

class _DateGridDropdownState extends State<DateGridDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

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
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  void _showMenu() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideMenu,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: size.width * 2.5,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(-size.width * 0.75, size.height + 4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.isDarkMode
                        ? AppColors.borderDark
                        : AppColors.border,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2)),
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, -4)),
                  ],
                ),
                child: Material(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(12),
                  color: context.colorScheme.surface,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 300,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: widget.crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.0,
                        ),
                        itemCount: widget.items.length,
                        itemBuilder: (context, index) {
                          return _buildGridItem(widget.items[index]);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildGridItem(DateDropdownItem item) {
    final itemText = item.displayText;
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
            itemText,
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
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.items
        .firstWhere((item) => item.value == widget.value)
        .displayText;

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
