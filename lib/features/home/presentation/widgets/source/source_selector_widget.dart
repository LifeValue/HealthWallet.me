import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_list_dialog.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_label_edit_dialog.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/bloc/patient_bloc.dart';

class SourceSelectorWidget extends StatelessWidget {
  final List<Source> sources;
  final String? selectedSource;
  final Function(String, List<String>?) onSourceChanged;
  final Patient? currentPatient;
  final Function(Source)? onSourceTap;
  final Function(Source)? onSourceLabelEdit;
  final Function(Source)? onSourceDelete;

  const SourceSelectorWidget({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.onSourceChanged,
    this.currentPatient,
    this.onSourceTap,
    this.onSourceLabelEdit,
    this.onSourceDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final colorScheme = context.colorScheme;

    final patientSources = _getPatientSources(context);

    if (patientSources.isEmpty) {
      return const SizedBox.shrink();
    } else if (patientSources.length == 1) {
      // Single source for patient - show as tappable text
      final source = patientSources.first;
      return Container(
        constraints: const BoxConstraints(maxWidth: 150),
        child: InkWell(
          onTap: () => _showSourceListDialog(context),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${context.l10n.source}: ',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                Flexible(
                  child: Text(
                    _getSourceDisplayName(context, source),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Multiple sources per patient - show tappable text that opens dialog
      return Container(
        constraints: const BoxConstraints(maxWidth: 150),
        child: InkWell(
          onTap: () => _showSourceListDialog(context),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.homeSource,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: Insets.small),
                Flexible(
                  child: Text(
                    _getSelectedSourceDisplayName(context),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  /// Get the display name for a source (labelSource > name > id)
  String _getSourceDisplayName(BuildContext context, Source source) {
    if (source.labelSource?.isNotEmpty == true) {
      return source.labelSource!;
    }
    if (source.platformName?.isNotEmpty == true) {
      return source.platformName!;
    }
    // If source ID is too long, don't display it
    if (source.id.length > 20) {
      return context.l10n.unknownSource;
    }
    return source.id;
  }

  /// Get sources for the current patient based on patient's sourceId
  /// Only show sources that have the selected patient
  List<Source> _getPatientSources(BuildContext context) {
    final allSources = sources.where((source) => source.id != 'All').toList();

    // Try to get the currently selected patient from PatientBloc
    try {
      final patientBloc = context.read<PatientBloc>();
      final patientState = patientBloc.state;

      // Use the selected patient ID from PatientBloc, not from currentPatient
      // This ensures we always have the latest patient selection
      final selectedPatientId = patientState.selectedPatientId;

      if (selectedPatientId == null || patientState.patientGroups.isEmpty) {
        // No patient selected or no groups available, show all sources
        return _sortSources(allSources);
      }

      // Find the patient group for the selected patient
      // This now includes orphan sources for the default wallet holder
      final patientGroup = patientState.patientGroups[selectedPatientId];

      if (patientGroup == null || patientGroup.sourceIds.isEmpty) {
        // If no group found, return all sources
        return _sortSources(allSources);
      }

      // Filter sources: only sources that have this patient
      final filteredSources = allSources.where((source) {
        return patientGroup.sourceIds.contains(source.id);
      }).toList();

      // If there are multiple sources, add an "All" option at the beginning
      if (filteredSources.length > 1) {
        final allSources = List<Source>.from(filteredSources);
        allSources.insert(
            0,
            Source(
              id: 'All',
              platformName: 'All Sources',
              labelSource: 'All Sources',
              platformType:
                  'all', // Special type to indicate this is a filter option, not a real source
            ));
        return allSources;
      }

      return _sortSources(filteredSources);
    } catch (e) {
      // If PatientBloc is not available, return all sources
      return _sortSources(allSources);
    }
  }

  /// Sort sources alphabetically
  List<Source> _sortSources(List<Source> sources) {
    final sortedSources = List<Source>.from(sources);
    sortedSources.sort((a, b) => a.id.compareTo(b.id));
    return sortedSources;
  }

  /// Show source list dialog
  void _showSourceListDialog(BuildContext context) {
    final patientSources = _getPatientSources(context);

    SourceListDialog.show(
      context,
      patientSources,
      selectedSource,
      (source) {
        // Get patient source IDs when "All" is selected
        List<String>? patientSourceIds;
        if (source.id == 'All') {
          try {
            final patientBloc = context.read<PatientBloc>();
            final patientState = patientBloc.state;
            final selectedPatientId = patientState.selectedPatientId;

            if (selectedPatientId != null &&
                patientState.patientGroups.isNotEmpty) {
              final patientGroup =
                  patientState.patientGroups[selectedPatientId];
              if (patientGroup != null) {
                patientSourceIds = patientGroup.sourceIds;
              }
            }
          } catch (e) {
            // Error getting patient source IDs
          }
        }

        onSourceChanged(source.id, patientSourceIds);
      },
      onSourceEdit: onSourceLabelEdit != null
          ? (source) {
              SourceLabelEditDialog.show(
                context,
                source,
                (newLabel) {
                  onSourceLabelEdit!(source);
                  // Close the source list dialog after successful edit
                  Navigator.of(context).pop();
                },
              );
            }
          : null,
      onSourceDelete: onSourceDelete,
    );
  }

  /// Get the display name for the currently selected source
  String _getSelectedSourceDisplayName(BuildContext context) {
    // Handle "All" option first
    if (selectedSource == 'All') {
      return 'All';
    }

    final patientSources = _getPatientSources(context);

    // Try to find the selected source in patient sources
    try {
      final currentSource = patientSources.firstWhere(
        (source) => source.id == selectedSource,
      );
      return _getSourceDisplayName(context, currentSource);
    } catch (e) {
      // If selected source is not found in patient sources,
      // try to find it in all sources
      try {
        final allSources =
            sources.where((source) => source.id != 'All').toList();
        final currentSource = allSources.firstWhere(
          (source) => source.id == selectedSource,
        );
        return _getSourceDisplayName(context, currentSource);
      } catch (e) {
        // If still not found, return the selected source ID or fallback
        if (selectedSource != null && selectedSource!.isNotEmpty) {
          return selectedSource!;
        }
        return patientSources.isNotEmpty
            ? _getSourceDisplayName(context, patientSources.first)
            : 'All';
      }
    }
  }
}
