import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/features/scan/presentation/widgets/patient_modified_banner.dart';
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
import 'package:health_wallet/core/config/constants/region_preset.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ResourcesForm extends StatefulWidget {
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
  State<ResourcesForm> createState() => _ResourcesFormState();
}

class _ResourcesFormState extends State<ResourcesForm> {
  int _patientVersion = 0;
  bool _hadDraft = false;

  @override
  void didUpdateWidget(ResourcesForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasDraft = widget.patient?.draft != null;
    if (_hadDraft && !hasDraft) {
      _patientVersion++;
    }
    _hadDraft = hasDraft;
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final encounter = widget.encounter;
    final diagnosticReport = widget.diagnosticReport;
    final resources = widget.resources;
    final sessionId = widget.sessionId;

    return GestureDetector(
      onTap: () => context.closeKeyboard(),
      behavior: HitTestBehavior.opaque,
      child: Form(
        key: widget.formKey,
        child: Column(
          children: [
            if (patient?.hasSelection == true)
              _buildResourceForm(
                context,
                resource: _resolvePatient(patient!),
                canRemove: false,
                isStagedResource: true,
                isLocked: widget.isAttachmentLocked,
                patientVersion: _patientVersion,
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
                key: widget.encounterSectionKey,
                child: _buildResourceForm(
                  context,
                  canRemove: false,
                  resource: diagnosticReport!.draft!,
                  isStagedResource: true,
                  isLocked: widget.isAttachmentLocked,
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
                key: widget.encounterSectionKey,
                child: _buildResourceForm(
                  context,
                  canRemove: false,
                  resource: encounter!.mode == ImportMode.createNew
                      ? encounter!.draft!
                      : MappingEncounter.fromFhirResource(encounter!.existing!),
                  isStagedResource: true,
                  isLocked: widget.isAttachmentLocked,
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
    int patientVersion = 0,
    bool isStagedResource = false,
    bool isLocked = false,
  }) {
    Map<String, TextFieldDescriptor> textFields =
        resource.getFieldDescriptors();

    return Container(
      key: ValueKey('${resource.id}_v$patientVersion'),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? context.colorScheme.primary.withValues(alpha: 0.4)
                : context.theme.dividerColor,
          ),
          color: isLocked
              ? context.colorScheme.primary.withValues(alpha: 0.04)
              : null),
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
                        resource is! MappingEncounter &&
                        resource is! MappingDiagnosticReport)
                      Padding(
                        padding: const EdgeInsetsGeometry.all(6),
                        child: GestureDetector(
                          onTap: () => _openAttachDialog(context),
                          child: Assets.icons.attachment.svg(
                              width: 20,
                              color: context.theme.iconTheme.color ??
                                  context.colorScheme.onSurface),
                        ),
                      ),
                    if (isStagedResource &&
                        (resource is MappingEncounter ||
                            resource is MappingDiagnosticReport))
                      Padding(
                        padding: const EdgeInsetsGeometry.all(6),
                        child: GestureDetector(
                          onTap: () => context.read<ScanBloc>().add(
                                ScanContainerTypeSwitched(sessionId: widget.sessionId),
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
            if (resource is MappingPatient && widget.patient != null)
              _buildPatientMatchBanner(context, widget.patient!),
            const SizedBox(height: Insets.normal),
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
                  if (descriptor.fieldType == FieldType.date)
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
                                            ? _formatDateForDisplay(
                                                descriptor.value, context)
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
                      onChanged: (String newValue) {
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

  String _formatDateForDisplay(String isoDate, BuildContext context) {
    final region = context.read<UserBloc>().state.regionPreset;
    return DateFormatUtils.formatIsoForDisplay(isoDate, region);
  }

  Future<String?> _showDatePicker(
    BuildContext context,
    String propertyKey,
    String currentValue,
    Function(String, String)? onPropertyChanged,
  ) async {
    final initialDate =
        DateFormatUtils.tryParseIso(currentValue) ?? DateTime.now();

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
      final formattedDate = DateFormatUtils.isoCompact(pickedDate);
      onPropertyChanged(propertyKey, formattedDate);
      return formattedDate;
    }
    return null;
  }

  void _swapPatient(
      BuildContext context, StagedPatient patient, ImportMode targetMode) {
    context.read<ScanBloc>().add(
          ScanEncounterAttached(
            sessionId: widget.sessionId,
            patient: StagedPatient(
              draft: patient.draft,
              existing: patient.existing,
              mode: targetMode,
            ),
            encounter: widget.encounter ?? const StagedEncounter(),
          ),
        );
  }

  Future<void> _openAttachDialog(BuildContext context) async {
    final result = await showDialog<AttachToEncounterResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AttachToEncounterWidget(
        patient: widget.patient,
        encounter: widget.encounter,
        confirmText: context.l10n.save,
      ),
    );
    if (result == null || !context.mounted) return;

    final (patient, encounter) = result;
    context.read<ScanBloc>().add(
          ScanEncounterAttached(
            sessionId: widget.sessionId,
            patient: patient,
            encounter: encounter,
          ),
        );
  }

  MappingPatient _resolvePatient(StagedPatient patient) {
    if (patient.draft != null && patient.existing != null) {
      final isSamePerson = patient.draft!.id == patient.existing!.id;
      if (isSamePerson || patient.mode == ImportMode.createNew) {
        return patient.draft!;
      }
      return MappingPatient.fromFhirResource(patient.existing!);
    }
    if (patient.draft != null) {
      return patient.draft!;
    }
    if (patient.existing != null) {
      return MappingPatient.fromFhirResource(patient.existing!);
    }
    return const MappingPatient();
  }

  Widget _buildPatientMatchBanner(BuildContext context, StagedPatient patient) {
    final hasBoth = patient.draft != null && patient.existing != null;
    final isNewPatient = patient.existing == null && patient.draft != null;
    final isNewWithExisting = hasBoth && patient.mode == ImportMode.createNew;
    final isModified = hasBoth && patient.mode == ImportMode.linkExisting;

    if (isNewPatient) {
      final draftName = patient.draft != null
          ? '${patient.draft!.givenName.value} ${patient.draft!.familyName.value}'
              .trim()
          : '';
      return _buildBanner(
        context,
        icon: Icons.person_add_outlined,
        color: context.colorScheme.tertiary,
        text: draftName.isNotEmpty
            ? '${context.l10n.newPatient}: $draftName'
            : context.l10n.newPatient,
      );
    }

    if (isNewWithExisting) {
      final draftName = patient.draft != null
          ? '${patient.draft!.givenName.value} ${patient.draft!.familyName.value}'
              .trim()
          : '';
      return _buildBanner(
        context,
        icon: Icons.person_add_outlined,
        color: context.colorScheme.tertiary,
        text: draftName.isNotEmpty
            ? '${context.l10n.newPatient}: $draftName'
            : context.l10n.newPatient,
        onAction: () => _swapPatient(context, patient, ImportMode.linkExisting),
        actionIcon: Icons.swap_horiz,
      );
    }

    final displayName = patient.existing!.displayTitle;

    if (isModified) {
      final isSamePerson = patient.draft!.id == patient.existing!.id;

      if (isSamePerson && widget.isAttachmentLocked) {
        return _buildBanner(
          context,
          icon: Icons.save_outlined,
          color: AppColors.success,
          text: context.l10n.patientSavingModified(displayName),
          onAction: () => context.read<ScanBloc>().add(
                ScanPatientReverted(sessionId: widget.sessionId),
              ),
        );
      }

      if (isSamePerson) {
        return Padding(
          padding: const EdgeInsets.only(top: Insets.small),
          child: PatientModifiedBanner(
            patientName: displayName,
            onRevert: () => context.read<ScanBloc>().add(
                  ScanPatientReverted(sessionId: widget.sessionId),
                ),
          ),
        );
      }

      return _buildBanner(
        context,
        leadingIcon: Assets.icons.information.svg(
          width: 16,
          height: 16,
          colorFilter: ColorFilter.mode(
            context.colorScheme.secondary,
            BlendMode.srcIn,
          ),
        ),
        color: context.colorScheme.secondary,
        text: context.l10n.patientChangedTo(displayName),
        onAction: () => _swapPatient(context, patient, ImportMode.createNew),
        actionIcon: Icons.swap_horiz,
      );
    }

    return _buildBanner(
      context,
      icon: Icons.check_circle,
      color: context.colorScheme.primary,
      text: context.l10n.patientMatchFound(displayName),
    );
  }

  Widget _buildBanner(
    BuildContext context, {
    IconData? icon,
    Widget? leadingIcon,
    required Color color,
    required String text,
    VoidCallback? onAction,
    IconData? actionIcon,
  }) {
    final trailingIcon = actionIcon ?? Icons.close;
    final leading = leadingIcon ?? Icon(icon, size: 16, color: color);
    final banner = Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: Insets.smallNormal,
        top: Insets.extraSmall,
        bottom: Insets.extraSmall,
        right: onAction != null ? Insets.extraSmall : Insets.smallNormal,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          leading,
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
          if (onAction != null)
            Padding(
              padding: const EdgeInsets.all(Insets.extraSmall),
              child: Icon(trailingIcon, size: 14, color: color),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: Insets.small),
      child: onAction != null
          ? GestureDetector(onTap: onAction, child: banner)
          : banner,
    );
  }
}
