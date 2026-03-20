import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_date_picker.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';
import 'package:health_wallet/core/widgets/dialogs/delete_confirmation_dialog.dart';
import 'package:health_wallet/features/user/domain/utils/gender_mapper.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';

class ResourcesForm extends StatelessWidget {
  const ResourcesForm({
    required this.resources,
    required this.sessionId,
    required this.formKey,
    this.encounterSectionKey,
    this.encounter,
    this.diagnosticReport,
    this.patient,
    this.isAttachmentLocked = false,
    super.key,
  });

  final List<MappingResource> resources;
  final String sessionId;
  final GlobalKey<FormState> formKey;
  final GlobalKey? encounterSectionKey;
  final StagedPatient? patient;
  final StagedEncounter? encounter;
  final StagedDiagnosticReport? diagnosticReport;
  final bool isAttachmentLocked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.closeKeyboard(),
      behavior: HitTestBehavior.opaque,
      child: Form(
        key: formKey,
        child: Column(
          children: [
            if (patient?.hasSelection == true)
              _buildResourceForm(
                context,
                resource: patient!.draft ??
                    MappingPatient.fromFhirResource(patient!.existing!),
                canRemove: false,
                isStagedResource: true,
                isReadOnly: isAttachmentLocked,
                onPropertyChanged: (propertyKey, newValue) =>
                    context.read<ScanBloc>().add(
                          ScanResourceChanged(
                            sessionId: sessionId,
                            index: 0,
                            propertyKey: propertyKey,
                            newValue: newValue,
                            isDraftPatient: true,
                          ),
                        ),
              ),
            if (diagnosticReport?.hasSelection == true)
              KeyedSubtree(
                key: encounterSectionKey,
                child: _buildResourceForm(
                  context,
                  canRemove: false,
                  resource: diagnosticReport!.draft!,
                  isStagedResource: true,
                  isReadOnly: isAttachmentLocked,
                  onPropertyChanged: (propertyKey, newValue) =>
                      context.read<ScanBloc>().add(
                            ScanResourceChanged(
                              sessionId: sessionId,
                              index: 0,
                              propertyKey: propertyKey,
                              newValue: newValue,
                              isDraftDiagnosticReport: true,
                            ),
                          ),
                ),
              )
            else if (encounter?.hasSelection == true)
              KeyedSubtree(
                key: encounterSectionKey,
                child: _buildResourceForm(
                  context,
                  canRemove: false,
                  resource: encounter!.mode == ImportMode.createNew
                      ? encounter!.draft!
                      : MappingEncounter.fromFhirResource(encounter!.existing!),
                  isStagedResource: true,
                  isReadOnly: isAttachmentLocked ||
                      encounter!.mode == ImportMode.linkExisting,
                  onPropertyChanged: (propertyKey, newValue) =>
                      context.read<ScanBloc>().add(
                            ScanResourceChanged(
                              sessionId: sessionId,
                              index: 0,
                              propertyKey: propertyKey,
                              newValue: newValue,
                              isDraftEncounter: true,
                            ),
                          ),
                ),
              ),
            ...resources.indexed.map((entry) {
              final (index, resource) = entry;

              return KeyedSubtree(
                key: ValueKey('remaining_${resource.id}_$index'),
                child: _buildResourceForm(
                  context,
                  resource: resource,
                  onPropertyChanged: (propertyKey, newValue) =>
                      context.read<ScanBloc>().add(
                            ScanResourceChanged(
                              sessionId: sessionId,
                              index: index,
                              propertyKey: propertyKey,
                              newValue: newValue,
                            ),
                          ),
                  onResourceRemoved: () => DeleteConfirmationDialog.show(
                    context: context,
                    title: 'Delete Resources',
                    onConfirm: () {
                      context.read<ScanBloc>().add(ScanResourceRemoved(
                          sessionId: sessionId, index: index));
                    },
                  ),
                ),
              );
            })
          ],
        ),
      ),
    );
  }

  Widget _buildResourceForm(
    BuildContext context, {
    required MappingResource resource,
    Function(String, String)? onPropertyChanged,
    bool canRemove = true,
    Function? onResourceRemoved,
    bool isStagedResource = false,
    bool isReadOnly = false,
  }) {
    Map<String, TextFieldDescriptor> textFields =
        resource.getFieldDescriptors();

    return Container(
      key: ValueKey(resource.id),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.theme.dividerColor)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(Insets.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(resource.label, style: AppTextStyle.bodyLarge),
                Row(
                  children: [
                    if (isStagedResource &&
                        !isAttachmentLocked &&
                        resource is! MappingEncounter &&
                        resource is! MappingDiagnosticReport)
                      Padding(
                        padding: const EdgeInsetsGeometry.all(6),
                        child: GestureDetector(
                          onTap: () async {
                            final result =
                                await showDialog<AttachToEncounterResult>(
                              context: context,
                              builder: (context) => AttachToEncounterWidget(
                                patient: this.patient,
                                encounter: this.encounter,
                              ),
                            );
                            if (result == null || !context.mounted) return;

                            final (patient, encounter) = result;
                            context.read<ScanBloc>().add(
                                  ScanEncounterAttached(
                                    sessionId: sessionId,
                                    patient: patient,
                                    encounter: encounter,
                                  ),
                                );
                          },
                          child: Assets.icons.attachment.svg(
                              width: 20,
                              color: context.theme.iconTheme.color ??
                                  context.colorScheme.onSurface),
                        ),
                      ),
                    if (isStagedResource &&
                        !isAttachmentLocked &&
                        (resource is MappingEncounter ||
                            resource is MappingDiagnosticReport))
                      Padding(
                        padding: const EdgeInsetsGeometry.all(6),
                        child: GestureDetector(
                          onTap: () => context.read<ScanBloc>().add(
                                ScanContainerTypeSwitched(sessionId: sessionId),
                              ),
                          child: Tooltip(
                            message: resource is MappingEncounter
                                ? 'Switch to Diagnostic Report'
                                : 'Switch to Encounter',
                            child: Icon(
                              Icons.swap_horiz,
                              size: 20,
                              color: context.theme.iconTheme.color ??
                                  context.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    if (canRemove)
                      Padding(
                        padding: const EdgeInsetsGeometry.all(6),
                        child: GestureDetector(
                          onTap: () => onResourceRemoved?.call(),
                          child: Assets.icons.trashCan.svg(
                              width: 20,
                              color: context.theme.iconTheme.color ??
                                  context.colorScheme.onSurface),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (resource is MappingPatient && patient?.existing != null)
              _buildPatientMatchBanner(context, patient!),
            const SizedBox(height: 24),
            ...textFields.entries.map((entry) {
              final propertyKey = entry.key;
              final descriptor = entry.value;

              final confidenceLevel =
                  ConfidenceLevel.fromDouble(descriptor.confidenceLevel);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(descriptor.label, style: AppTextStyle.bodySmall),
                          if (descriptor.fieldType == FieldType.date &&
                              descriptor.value.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.error_outline,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                      if (confidenceLevel != ConfidenceLevel.high)
                        Text(
                          "(${confidenceLevel.getString()})",
                          style: AppTextStyle.labelSmall.copyWith(
                              color: confidenceLevel.getColor(context),
                              fontStyle: FontStyle.italic),
                        )
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isReadOnly)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: confidenceLevel.getColor(context)),
                        borderRadius: BorderRadius.circular(8),
                        color: confidenceLevel
                            .getColor(context)
                            .withValues(alpha: 0.08),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Text(
                        descriptor.value,
                        style: AppTextStyle.labelLarge,
                      ),
                    )
                  else if (descriptor.fieldType == FieldType.date)
                    FormField<String>(
                      key: ValueKey(
                          '${resource.id}_${propertyKey}_form_${descriptor.value}'),
                      initialValue: descriptor.value,
                      validator: (value) {
                        final error = descriptor.validate(value);
                        if (error != null &&
                            error == 'This field cannot be empty') {
                          return context.l10n.fieldCannotBeEmpty;
                        }
                        return error;
                      },
                      onSaved: (value) {
                        if (value != null &&
                            value != descriptor.value &&
                            onPropertyChanged != null) {
                          onPropertyChanged(propertyKey, value);
                        }
                      },
                      builder: (field) {
                        final hasError = field.hasError;
                        final errorText = field.errorText;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () async {
                                final newValue = await _showDatePicker(
                                  context,
                                  propertyKey,
                                  descriptor.value,
                                  onPropertyChanged,
                                );
                                if (newValue != null) {
                                  field.didChange(newValue);
                                  field.validate();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: hasError
                                        ? Colors.red
                                        : confidenceLevel.getColor(context),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        descriptor.value.isNotEmpty
                                            ? descriptor.value
                                            : context.l10n.selectDate,
                                        style: AppTextStyle.labelLarge.copyWith(
                                          color: descriptor.value.isNotEmpty
                                              ? (context.isDarkMode
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimary)
                                              : (context.isDarkMode
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Assets.icons.calendar.svg(
                                      width: 16,
                                      height: 16,
                                      colorFilter: ColorFilter.mode(
                                        context.theme.iconTheme.color ??
                                            context.colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (hasError && errorText != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4, left: 12),
                                child: Text(
                                  errorText,
                                  style: AppTextStyle.labelSmall.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    )
                  else if (descriptor.fieldType == FieldType.dropdown)
                    AppDropdownField<String>(
                      value: _getGenderDisplayValue(descriptor.value, context),
                      items: [
                        context.l10n.male,
                        context.l10n.female,
                        context.l10n.preferNotToSay,
                      ],
                      getDisplayText: (item) => item,
                      onChanged: isReadOnly
                          ? null
                          : (String newValue) {
                              final fhirValue =
                                  _mapDisplayGenderToFhir(newValue, context);
                              onPropertyChanged?.call(propertyKey, fhirValue);
                            },
                    )
                  else
                    TextFormField(
                      key: ValueKey('${resource.id}_$propertyKey'),
                      initialValue: descriptor.value,
                      validator: descriptor.validate,
                      inputFormatters: descriptor.inputFormatters,
                      keyboardType: descriptor.keyboardType,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      style: AppTextStyle.labelLarge,
                      onChanged: (value) =>
                          onPropertyChanged?.call(propertyKey, value),
                      decoration: InputDecoration(
                        isDense: true,
                        helperText: ' ',
                        helperStyle: const TextStyle(height: 0, fontSize: 0),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: confidenceLevel.getColor(context)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: confidenceLevel.getColor(context)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: confidenceLevel.getColor(context)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.red, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  if (entry.key != textFields.entries.last.key)
                    const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getGenderDisplayValue(String fhirValue, BuildContext context) {
    if (fhirValue.isEmpty) {
      return context.l10n.preferNotToSay;
    }
    return GenderMapper.mapFhirGenderToDisplay(fhirValue, context.l10n);
  }

  String _mapDisplayGenderToFhir(String displayValue, BuildContext context) {
    if (displayValue == context.l10n.male) {
      return 'male';
    } else if (displayValue == context.l10n.female) {
      return 'female';
    } else {
      return 'unknown';
    }
  }

  Future<String?> _showDatePicker(
    BuildContext context,
    String propertyKey,
    String currentValue,
    Function(String, String)? onPropertyChanged,
  ) async {
    DateTime? initialDate;
    if (currentValue.isNotEmpty) {
      initialDate = DateTime.tryParse(currentValue);
      if (initialDate == null) {
        try {
          final dateFormat = DateFormat('yyyy-MM-dd');
          initialDate = dateFormat.parse(currentValue);
        } catch (e) {
          initialDate = null;
        }
      }
    }
    if (initialDate == null) {
      initialDate = DateTime.now();
    }

    DateTime? firstDate;
    DateTime? lastDate;

    if (propertyKey == 'dateOfBirth') {
      firstDate = DateTime(1900);
      lastDate = DateTime.now();
    } else if (propertyKey == 'periodStart') {
      firstDate = DateTime(1900);
      lastDate = DateTime.now();
    }

    final pickedDate = await AppDatePicker.show(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null && onPropertyChanged != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
      onPropertyChanged(propertyKey, formattedDate);
      return formattedDate;
    }
    return null;
  }

  Widget _buildPatientMatchBanner(BuildContext context, StagedPatient patient) {
    final isModified = patient.mode == ImportMode.createNew && patient.existing != null;
    final color = isModified ? AppColors.warning : context.colorScheme.primary;
    final icon = isModified ? Icons.person_add : Icons.check_circle;
    final text = isModified
        ? context.l10n.patientModifiedNewWillBeCreated
        : context.l10n.patientMatchFound(patient.existing!.displayTitle);

    return Padding(
      padding: const EdgeInsets.only(top: Insets.small),
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
            Icon(
              icon,
              size: 16,
              color: color,
            ),
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
