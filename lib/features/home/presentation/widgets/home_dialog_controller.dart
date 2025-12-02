import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_dialog.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';

class HomeDialogController {
  static void showEditRecordsDialog(
    BuildContext context,
    HomeState state,
    Function(Map<HomeRecordsCategory, bool>) onRecordsSaved,
  ) {
    final orderedRecords =
        state.overviewCards.map((c) => c.category).toList(growable: false);
    final allRecords = HomeRecordsCategory.values;
    final items = orderedRecords.map((category) {
      return DialogItem(
        id: category.name,
        label: category.display,
      );
    }).toList();

    // Add any remaining categories not in ordered list
    for (final category in allRecords) {
      if (!orderedRecords.contains(category)) {
        items.add(DialogItem(
          id: category.name,
          label: category.display,
        ));
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
        description: 'Choose the records you want to see on your dashboard.',
        items: items,
        mode: AppDialogMode.multiSelect,
        initiallySelected: initiallySelected,
        cancelText: context.l10n.cancel,
        confirmText: context.l10n.save,
        validationMessage: 'Select at least one record type to continue.',
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
        label: type.title,
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
        description: 'Choose the vitals you want to see on your dashboard.',
        items: items,
        mode: AppDialogMode.multiSelect,
        initiallySelected: initiallySelected,
        cancelText: context.l10n.cancel,
        confirmText: context.l10n.save,
        validationMessage: 'Select at least one vital sign to continue.',
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
}
