import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
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
    required this.onPropertyChanged,
    required this.onResourceRemoved,
    required this.formKey,
    this.encounter,
    this.patient,
    super.key,
  });

  final List<MappingResource> resources;
  final Function(int, String, String) onPropertyChanged;
  final Function(int) onResourceRemoved;
  final GlobalKey<FormState> formKey;
  final StagedPatient? patient;
  final StagedEncounter? encounter;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (patient?.hasSelection == true)
              _buildResourceForm(
                context,
                resource: patient!.mode == ImportMode.createNew
                    ? patient!.draft!
                    : MappingPatient.fromFhirResource(patient!.existing!),
                canRemove: false,
                isStagedResource: true,
                isReadOnly: patient!.mode == ImportMode.linkExisting,
              ),
            if (encounter?.hasSelection == true)
              _buildResourceForm(
                context,
                canRemove: false,
                resource: encounter!.mode == ImportMode.createNew
                    ? encounter!.draft!
                    : MappingEncounter.fromFhirResource(encounter!.existing!),
                isStagedResource: true,
                isReadOnly: encounter!.mode == ImportMode.linkExisting,
              ),
            ...resources.map((resource) {
              final index = resources.indexOf(resource);

              return _buildResourceForm(
                context,
                resource: resource,
                onPropertyChanged: (propertyKey, newValue) =>
                    onPropertyChanged.call(index, propertyKey, newValue),
                onResourceRemoved: () => onResourceRemoved.call(index),
              );
            })
          ]),
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
                    if (isStagedResource)
                      Padding(
                        padding: const EdgeInsetsGeometry.all(6),
                        child: GestureDetector(
                          onTap: () async {
                            final result =
                                await showDialog<AttachToEncounterResult>(
                              context: context,
                              builder: (context) => AttachToEncounterWidget(
                                newPatient: resources.firstWhereOrNull(
                                        (resource) =>
                                            resource is MappingPatient)
                                    as MappingPatient?,
                                newEncounter: resources.firstWhereOrNull(
                                        (resource) =>
                                            resource is MappingEncounter)
                                    as MappingEncounter?,
                              ),
                            );
                            if (result == null || !context.mounted) return;

                            final (patient, encounter) = result;

                            context.read<ScanBloc>().add(ScanEncounterAttached(
                                  patient: patient,
                                  encounter: encounter,
                                ));
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
              final borderColor = switch (descriptor.confidenceLevel) {
                < 0.6 => Colors.red,
                >= 0.6 && < 0.8 => Colors.yellow,
                _ =>
                  context.isDarkMode ? AppColors.borderDark : AppColors.border,
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(descriptor.label, style: AppTextStyle.bodySmall),
                  const SizedBox(height: 4),
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
                        borderSide: BorderSide(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
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
