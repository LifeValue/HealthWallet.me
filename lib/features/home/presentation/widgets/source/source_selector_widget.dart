import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_label_edit_dialog.dart';
import 'package:health_wallet/features/home/presentation/widgets/source/source_list_dialog.dart';
import 'package:health_wallet/features/records/domain/entity/patient/patient.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/features/sync/domain/services/source_type_service.dart';

class SourceSelectorWidget extends StatelessWidget {
  final List<Source> sources;
  final String? selectedSource;

  /// The selected person's sources; null shows every source.
  final List<String>? holderSourceIds;
  final Function(String) onSourceChanged;
  final Patient? currentPatient;
  final Function(Source)? onSourceTap;
  final Function(Source)? onSourceLabelEdit;
  final Function(Source)? onSourceDelete;

  const SourceSelectorWidget({
    super.key,
    required this.sources,
    required this.selectedSource,
    this.holderSourceIds,
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
      final label = source.labelSource!;
      return label.endsWith(SourceTypeService.unknownPatientName)
          ? label.replaceRange(
              label.length - SourceTypeService.unknownPatientName.length,
              null,
              context.l10n.unknownPatient,
            )
          : label;
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

  /// The selected person's sources, with "All" first when there are
  /// several; every source when no one is selected.
  List<Source> _getPatientSources(BuildContext context) {
    final allSources = sources.where((source) => source.id != 'All').toList();
    final holderSourceIds = this.holderSourceIds;
    if (holderSourceIds == null || holderSourceIds.isEmpty) {
      return _sortSources(allSources);
    }

    final filteredSources = allSources
        .where((source) => holderSourceIds.contains(source.id))
        .toList();
    if (filteredSources.length > 1) {
      return [
        const Source(
          id: 'All',
          platformName: 'All Sources',
          labelSource: 'All Sources',
          // A filter option, not a real source.
          platformType: 'all',
        ),
        ...filteredSources,
      ];
    }
    return _sortSources(filteredSources);
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
        onSourceChanged(source.id);
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
      return context.l10n.all;
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
        final allSources = sources
            .where((source) => source.id != 'All')
            .toList();
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
            : context.l10n.all;
      }
    }
  }
}
