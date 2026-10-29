import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';

class HomeDialogController {
  static void showEditRecordsDialog(
    BuildContext context,
    HomeState state,
    Function(Map<HomeRecordsCategory, bool>) onRecordsSaved,
  ) {
    final orderedRecords = state.overviewCards
        .map((c) => c.category)
        .toList(growable: false);
    const allRecords = HomeRecordsCategory.values;
    final items = orderedRecords.map((category) {
      return DialogItem(
        id: category.name,
        label: category.localizedName(context.l10n),
      );
    }).toList();

    // Add any remaining categories not in ordered list
    for (final category in allRecords) {
      if (!orderedRecords.contains(category)) {
        items.add(
          DialogItem(
            id: category.name,
            label: category.localizedName(context.l10n),
          ),
        );
      }
    }

    final initiallySelected = state.selectedRecordTypes.entries
        .where((e) => e.value)
        .map((e) => e.key.name)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.records,
        description: context.l10n.chooseRecordsForDashboard,
        items: items,
        mode: AppDialogMode.multiSelect,
        initiallySelected: initiallySelected,
        cancelText: context.l10n.cancel,
        confirmText: context.l10n.save,
        validationMessage: context.l10n.selectAtLeastOneRecordType,
        onConfirm: (selectedIds) {
          final result = <HomeRecordsCategory, bool>{};
          for (final category in allRecords) {
            result[category] = selectedIds.contains(category.name);
          }
          onRecordsSaved(result);
        },
      ),
    );
  }

  static void showEditVitalsDialog(
    BuildContext context,
    HomeState state,
    Function(Map<PatientVitalType, bool>) onVitalsSaved,
  ) {
    final displayedOrder = state.patientVitals
        .map((v) => PatientVitalTypeX.fromTitle(v.title))
        .whereType<PatientVitalType>()
        .toList(growable: false);
    final remaining = state.selectedVitals.keys
        .where((k) => !displayedOrder.contains(k))
        .toList(growable: false);
    final orderedVitals = [...displayedOrder, ...remaining];

    final items = orderedVitals.map((type) {
      return DialogItem(
        id: type.name,
        label: type.localizedName(context.l10n),
      );
    }).toList();

    final initiallySelected = state.selectedVitals.entries
        .where((e) => e.value)
        .map((e) => e.key.name)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.vitals,
        description: context.l10n.chooseVitalsForDashboard,
        items: items,
        mode: AppDialogMode.multiSelect,
        initiallySelected: initiallySelected,
        cancelText: context.l10n.cancel,
        confirmText: context.l10n.save,
        validationMessage: context.l10n.selectAtLeastOneVital,
        onConfirm: (selectedIds) {
          final result = <PatientVitalType, bool>{};
          for (final type in PatientVitalType.values) {
            result[type] = selectedIds.contains(type.name);
          }
          onVitalsSaved(result);
        },
      ),
    );
  }

  static void showEditSpecialtiesDialog(
    BuildContext context,
    HomeState state,
    Function(Map<MedicalSpecialty, bool>) onSpecialtiesSaved,
  ) {
    final orderedSpecialties = state.specialtyCards
        .map((c) => c.specialty)
        .toList(growable: false);
    const allSpecialties = MedicalSpecialty.values;
    final items = orderedSpecialties.map((specialty) {
      return DialogItem(
        id: specialty.name,
        label: specialty.localizedName(context.l10n),
      );
    }).toList();

    for (final specialty in allSpecialties) {
      if (!orderedSpecialties.contains(specialty)) {
        items.add(
          DialogItem(
            id: specialty.name,
            label: specialty.localizedName(context.l10n),
          ),
        );
      }
    }

    final initiallySelected = state.selectedSpecialties.entries
        .where((e) => e.value)
        .map((e) => e.key.name)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.specialty,
        description: context.l10n.chooseSpecialtiesForDashboard,
        items: items,
        mode: AppDialogMode.multiSelect,
        initiallySelected: initiallySelected,
        cancelText: context.l10n.cancel,
        confirmText: context.l10n.save,
        validationMessage: context.l10n.selectAtLeastOneSpecialty,
        onConfirm: (selectedIds) {
          final result = <MedicalSpecialty, bool>{};
          for (final specialty in allSpecialties) {
            result[specialty] = selectedIds.contains(specialty.name);
          }
          onSpecialtiesSaved(result);
        },
      ),
    );
  }
}
