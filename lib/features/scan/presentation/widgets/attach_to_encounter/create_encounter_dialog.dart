import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/scan/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class CreateEncounterDialog extends StatefulWidget {
  const CreateEncounterDialog({super.key});

  static Future<MappingEncounter?> show(BuildContext context) {
    return showDialog<MappingEncounter>(
      context: context,
      builder: (context) => const CreateEncounterDialog(),
    );
  }

  @override
  State<CreateEncounterDialog> createState() => _CreateEncounterDialogState();
}

class _CreateEncounterDialogState extends State<CreateEncounterDialog> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  void _handleCreate() {
    if (!_formKey.currentState!.validate()) return;

    final encounter = MappingEncounter(
      id: const Uuid().v4(),
      encounterType: MappedProperty(
        value: _nameController.text,
        confidenceLevel: 1.0,
      ),
      periodStart: MappedProperty(
        value: _selectedDate.toIso8601String().split('T').first,
        confidenceLevel: 1.0,
      ),
    );

    Navigator.of(context).pop(encounter);
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: context.theme.copyWith(
            colorScheme: context.colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;

    return Dialog(
      backgroundColor: context.colorScheme.surface,
      surfaceTintColor: context.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.all(Insets.normal),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.normal,
                  vertical: Insets.small,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Create Encounter',
                        style: AppTextStyle.titleSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: borderColor),

              // Content
              Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encounter name field
                    Text(
                      'Encounter name',
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: Insets.small),
                    TextFormField(
                      controller: _nameController,
                      style: AppTextStyle.bodyMedium,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an encounter name';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter encounter name',
                        hintStyle: AppTextStyle.bodyMedium.copyWith(
                          color: context.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: Insets.normal),

                    // Date field
                    Text(
                      'Date',
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: Insets.small),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('dd.MM.yyyy').format(_selectedDate),
                                style: AppTextStyle.bodyMedium,
                              ),
                            ),
                            Assets.icons.calendar.svg(
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                context.colorScheme.onSurface.withOpacity(0.6),
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(height: 1, color: borderColor),

              // Footer
              Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.transparent,
                        onPressed: _handleCancel,
                      ),
                    ),
                    const SizedBox(width: Insets.small),
                    Expanded(
                      child: AppButton(
                        label: 'Create',
                        variant: AppButtonVariant.primary,
                        onPressed: _handleCreate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

