import 'package:flutter/material.dart';
import 'package:health_wallet/core/config/constants/country_identifier.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'date_field.dart';
import 'form_fields.dart';
import 'phone_input_field.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class DialogContent extends StatelessWidget {
  final Patient patient;
  final String? selectedGiven;
  final String? selectedFamily;
  final String? selectedIdentifier;
  final String? selectedContactPhone;
  final DateTime? selectedBirthDate;
  final String selectedGender;
  final String selectedBloodType;
  final List<String> genderOptions;
  final List<String> bloodTypeOptions;
  final Color iconColor;
  final bool showNameField;
  final bool isSetupMode;
  final bool isScanning;
  final bool scanCompleted;
  final ValueChanged<String>? onGivenChanged;
  final ValueChanged<String>? onFamilyChanged;
  final ValueChanged<String>? onIdentifierChanged;
  final ValueChanged<String>? onContactPhoneChanged;
  final ValueChanged<DateTime?>? onBirthDateChanged;
  final ValueChanged<String>? onGenderChanged;
  final ValueChanged<String>? onBloodTypeChanged;
  final VoidCallback? onScanIdCard;
  final VoidCallback? onPickFromGallery;
  final VoidCallback? onRetryOcr;
  final ValueChanged<String>? onCountryChanged;
  final String? selectedCountryCode;
  final TextEditingController? givenController;
  final TextEditingController? familyController;
  final TextEditingController? identifierController;
  final String identifierLabel;
  const DialogContent({
    super.key,
    required this.patient,
    this.selectedGiven,
    this.selectedFamily,
    this.selectedIdentifier,
    this.selectedContactPhone,
    required this.selectedBirthDate,
    required this.selectedGender,
    required this.selectedBloodType,
    required this.genderOptions,
    required this.bloodTypeOptions,
    required this.iconColor,
    this.showNameField = false,
    this.isSetupMode = false,
    this.isScanning = false,
    this.scanCompleted = false,
    this.onGivenChanged,
    this.onFamilyChanged,
    this.onIdentifierChanged,
    this.onContactPhoneChanged,
    this.onBirthDateChanged,
    this.onGenderChanged,
    this.onBloodTypeChanged,
    this.onScanIdCard,
    this.onPickFromGallery,
    this.onRetryOcr,
    this.onCountryChanged,
    this.selectedCountryCode,
    this.givenController,
    this.familyController,
    this.identifierController,
    this.identifierLabel = 'ID',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!showNameField)
            Text(patient.displayTitle,
                style: AppTextStyle.bodyMedium
                    .copyWith(fontWeight: FontWeight.w500)),
          if (!showNameField) const SizedBox(height: Insets.medium),
          if (showNameField && onCountryChanged != null) ...[
            _CountrySelector(
              selectedCountryCode: selectedCountryCode,
              onChanged: onCountryChanged!,
            ),
            const SizedBox(height: Insets.normal),
          ],
          if (showNameField && onScanIdCard != null) ...[
            _ScanIdCardButton(
              onTap: onScanIdCard!,
              onPickFromGallery: onPickFromGallery,
              onRetryOcr: onRetryOcr,
              isScanning: isScanning,
              scanCompleted: scanCompleted,
            ),
            const SizedBox(height: Insets.normal),
          ],
          if (showNameField) ...[
            Row(
              children: [
                Expanded(
                  child: FormFields.buildTextField(
                    context,
                    context.l10n.givenName,
                    isSetupMode ? '' : (selectedGiven ?? ''),
                    onGivenChanged,
                    controller: givenController,
                    hintText: isSetupMode ? context.l10n.givenName : null,
                  ),
                ),
                const SizedBox(width: Insets.small),
                Expanded(
                  child: FormFields.buildTextField(
                    context,
                    context.l10n.familyName,
                    isSetupMode ? '' : (selectedFamily ?? ''),
                    onFamilyChanged,
                    controller: familyController,
                    hintText: isSetupMode ? context.l10n.familyName : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.normal),
            FormFields.buildTextField(
              context,
              identifierLabel,
              isSetupMode ? '' : (selectedIdentifier ?? ''),
              onIdentifierChanged,
              controller: identifierController,
              hintText: isSetupMode ? '$identifierLabel (optional)' : null,
            ),
            const SizedBox(height: Insets.normal),
          ],
          DateField(
            label: context.l10n.age,
            selectedDate: selectedBirthDate,
            onDateChanged: onBirthDateChanged,
            iconColor: iconColor,
          ),
          const SizedBox(height: Insets.normal),
          FormFields.buildDropdownField(
            context,
            context.l10n.gender,
            selectedGender,
            genderOptions,
            onGenderChanged,
          ),
          const SizedBox(height: Insets.normal),
          FormFields.buildDropdownField(
            context,
            context.l10n.bloodType,
            selectedBloodType,
            bloodTypeOptions,
            onBloodTypeChanged,
          ),
          if (showNameField) ...[
            const SizedBox(height: Insets.normal),
            FormFields.buildFieldLabel(context, context.l10n.emergencyContact),
            PhoneInputField(
              key: ValueKey('phone_${selectedCountryCode ?? ''}'),
              value: selectedContactPhone ?? '',
              defaultCountryCode: selectedCountryCode,
              onChanged: onContactPhoneChanged != null
                  ? (val) => onContactPhoneChanged!(val)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _CountrySelector extends StatelessWidget {
  final String? selectedCountryCode;
  final ValueChanged<String> onChanged;

  static const _countries = <String, String>{
    'AT': '🇦🇹 Austria',
    'FR': '🇫🇷 France',
    'DE': '🇩🇪 Germany',
    'IT': '🇮🇹 Italy',
    'NL': '🇳🇱 Netherlands',
    'PL': '🇵🇱 Poland',
    'RO': '🇷🇴 Romania',
    'ES': '🇪🇸 Spain',
    'SE': '🇸🇪 Sweden',
    'CH': '🇨🇭 Switzerland',
    'GB': '🇬🇧 United Kingdom',
    'US': '🇺🇸 United States',
  };

  const _CountrySelector({
    required this.selectedCountryCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLabel = _countries[selectedCountryCode] ?? _countries['US']!;
    final countryItems = _countries.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFields.buildDropdownField(
          context,
          context.l10n.country,
          currentLabel,
          countryItems,
          (value) {
            final code = _countries.entries
                .firstWhere((e) => e.value == value,
                    orElse: () => const MapEntry('US', ''))
                .key;
            onChanged(code);
          },
        ),
      ],
    );
  }
}

class _ScanIdCardButton extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onPickFromGallery;
  final VoidCallback? onRetryOcr;
  final bool isScanning;
  final bool scanCompleted;

  const _ScanIdCardButton({
    required this.onTap,
    this.onPickFromGallery,
    this.onRetryOcr,
    this.isScanning = false,
    this.scanCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      return _buildContainer(
        context,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Insets.small),
            Text(
              context.l10n.loading,
              style: AppTextStyle.labelSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (scanCompleted) {
      final buttonStyle = OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(
          vertical: Insets.small,
          horizontal: Insets.small,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTextStyle.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormFields.buildFieldLabel(context, context.l10n.scanIdCard),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.camera_alt_outlined, size: 14),
                  label: Text(context.l10n.retry),
                  style: buttonStyle,
                ),
              ),
              const SizedBox(width: Insets.small),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetryOcr,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: Text(context.l10n.retry),
                  style: buttonStyle,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(
        vertical: Insets.small,
        horizontal: Insets.small,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: AppTextStyle.labelSmall.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return _buildContainer(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.scanIdCard,
            style: AppTextStyle.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            context.l10n.scanIdCardDescription,
            style: AppTextStyle.regular.copyWith(
              color: context.isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: Insets.small),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.camera_alt_outlined, size: 14),
                  label: Text(context.l10n.documentScanTitle),
                  style: buttonStyle,
                ),
              ),
              if (onPickFromGallery != null) ...[
                const SizedBox(width: Insets.small),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 14),
                    label: Text(context.l10n.attachFile),
                    style: buttonStyle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContainer(BuildContext context, {required Widget child}) {
    final borderColor = context.isDarkMode
        ? AppColors.borderDark
        : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.normal,
        vertical: Insets.smallNormal,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: child,
    );
  }
}
