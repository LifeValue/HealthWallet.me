import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class DropdownField extends StatefulWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String>? onChanged;
  final bool isSelected;

  const DropdownField({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.isSelected = false,
  });

  @override
  State<DropdownField> createState() => _DropdownFieldState();
}

class _DropdownFieldState extends State<DropdownField> {
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
                          (widget.items.length > 3 ? 3 : widget.items.length),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      children: widget.items
                          .map((item) => _buildMenuItem(item))
                          .toList(),
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

  Widget _buildMenuItem(String item) {
    final isSelected = item == widget.value;
    return InkWell(
      onTap: widget.onChanged != null ? () {
        widget.onChanged!(item);
        _hideMenu();
      } : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(
            left: Insets.small, right: Insets.small, top: Insets.small),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.smallNormal, vertical: Insets.small),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item,
            style: AppTextStyle.labelLarge.copyWith(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface,
            ),
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.onChanged != null ? _toggleMenu : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 36,
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.small, vertical: Insets.small),
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
