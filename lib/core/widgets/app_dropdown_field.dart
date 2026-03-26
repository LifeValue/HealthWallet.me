import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class AppDropdownField<T> extends StatefulWidget {
  final String value;
  final List<T> items;
  final String Function(T) getDisplayText;
  final ValueChanged<T>? onChanged;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.getDisplayText,
    this.onChanged,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleMenu() {
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
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
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
                    constraints: BoxConstraints(
                      maxHeight: 52.0 *
                          (widget.items.length > 7 ? 7 : widget.items.length),
                    ),
                    child: _MenuList(
                      items: widget.items,
                      selectedValue: widget.value,
                      getDisplayText: widget.getDisplayText,
                      onSelected: (item) {
                        widget.onChanged?.call(item);
                        _hideMenu();
                      },
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

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.onChanged != null ? _toggleMenu : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 42,
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.smallNormal, vertical: Insets.small),
          decoration: BoxDecoration(
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
                  widget.value,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.labelLarge
                      .copyWith(color: context.colorScheme.onSurface),
                ),
              ),
              Icon(
                _isOpen ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: context.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuList<T> extends StatefulWidget {
  final List<T> items;
  final String selectedValue;
  final String Function(T) getDisplayText;
  final ValueChanged<T> onSelected;

  const _MenuList({
    required this.items,
    required this.selectedValue,
    required this.getDisplayText,
    required this.onSelected,
  });

  @override
  State<_MenuList<T>> createState() => _MenuListState<T>();
}

class _MenuListState<T> extends State<_MenuList<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  void _scrollToSelected() {
    final index = widget.items.indexWhere(
      (item) => widget.getDisplayText(item) == widget.selectedValue,
    );
    if (index > 0 && _scrollController.hasClients) {
      final offset = (index * 52.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(offset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final itemText = widget.getDisplayText(item);
        final isSelected = itemText == widget.selectedValue;

        return InkWell(
          onTap: () => widget.onSelected(item),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(
              left: Insets.small,
              right: Insets.small,
              top: Insets.small,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.smallNormal,
                vertical: Insets.small,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                itemText,
                style: AppTextStyle.bodyMedium.copyWith(
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
