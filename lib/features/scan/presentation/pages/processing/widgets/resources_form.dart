import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/delete_confirmation_dialog.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_patient.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/staged_resource.dart';
import 'package:health_wallet/features/scan/domain/entity/text_field_descriptor.dart';
import 'package:health_wallet/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:health_wallet/features/scan/presentation/widgets/attach_to_encounter/attach_to_encounter_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ResourcesForm extends StatelessWidget {
  const ResourcesForm({
    required this.resources,
    required this.sessionId,
    required this.formKey,
    this.encounter,
    this.patient,
    this.isAttachmentLocked = false,
    super.key,
  });

  final List<MappingResource> resources;
  final String sessionId;
  final GlobalKey<FormState> formKey;
  final StagedPatient? patient;
  final StagedEncounter? encounter;
  final bool isAttachmentLocked;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          if (patient?.hasSelection == true)
            _buildResourceForm(
              context,
              resource: patient!.mode == ImportMode.createNew
                  ? patient!.draft!
                  : MappingPatient.fromFhirResource(patient!.existing!),
              canRemove: false,
              isStagedResource: true,
              isReadOnly: isAttachmentLocked ||
                  patient!.mode == ImportMode.linkExisting,
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
          if (encounter?.hasSelection == true)
            _buildResourceForm(
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
          ...resources.map((resource) {
            final index = resources.indexOf(resource);

            return _buildResourceForm(
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
                  context.read<ScanBloc>().add(
                      ScanResourceRemoved(sessionId: sessionId, index: index));
                },
              ),
            );
          })
        ],
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
          border:
              Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1))),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsetsGeometry.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(resource.label, style: AppTextStyle.bodyLarge),
                Row(
                  children: [
                    if (isStagedResource && !isAttachmentLocked)
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
                      Text(descriptor.label, style: AppTextStyle.bodySmall),
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
                  else
                    TextFormField(
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
}
