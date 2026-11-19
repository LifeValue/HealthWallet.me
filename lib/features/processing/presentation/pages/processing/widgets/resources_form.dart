import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/widgets/app_date_picker.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';
import 'package:health_wallet/core/widgets/dialogs/delete_confirmation_dialog.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_diagnostic_report.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/processing/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/processing/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/features/user/domain/utils/gender_mapper.dart';
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
                resource: patient!.shown,
                canRemove: false,
                isStagedResource: true,
                isLocked: widget.isAttachmentLocked,
                patientVersion: _patientVersion,
                onPropertyChanged: (propertyKey, newValue) =>
                    context.read<ProcessingBloc>().add(
                      ResourceChanged(
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
                      context.read<ProcessingBloc>().add(
                        ResourceChanged(
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
                      ? encounter.draft!
                      : MappingEncounter.fromFhirResource(encounter.existing!),
                  walletNote: !encounter.isExistingVisit
                      ? null
                      : encounter.completesExistingVisit
                      ? context.l10n.stagedWillBeCompleted
                      : context.l10n.stagedAlreadyInWallet,
                  isStagedResource: true,
                  isLocked: widget.isAttachmentLocked,
                  onPropertyChanged: (propertyKey, newValue) =>
                      context.read<ProcessingBloc>().add(
                        ResourceChanged(
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
                  walletNote: switch (resource) {
                    MappingVisionPrescription(
                      existingId: final id,
                      :final completesExisting,
                    )
                        when id.isNotEmpty =>
                      completesExisting
                          ? context.l10n.stagedWillBeCompleted
                          : context.l10n.stagedAlreadyInWallet,
                    _ => null,
                  },
                  onPropertyChanged: (propertyKey, newValue) =>
                      context.read<ProcessingBloc>().add(
                        ResourceChanged(
                          sessionId: sessionId,
                          index: index,
                          propertyKey: propertyKey,
                          newValue: newValue,
                        ),
                      ),
                  onResourceRemoved: () => DeleteConfirmationDialog.show(
                    context: context,
                    title: context.l10n.deleteResourcesTitle,
                    onConfirm: () {
                      context.read<ProcessingBloc>().add(
                        ResourceRemoved(sessionId: sessionId, index: index),
                      );
                    },
                  ),
                ),
              );
            }),
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
    String? walletNote,
  }) {
    final Map<String, TextFieldDescriptor> textFields = resource
        .getFieldDescriptors(context.l10n);
    // A record already in the wallet is only completed, never changed, so
    // its fields can't be edited here, nor hold up saving the rest.
    final readOnly = walletNote != null;
    final locked = isLocked || readOnly;

    return Container(
      key: ValueKey('${resource.id}_v$patientVersion'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked
              ? context.colorScheme.primary.withValues(alpha: 0.4)
              : context.theme.dividerColor,
        ),
        color: locked
            ? context.colorScheme.primary.withValues(alpha: 0.04)
            : null,
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(Insets.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  resource.localizedLabel(context.l10n),
                  style: AppTextStyle.bodyLarge,
                ),
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
                            color:
                                context.theme.iconTheme.color ??
                                context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    if (isStagedResource &&
                        (resource is MappingEncounter ||
                            resource is MappingDiagnosticReport))
                      Padding(
                        padding: const EdgeInsetsGeometry.all(6),
                        child: GestureDetector(
                          onTap: () => context.read<ProcessingBloc>().add(
                            ContainerTypeSwitched(sessionId: widget.sessionId),
                          ),
                          child: Tooltip(
                            message: resource is MappingEncounter
                                ? context.l10n.switchToDiagnosticReport
                                : context.l10n.switchToEncounter,
                            child: Icon(
                              Icons.swap_horiz,
                              size: 20,
                              color:
                                  context.theme.iconTheme.color ??
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
                            color:
                                context.theme.iconTheme.color ??
                                context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (resource is MappingPatient && widget.patient != null)
              _buildPatientMatchBanner(context, widget.patient!),
            if (walletNote != null)
              _buildBanner(
                context,
                icon: Icons.inventory_2_outlined,
                color: context.colorScheme.primary,
                text: walletNote,
              ),
            if (resource is MappingVisionPrescription)
              IgnorePointer(
                ignoring: readOnly,
                child: _buildLensGrid(
                  context,
                  resource,
                  readOnly: readOnly,
                  onPropertyChanged: onPropertyChanged,
                ),
              ),
            const SizedBox(height: Insets.normal),
            ...textFields.entries.map((entry) {
              final propertyKey = entry.key;
              final descriptor = entry.value;

              final confidenceLevel = descriptor.confidence;

              return IgnorePointer(
                ignoring: readOnly,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              descriptor.label,
                              style: AppTextStyle.bodySmall,
                            ),
                            if (descriptor.fieldType == FieldType.date &&
                                descriptor.value.isEmpty &&
                                descriptor.isRequired)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
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
                            '(${confidenceLevel.localizedName(context.l10n)})',
                            style: AppTextStyle.labelSmall.copyWith(
                              color: confidenceLevel.getColor(context),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (descriptor.fieldType == FieldType.date)
                      FormField<String>(
                        key: ValueKey(
                          '${resource.id}_${propertyKey}_form_${descriptor.value}',
                        ),
                        initialValue: descriptor.value,
                        validator: (value) => readOnly
                            ? null
                            : descriptor.validate(value)?.message(context.l10n),
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
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          descriptor.value.isNotEmpty
                                              ? _formatDateForDisplay(
                                                  descriptor.value,
                                                  context,
                                                )
                                              : context.l10n.selectDate,
                                          style: AppTextStyle.labelLarge.copyWith(
                                            color: descriptor.value.isNotEmpty
                                                ? (context.isDarkMode
                                                      ? AppColors
                                                            .textPrimaryDark
                                                      : AppColors.textPrimary)
                                                : (context.isDarkMode
                                                      ? AppColors
                                                            .textSecondaryDark
                                                      : AppColors
                                                            .textSecondary),
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
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 12,
                                  ),
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
                    else if (descriptor.fieldType == FieldType.dropdown &&
                        propertyKey == 'specialty')
                      FormField<String>(
                        key: ValueKey(
                          '${resource.id}_${propertyKey}_form_${descriptor.value}',
                        ),
                        initialValue: descriptor.value,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) =>
                            !readOnly && (value == null || value.isEmpty)
                            ? context.l10n.fieldCannotBeEmpty
                            : null,
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppDropdownField<MedicalSpecialty>(
                              value: descriptor.value,
                              items: MedicalSpecialty.values,
                              openAbove: true,
                              hasError: field.hasError,
                              // The English name is the stored value the
                              // dropdown matches; the builders show it localized.
                              getDisplayText: (s) => s.displayName,
                              onChanged: (MedicalSpecialty s) {
                                onPropertyChanged?.call(
                                  propertyKey,
                                  s.displayName,
                                );
                                field.didChange(s.displayName);
                              },
                              itemBuilder: (context, s, isSelected) => Row(
                                children: [
                                  s.icon.svg(
                                    width: 20,
                                    height: 20,
                                    colorFilter: ColorFilter.mode(
                                      isSelected
                                          ? context.colorScheme.primary
                                          : context.colorScheme.onSurface,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.localizedName(context.l10n),
                                      style: AppTextStyle.bodyMedium.copyWith(
                                        color: isSelected
                                            ? context.colorScheme.primary
                                            : context.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              valueBuilder: (context, value) {
                                final match = MedicalSpecialty.values
                                    .where((s) => s.displayName == value)
                                    .firstOrNull;
                                if (match == null) {
                                  return Text(
                                    value.isEmpty
                                        ? context.l10n.specialty
                                        : value,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyle.labelLarge.copyWith(
                                      color: value.isEmpty
                                          ? context.colorScheme.onSurface
                                                .withValues(alpha: 0.5)
                                          : context.colorScheme.onSurface,
                                    ),
                                  );
                                }
                                return Row(
                                  children: [
                                    match.icon.svg(
                                      width: 18,
                                      height: 18,
                                      colorFilter: ColorFilter.mode(
                                        context.colorScheme.onSurface,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      match.localizedName(context.l10n),
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyle.labelLarge.copyWith(
                                        color: context.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (field.hasError && field.errorText != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  left: 12,
                                ),
                                child: Text(
                                  field.errorText!,
                                  style: AppTextStyle.labelSmall.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (descriptor.fieldType == FieldType.dropdown)
                      AppDropdownField<String>(
                        value: _getGenderDisplayValue(
                          descriptor.value,
                          context,
                        ),
                        items: [
                          context.l10n.male,
                          context.l10n.female,
                          context.l10n.preferNotToSay,
                        ],
                        getDisplayText: (item) => item,
                        onChanged: (String newValue) {
                          final fhirValue = _mapDisplayGenderToFhir(
                            newValue,
                            context,
                          );
                          onPropertyChanged?.call(propertyKey, fhirValue);
                        },
                      )
                    else
                      TextFormField(
                        key: ValueKey('${resource.id}_$propertyKey'),
                        initialValue: descriptor.value,
                        readOnly: readOnly,
                        validator: (value) => readOnly
                            ? null
                            : descriptor.validate(value)?.message(context.l10n),
                        inputFormatters: descriptor.inputFormatters,
                        keyboardType: descriptor.keyboardType,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: AppTextStyle.labelLarge,
                        onChanged: (value) =>
                            onPropertyChanged?.call(propertyKey, value),
                        decoration: _fieldDecoration(
                          context,
                          confidenceLevel,
                        ),
                      ),
                    if (entry.key != textFields.entries.last.key)
                      const SizedBox(height: 16),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context,
    ConfidenceLevel confidenceLevel, {
    String? hintText,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderSide: BorderSide(color: color, width: width),
          borderRadius: BorderRadius.circular(8),
        );
    final color = confidenceLevel.getColor(context);
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      helperText: ' ',
      helperStyle: const TextStyle(height: 0, fontSize: 0),
      errorMaxLines: 4,
      disabledBorder: border(color),
      enabledBorder: border(color),
      focusedBorder: border(color),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red, width: 1.5),
      contentPadding: contentPadding,
    );
  }

  /// A glasses prescription's lens values as on paper, but turned so it
  /// fits a phone: one row per value, a field per eye.
  Widget _buildLensGrid(
    BuildContext context,
    MappingVisionPrescription resource, {
    required bool readOnly,
    Function(String, String)? onPropertyChanged,
  }) {
    final l10n = context.l10n;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.extraSmall),
      child: Text(text, style: AppTextStyle.bodySmall),
    );
    Widget cell(String key, TextFieldDescriptor descriptor) => Padding(
      padding: const EdgeInsets.all(Insets.extraSmall),
      child: TextFormField(
        key: ValueKey('${resource.id}_$key'),
        initialValue: descriptor.value,
        readOnly: readOnly,
        validator: (value) =>
            readOnly ? null : descriptor.validate(value)?.message(l10n),
        keyboardType: descriptor.keyboardType,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textAlign: TextAlign.center,
        style: AppTextStyle.labelLarge,
        onChanged: (value) => onPropertyChanged?.call(key, value),
        decoration: _fieldDecoration(
          context,
          descriptor.confidence,
          hintText: '-',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Insets.small,
            vertical: Insets.small,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: Insets.normal),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.3),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox.shrink(),
              header(l10n.visionEyeRight),
              header(l10n.visionEyeLeft),
            ],
          ),
          for (final row in resource.lensRows(l10n))
            TableRow(
              children: [
                Text(row.right.label, style: AppTextStyle.bodySmall),
                cell(row.rightKey, row.right),
                cell(row.leftKey, row.left),
              ],
            ),
        ],
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

  void _swapPatient(BuildContext context, StagedPatient patient) {
    context.read<ProcessingBloc>().add(
      EncounterAttached(
        sessionId: widget.sessionId,
        patient: patient.swapped,
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
        patientOnly: widget.diagnosticReport?.hasSelection ?? false,
      ),
    );
    if (result == null || !context.mounted) return;

    final (patient, encounter) = result;
    context.read<ProcessingBloc>().add(
      EncounterAttached(
        sessionId: widget.sessionId,
        patient: patient,
        encounter: encounter,
      ),
    );
  }

  Widget _buildPatientMatchBanner(BuildContext context, StagedPatient patient) {
    final shown = patient.shown;
    final shownName = '${shown.givenName.value} ${shown.familyName.value}'
        .trim();
    final swap = patient.canSwap ? () => _swapPatient(context, patient) : null;
    final swapIcon = patient.canSwap ? Icons.swap_horiz : null;

    switch (patient.review) {
      case PatientReview.unidentified:
        return _buildBanner(
          context,
          icon: Icons.person_search_outlined,
          color: context.colorScheme.tertiary,
          text: context.l10n.processingNoPatientFound,
          onAction: swap,
          actionIcon: swapIcon,
        );
      case PatientReview.newPerson:
        return _buildBanner(
          context,
          icon: Icons.person_add_outlined,
          color: context.colorScheme.tertiary,
          text: shownName.isNotEmpty
              ? '${context.l10n.newPatient}: $shownName'
              : context.l10n.newPatient,
          onAction: swap,
          actionIcon: swapIcon,
        );
      case PatientReview.you:
        return _buildBanner(
          context,
          icon: Icons.person_outline,
          color: context.colorScheme.primary,
          text: shownName.isNotEmpty
              ? context.l10n.patientIsYou(shownName)
              : context.l10n.patientSavedAsYou,
          onAction: swap,
          actionIcon: swapIcon,
        );
      case PatientReview.existing:
        return _buildBanner(
          context,
          icon: Icons.check_circle,
          color: context.colorScheme.primary,
          text: context.l10n.patientMatchFound(patient.existing!.displayTitle),
        );
      case PatientReview.existingEdited:
        final displayName = patient.existing!.displayTitle;
        return _buildBanner(
          context,
          icon: widget.isAttachmentLocked
              ? Icons.save_outlined
              : Icons.edit_outlined,
          color: widget.isAttachmentLocked
              ? AppColors.success
              : AppColors.warning,
          text: widget.isAttachmentLocked
              ? context.l10n.patientSavingModified(displayName)
              : context.l10n.patientModifiedUpdating(displayName),
          onAction: () => context.read<ProcessingBloc>().add(
            PatientReverted(sessionId: widget.sessionId),
          ),
        );
      case PatientReview.changedTo:
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
          text: context.l10n.patientChangedTo(patient.existing!.displayTitle),
          onAction: swap,
          actionIcon: swapIcon,
        );
    }
  }

  Widget _buildBanner(
    BuildContext context, {
    IconData? icon,
    Widget? leadingIcon,
    required Color color,
    required String text,
    VoidCallback? onAction,
    IconData? actionIcon,
  }) => ReviewBanner(
    icon: icon,
    leadingIcon: leadingIcon,
    color: color,
    text: text,
    onAction: onAction,
    actionIcon: actionIcon,
  );
}

/// A one-line note on a staged record in the review (a patient match, a
/// record already in the wallet), with an optional action.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({
    required this.color,
    required this.text,
    this.icon,
    this.leadingIcon,
    this.onAction,
    this.actionIcon,
    super.key,
  });

  final IconData? icon;
  final Widget? leadingIcon;
  final Color color;
  final String text;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
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
