import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_input_field.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

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

/// Every country with a dial code, named in [languageCode] and sorted by
/// name, ignoring case and diacritics so "Österreich" sorts under O.
List<CountryEntry> buildCountryList(String languageCode) {
  final entries = <CountryEntry>[];
  for (final iso in IsoCode.values) {
    final meta = metadataByIsoCode[iso];
    if (meta == null) continue;
    entries.add(
      CountryEntry(
        isoCode: iso,
        dialCode: meta.countryCode,
        flag: _isoToFlag(iso.name),
        name: countryName(iso, languageCode),
      ),
    );
  }
  if (languageCode == 'en') {
    // The English names have no diacritics that change the order.
    entries.sort((a, b) => a.name.compareTo(b.name));
  } else {
    entries.sort((a, b) {
      final byKey = foldCountryName(a.name).compareTo(foldCountryName(b.name));
      return byKey != 0 ? byKey : a.name.compareTo(b.name);
    });
  }
  return entries;
}

const _foldedLetters = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ă': 'a',
  'ç': 'c',
  'č': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ș': 's',
  'ş': 's',
  'š': 's',
  'ț': 't',
  'ţ': 't',
  'ž': 'z',
  'ß': 'ss',
};

/// Lower-cases [name] and folds its diacritics ("Österreich" ->
/// "osterreich"), for sorting and searching country names.
String foldCountryName(String name) =>
    name.toLowerCase().split('').map((c) => _foldedLetters[c] ?? c).join();

String _isoToFlag(String code) {
  return code
      .toUpperCase()
      .codeUnits
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
  final String? defaultCountryCode;

  const PhoneInputField({
    super.key,
    required this.value,
    this.onChanged,
    this.defaultCountryCode,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  /// English names; only the iso code, flag and dial code of these are
  /// used. The picker lists the names in the app language.
  static final List<CountryEntry> _countries = buildCountryList('en');
  static final _localizedCountries = <String, List<CountryEntry>>{};
  late CountryEntry _selectedCountry;
  late TextEditingController _numberCtrl;
  bool _formatting = false;
  String _lastDigits = '';

  CountryEntry get _defaultCountry {
    if (widget.defaultCountryCode != null) {
      final match = _countries
          .where(
            (c) =>
                c.isoCode.name.toUpperCase() ==
                widget.defaultCountryCode!.toUpperCase(),
          )
          .firstOrNull;
      if (match != null) return match;
    }
    final countryCode = ui.PlatformDispatcher.instance.locale.countryCode
        ?.toUpperCase();
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
        final hasRealDigits = parsed.nsn
            .replaceAll(RegExp(r'0'), '')
            .isNotEmpty;
        if (!hasRealDigits && widget.defaultCountryCode != null) {
          _selectedCountry = _defaultCountry;
          _lastDigits = '';
          _numberCtrl = TextEditingController();
          return;
        }
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
      } catch (_) {
        // A saved number that no longer parses starts the field empty on the
        // default country, as a new number would.
      }
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
    final isDeleting =
        _numberCtrl.text.length < prevFormatted.length &&
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
    final capped = digits.length > maxLen
        ? digits.substring(0, maxLen)
        : digits;
    setState(() => _selectedCountry = entry);
    _numberCtrl.value = TextEditingValue(
      text: _formatNsn(entry.isoCode, capped),
      selection: TextSelection.collapsed(
        offset: _formatNsn(entry.isoCode, capped).length,
      ),
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
        countries: _localizedCountries.putIfAbsent(
          context.l10n.localeName,
          () => buildCountryList(context.l10n.localeName),
        ),
        selected: _selectedCountry,
      ),
    );
    if (result != null && mounted) {
      _onCountryChanged(result);
    }
  }

  String _getPlaceholder() {
    try {
      final example = PhoneNumber.parse(
        '+${_selectedCountry.dialCode}${'0' * _maxNsnLength(_selectedCountry.isoCode)}',
      );
      return example.formatNsn().replaceAll(RegExp(r'\d'), '0');
    } catch (_) {
      return '+${_selectedCountry.dialCode}';
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
        height: kInputFieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: Insets.small),
        decoration: BoxDecoration(
          border: Border.all(color: bColor, width: kInputBorderWidth),
          borderRadius: BorderRadius.circular(kInputBorderRadius),
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
              Icon(
                Icons.expand_more,
                size: 16,
                color: tColor.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(Color bColor, Color tColor, bool enabled) {
    return Container(
      height: kInputFieldHeight,
      decoration: BoxDecoration(
        border: Border.all(color: bColor, width: kInputBorderWidth),
        borderRadius: BorderRadius.circular(kInputBorderRadius),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _numberCtrl,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        style: inputFieldTextStyle(context),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.smallNormal,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isCollapsed: true,
          hintText: _getPlaceholder(),
          hintStyle: AppTextStyle.labelLarge.copyWith(
            color: context.isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
