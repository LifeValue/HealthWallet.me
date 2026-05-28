import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/app_dropdown_field.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapped_property.dart';
import 'package:health_wallet/features/processing/domain/entity/mapping_resources/mapping_encounter.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class CreateEncounterDialog extends StatefulWidget {
  const CreateEncounterDialog({super.key});

  static Future<MappingEncounter?> show(
    BuildContext context, {
    MappingEncounter? initEncounter,
  }) {
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
  String _selectedSpecialty = '';
  final _formKey = GlobalKey<FormState>();
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  String? _specialtyError;

  void _handleCreate() {
    final nameValid = _nameController.text.trim().isNotEmpty;
    if (!nameValid) {
      setState(() => _nameError = context.l10n.pleaseEnterEncounterName);
    } else {
      setState(() => _nameError = null);
    }
    if (_selectedSpecialty.isEmpty) {
      setState(() => _specialtyError = 'Please select a specialty');
    } else {
      setState(() => _specialtyError = null);
    }
    if (!nameValid || _selectedSpecialty.isEmpty) return;

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
      specialty: MappedProperty(
        value: _selectedSpecialty,
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
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.createEncounter,
                        style: AppTextStyle.bodyLarge,
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
                    const SizedBox(width: 6)
                  ],
                ),
              ),
              Container(height: 1, color: borderColor),


              Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      context.l10n.encounterName,
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: Insets.small),
                    TextField(
                      controller: _nameController,
                      style: AppTextStyle.labelLarge,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: context.l10n.enterEncounterName,
                        hintStyle: AppTextStyle.labelLarge.copyWith(
                          color: context.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _nameError != null
                                ? context.colorScheme.error
                                : borderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (_nameError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Insets.extraSmall),
                        child: Text(
                          _nameError!,
                          style: AppTextStyle.labelSmall.copyWith(
                            color: context.colorScheme.error,
                          ),
                        ),
                      ),

                    const SizedBox(height: Insets.normal),

                    Text(
                      context.l10n.specialty,
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: Insets.small),
                    AppDropdownField<MedicalSpecialty>(
                      hasError: _specialtyError != null,
                      value: _selectedSpecialty,
                      items: MedicalSpecialty.values,
                      openAbove: true,
                      getDisplayText: (s) => s.displayName,
                      onChanged: (s) =>
                          setState(() {
                            _selectedSpecialty = s.displayName;
                            _specialtyError = null;
                          }),
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
                              s.displayName,
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
                            value.isEmpty ? context.l10n.specialty : value,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.labelLarge.copyWith(
                              color: value.isEmpty
                                  ? context.colorScheme.onSurface
                                      .withOpacity(0.5)
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
                              match.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.labelLarge.copyWith(
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_specialtyError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Insets.extraSmall),
                        child: Text(
                          _specialtyError!,
                          style: AppTextStyle.labelSmall.copyWith(
                            color: context.colorScheme.error,
                          ),
                        ),
                      ),

                    const SizedBox(height: Insets.normal),

                    Text(
                      context.l10n.date,
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
                                DateFormatUtils.formatDate(
                                    _selectedDate,
                                    context.read<UserBloc>().state.regionPreset),
                                style: AppTextStyle.labelLarge,
                              ),
                            ),
                            Assets.icons.calendar.svg(
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                context.colorScheme.onSurface,
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

              Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: context.l10n.cancel,
                        variant: AppButtonVariant.transparent,
                        onPressed: _handleCancel,
                      ),
                    ),
                    const SizedBox(width: Insets.small),
                    Expanded(
                      child: AppButton(
                        label: context.l10n.create,
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
    );
  }
}
