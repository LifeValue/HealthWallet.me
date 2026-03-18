import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'country_names.dart';
import 'country_picker_dialog.dart';

class CountryEntry {
  final IsoCode isoCode;
  final String dialCode;
  final String flag;
  final String name;

  const CountryEntry({
    required this.isoCode,
    required this.dialCode,
    required this.flag,
    required this.name,
  });
}

List<CountryEntry> buildCountryList() {
  final entries = <CountryEntry>[];
  for (final iso in IsoCode.values) {
    final meta = metadataByIsoCode[iso];
    if (meta == null) continue;
    entries.add(CountryEntry(
      isoCode: iso,
      dialCode: meta.countryCode,
      flag: _isoToFlag(iso.name),
      name: countryNames[iso] ?? iso.name,
    ));
  }
  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

String _isoToFlag(String code) {
  return code.toUpperCase().codeUnits
      .map((c) => String.fromCharCode(c - 0x41 + 0x1F1E6))
      .join();
}

String _formatNsn(IsoCode isoCode, String digits) {
  if (digits.isEmpty) return '';
  try {
    return PhoneNumber(isoCode: isoCode, nsn: digits).formatNsn();
  } catch (_) {
    return digits;
  }
}

int _maxNsnLength(IsoCode isoCode) {
  final lengths = metadataLenghtsByIsoCode[isoCode];
  if (lengths == null) return 15;
  final all = [
    ...lengths.general,
    ...lengths.mobile,
    ...lengths.fixedLine,
    ...lengths.voip,
    ...lengths.tollFree,
    ...lengths.premiumRate,
    ...lengths.sharedCost,
    ...lengths.personalNumber,
    ...lengths.uan,
    ...lengths.pager,
    ...lengths.voiceMail,
  ];
  if (all.isEmpty) return 15;
  return all.reduce((a, b) => a > b ? a : b);
}

class PhoneInputField extends StatefulWidget {
  final String value;
  final ValueChanged<String>? onChanged;

  const PhoneInputField({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  static final List<CountryEntry> _countries = buildCountryList();
  late CountryEntry _selectedCountry;
  late TextEditingController _numberCtrl;
  bool _formatting = false;
  String _lastDigits = '';

  CountryEntry get _defaultCountry {
    final countryCode =
        ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    if (countryCode != null) {
      final match = _countries
          .where((c) => c.isoCode.name.toUpperCase() == countryCode)
          .firstOrNull;
      if (match != null) return match;
    }
    return _countries.firstWhere(
      (c) => c.isoCode == IsoCode.US,
      orElse: () => _countries.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _initFromValue();
    _numberCtrl.addListener(_onControllerChanged);
  }

  void _initFromValue() {
    if (widget.value.isNotEmpty) {
      try {
        final parsed = PhoneNumber.parse(widget.value);
        _selectedCountry = _countries.firstWhere(
          (c) => c.isoCode == parsed.isoCode,
          orElse: () => _defaultCountry,
        );
        final maxLen = _maxNsnLength(parsed.isoCode);
        final nsn = parsed.nsn.length > maxLen
            ? parsed.nsn.substring(0, maxLen)
            : parsed.nsn;
        _lastDigits = nsn;
        _numberCtrl = TextEditingController(
          text: _formatNsn(parsed.isoCode, nsn),
        );
        return;
      } catch (_) {}
    }
    _selectedCountry = _defaultCountry;
    _numberCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _numberCtrl.removeListener(_onControllerChanged);
    _numberCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_formatting) return;
    _formatting = true;

    var digits = _numberCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final maxLen = _maxNsnLength(_selectedCountry.isoCode);
    if (digits.length > maxLen) digits = digits.substring(0, maxLen);

    final prevFormatted = _formatNsn(_selectedCountry.isoCode, _lastDigits);
    final isDeleting = _numberCtrl.text.length < prevFormatted.length &&
        digits.length >= _lastDigits.length &&
        _lastDigits.isNotEmpty;
    if (isDeleting) {
      digits = _lastDigits.substring(0, _lastDigits.length - 1);
    }

    final formatted = _formatNsn(_selectedCountry.isoCode, digits);
    if (_numberCtrl.text != formatted) {
      _numberCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    if (digits != _lastDigits) {
      _lastDigits = digits;
      if (digits.isEmpty) {
        widget.onChanged?.call('');
      } else {
        widget.onChanged?.call('+${_selectedCountry.dialCode}$digits');
      }
    }

    _formatting = false;
  }

  void _onCountryChanged(CountryEntry entry) {
    _formatting = true;
    final digits = _numberCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    final maxLen = _maxNsnLength(entry.isoCode);
    final capped = digits.length > maxLen ? digits.substring(0, maxLen) : digits;
    setState(() => _selectedCountry = entry);
    _numberCtrl.value = TextEditingValue(
      text: _formatNsn(entry.isoCode, capped),
      selection: TextSelection.collapsed(
          offset: _formatNsn(entry.isoCode, capped).length),
    );
    _lastDigits = capped;
    _formatting = false;
    if (capped.isEmpty) {
      widget.onChanged?.call('');
    } else {
      widget.onChanged?.call('+${entry.dialCode}$capped');
    }
  }

  void _openPicker() async {
    final result = await showDialog<CountryEntry>(
      context: context,
      builder: (_) => CountryPickerDialog(
        countries: _countries,
        selected: _selectedCountry,
      ),
    );
    if (result != null && mounted) {
      _onCountryChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bColor = context.borderColor;
    final tColor = context.primaryTextColor;
    final enabled = widget.onChanged != null;

    return Row(
      children: [
        _buildPrefixButton(bColor, tColor, enabled),
        const SizedBox(width: Insets.small),
        Expanded(child: _buildNumberField(bColor, tColor, enabled)),
      ],
    );
  }

  Widget _buildPrefixButton(Color bColor, Color tColor, bool enabled) {
    return GestureDetector(
      onTap: enabled ? _openPicker : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: Insets.small),
        decoration: BoxDecoration(
          border: Border.all(color: bColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              _selectedCountry.isoCode.name,
              style: AppTextStyle.labelLarge.copyWith(color: tColor),
            ),
            if (enabled)
              Icon(Icons.expand_more,
                  size: 16, color: tColor.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(Color bColor, Color tColor, bool enabled) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: bColor, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _numberCtrl,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        style: AppTextStyle.labelLarge.copyWith(color: tColor),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.small,
            vertical: Insets.small,
          ),
          border: InputBorder.none,
          isDense: true,
          hintText: '+${_selectedCountry.dialCode}',
          hintStyle: AppTextStyle.labelLarge.copyWith(
            color: context.isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
