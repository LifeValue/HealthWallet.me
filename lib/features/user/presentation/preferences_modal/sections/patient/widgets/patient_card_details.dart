import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/utils/phone_formatter.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/records/domain/utils/fhir_field_extractor.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class PatientCardDetails extends StatelessWidget {
  final Patient displayPatient;
  final Patient currentPatient;
  final Color iconColor;
  final Color textColor;
  final bool isExpanding;
  final bool isCollapsing;
  final String bloodTypeDisplay;
  final VoidCallback onBloodTypeUpdated;

  const PatientCardDetails({
    super.key,
    required this.displayPatient,
    required this.currentPatient,
    required this.iconColor,
    required this.textColor,
    required this.isExpanding,
    required this.isCollapsing,
    required this.bloodTypeDisplay,
    required this.onBloodTypeUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: Insets.small),
        Container(
          height: 1,
          color: textColor.withValues(alpha: 0.1),
        ),
        const SizedBox(height: Insets.small),
        _buildIdentifierAndAgeRows(context),
        _buildGenderBloodAndContactRows(context),
        const SizedBox(height: Insets.small),
        _buildEditButton(context),
      ],
    );
  }

  Widget _buildIdentifierAndAgeRows(BuildContext context) {
    return AnimatedOpacity(
      duration: Duration(
        milliseconds:
            isExpanding ? 400 : (isCollapsing ? 600 : 200),
      ),
      opacity: (isExpanding || isCollapsing) ? 0.0 : 1.0,
      child: Column(
        children: [
          _buildPatientInfoRow(
            context,
            Assets.icons.identification.svg(
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                iconColor,
                BlendMode.srcIn,
              ),
            ),
            '${FhirFieldExtractor.extractPatientIdentifierLabel(displayPatient)}: ${FhirFieldExtractor.extractPatientMRN(displayPatient)}',
          ),
          _buildPatientInfoRow(
            context,
            Assets.icons.calendar.svg(
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                iconColor,
                BlendMode.srcIn,
              ),
            ),
            '${context.l10n.age}: ${FhirFieldExtractor.extractPatientAge(displayPatient)} (${_formatBirthDate(context, displayPatient)})',
          ),
        ],
      ),
    );
  }

  Widget _buildGenderBloodAndContactRows(BuildContext context) {
    return AnimatedOpacity(
      duration: Duration(
        milliseconds:
            isExpanding ? 600 : (isCollapsing ? 400 : 300),
      ),
      opacity: (isExpanding || isCollapsing) ? 0.0 : 1.0,
      child: Column(
        children: [
          _buildPatientInfoRow(
            context,
            _getGenderIcon(displayPatient),
            '${context.l10n.gender}: ${_formatGenderDisplay(context, FhirFieldExtractor.extractPatientGender(displayPatient))}',
          ),
          _buildPatientInfoRow(
            context,
            Assets.icons.drop.svg(
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                iconColor,
                BlendMode.srcIn,
              ),
            ),
            '${context.l10n.bloodType}: $bloodTypeDisplay',
          ),
          _buildEmergencyContactRow(context, displayPatient),
        ],
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return AnimatedOpacity(
      duration: Duration(
        milliseconds:
            isExpanding ? 800 : (isCollapsing ? 200 : 400),
      ),
      opacity: (isExpanding || isCollapsing) ? 0.0 : 1.0,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            context.read<PatientBloc>().add(
                  PatientEditStarted(currentPatient.id),
                );
            PatientEditDialog.show(
              context,
              currentPatient,
              onBloodTypeUpdated: onBloodTypeUpdated,
            );
          },
          icon: Assets.icons.edit.svg(
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
          label: Text(
            context.l10n.editDetails,
            style: AppTextStyle.buttonSmall,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.small,
              vertical: Insets.small,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getGenderIcon(Patient patient) {
    final gender = FhirFieldExtractor.extractPatientGender(patient);

    if (gender.toLowerCase() == 'female') {
      return Assets.icons.genderFemale.svg(
        width: 16,
        height: 16,
        colorFilter: ColorFilter.mode(
          iconColor,
          BlendMode.srcIn,
        ),
      );
    }

    return Assets.icons.genderMale.svg(
      width: 16,
      height: 16,
      colorFilter: ColorFilter.mode(
        iconColor,
        BlendMode.srcIn,
      ),
    );
  }

  String _formatGenderDisplay(BuildContext context, String? gender) {
    if (gender == null || gender.isEmpty) return context.l10n.homeNA;

    final lowerGender = gender.toLowerCase();

    switch (lowerGender) {
      case 'male':
        return context.l10n.male;
      case 'female':
        return context.l10n.female;
      case 'unknown':
      case 'prefer not to say':
      case 'prefer_not_to_say':
      case 'prefernottosay':
        return context.l10n.preferNotToSay;
      default:
        return gender;
    }
  }

  String _formatBirthDate(BuildContext context, Patient patient) {
    final birthDate = FhirFieldExtractor.extractPatientBirthDate(patient);
    if (birthDate == null) return patient.birthDate?.toString() ?? '';
    final region = context.read<UserBloc>().state.regionPreset;
    return DateFormatUtils.formatDate(birthDate, region);
  }

  Widget _buildEmergencyContactRow(BuildContext context, Patient patient) {
    final phone = FhirFieldExtractor.extractTelecomBySystem(
        patient.contact?.firstOrNull?.telecom, 'phone');
    final display = (phone != null && phone.isNotEmpty)
        ? PhoneDisplayFormatter.format(phone)
        : '-';

    return _buildPatientInfoRow(
      context,
      Icon(Icons.phone, size: 16, color: iconColor),
      '${context.l10n.emergencyContact}: $display',
    );
  }

  Widget _buildPatientInfoRow(BuildContext context, Widget icon, String text) {
    final rowTextColor = context.colorScheme.onSurface;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmall = screenWidth < 380;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Row(
        children: [
          icon,
          const SizedBox(width: Insets.smaller),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: isSmall
                  ? AppTextStyle.labelLarge.copyWith(
                      fontSize: 11,
                      color: rowTextColor,
                    )
                  : AppTextStyle.labelLarge.copyWith(
                      color: rowTextColor,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
