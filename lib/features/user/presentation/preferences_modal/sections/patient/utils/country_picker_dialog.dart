import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'phone_input_field.dart';

class CountryPickerDialog extends StatefulWidget {
  final List<CountryEntry> countries;
  final CountryEntry selected;

  const CountryPickerDialog({
    super.key,
    required this.countries,
    required this.selected,
  });

  @override
  State<CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<CountryPickerDialog> {
  final _searchCtrl = TextEditingController();
  late List<CountryEntry> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.countries;
        return;
      }
      _filtered = widget.countries.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.isoCode.name.toLowerCase().contains(q) ||
            c.dialCode.contains(q) ||
            '+${c.dialCode}'.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.isDarkMode ? AppColors.surfaceDark : AppColors.surface;
    final bColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;
    final tColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Insets.medium),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSearchField(bColor, tColor),
              Flexible(child: _buildList(tColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(Color bColor, Color tColor) {
    return Padding(
      padding: const EdgeInsets.all(Insets.normal),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: bColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onSearch,
          style: AppTextStyle.labelLarge.copyWith(color: tColor),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Insets.small,
              vertical: Insets.small,
            ),
            border: InputBorder.none,
            isDense: true,
            hintStyle: AppTextStyle.labelLarge.copyWith(
              color: context.isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            prefixIcon: Icon(Icons.search,
                size: 20, color: tColor.withValues(alpha: 0.5)),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildList(Color tColor) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final entry = _filtered[index];
        final isSel = entry.isoCode == widget.selected.isoCode;
        return InkWell(
          onTap: () => Navigator.of(context).pop(entry),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.normal,
              vertical: Insets.small,
            ),
            color: isSel
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            child: Row(
              children: [
                Text(entry.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: Insets.small),
                Expanded(
                  child: Text(
                    entry.name,
                    style: AppTextStyle.labelLarge.copyWith(
                      color: tColor,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Insets.small),
                Text(
                  '+${entry.dialCode}',
                  style: AppTextStyle.labelLarge.copyWith(
                    color: context.isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
