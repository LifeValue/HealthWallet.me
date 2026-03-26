import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/bloc/attach_to_encounter_bloc.dart';

class PatientSelector extends StatelessWidget {
  final String? title;

  const PatientSelector({
    super.key,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttachToEncounterBloc, AttachToEncounterState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'Patient & Source Information',
                style: AppTextStyle.bodyLarge.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildPatientBanner(context, state),
              _buildPatientSelector(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatientSelector(
      BuildContext context, AttachToEncounterState state) {
    final patient = state.patient;

    if (state.existingPatients.isEmpty && patient.draft == null) {
      return Text(
        'No patients available',
        style: AppTextStyle.bodySmall.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final items = <dynamic>[];
    if (patient.draft != null) {
      items.add(patient.draft);
    }
    items.addAll(state.existingPatients);

    String getDisplayText(dynamic item) {
      if (item is MappingPatient) {
        final name = "${item.familyName.value} ${item.givenName.value}";
        return "${context.l10n.newLabel}: $name";
      } else if (item is Patient) {
        return item.displayTitle;
      }
      return '';
    }

    final selectedValue = state.selectedPatient;
    final displayText = selectedValue != null
        ? getDisplayText(selectedValue)
        : 'Select patient';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patient',
          style: AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        AppDropdownField<dynamic>(
          value: displayText,
          items: items,
          getDisplayText: getDisplayText,
          onChanged: (dynamic newValue) {
            if (newValue == null) return;
            if (patient.mode == ImportMode.createNew &&
                patient.draft != null &&
                newValue is Patient) {
              AppSimpleDialog.showDestructiveConfirmation(
                context: context,
                title: context.l10n.dropModificationsTitle,
                message: context.l10n.dropModificationsMessage,
                confirmText: context.l10n.continueButton,
                cancelText: context.l10n.cancel,
                onConfirm: () {
                  context.read<AttachToEncounterBloc>().add(
                        AttachToEncounterPatientChanged(newValue),
                      );
                },
              );
              return;
            }
            context.read<AttachToEncounterBloc>().add(
                  AttachToEncounterPatientChanged(newValue),
                );
          },
        ),
      ],
    );
  }

  Widget _buildPatientBanner(
      BuildContext context, AttachToEncounterState state) {
    final patient = state.patient;
    final hasBoth = patient.draft != null && patient.existing != null;
    final isNew = patient.mode == ImportMode.createNew && patient.draft != null;
    final isExisting =
        patient.mode == ImportMode.linkExisting && patient.existing != null;

    if (isNew) {
      final name =
          '${patient.draft!.givenName.value} ${patient.draft!.familyName.value}'
              .trim();
      return _banner(
        context,
        icon: Icons.person_add_outlined,
        color: context.colorScheme.tertiary,
        text: name.isNotEmpty
            ? '${context.l10n.newPatient}: $name'
            : context.l10n.newPatient,
      );
    }

    if (isExisting && hasBoth) {
      final isSamePerson = patient.draft!.id == patient.existing!.id;
      if (isSamePerson) {
        return _banner(
          context,
          icon: Icons.edit_outlined,
          color: AppColors.warning,
          text: context.l10n.patientModifiedUpdating(
              patient.existing!.displayTitle),
        );
      }
      return _banner(
        context,
        icon: Icons.check_circle,
        color: context.colorScheme.primary,
        text: context.l10n.patientChangedTo(patient.existing!.displayTitle),
      );
    }

    if (isExisting) {
      return _banner(
        context,
        icon: Icons.check_circle,
        color: context.colorScheme.primary,
        text: context.l10n.patientMatchFound(patient.existing!.displayTitle),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _banner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.small),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.smallNormal,
          vertical: Insets.small,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Insets.small),
            Expanded(
              child: Text(
                text,
                style: AppTextStyle.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
