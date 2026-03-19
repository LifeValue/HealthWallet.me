import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/fhir_resource_relationship_service.dart';
import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/share_records/core/ephemeral_session_manager.dart';
import 'package:health_wallet/gen/assets.gen.dart';

@RoutePage()
class RecordDetailsPage extends StatefulWidget {
  final IFhirResource resource;
  final List<IFhirResource> ephemeralRecords;

  const RecordDetailsPage({
    super.key,
    required this.resource,
    this.ephemeralRecords = const [],
  });

  @override
  State<RecordDetailsPage> createState() => _RecordDetailsPageState();
}

class _RecordDetailsPageState extends State<RecordDetailsPage> {
  final PdfPreviewService _pdfPreviewService = getIt<PdfPreviewService>();
  late final bool _isEphemeral;
  late final RecordsBloc _appRecordsBloc;
  List<IFhirResource> _ephemeralRelatedResources = [];

  @override
  void initState() {
    super.initState();
    _appRecordsBloc = context.read<RecordsBloc>();
    _isEphemeral = widget.ephemeralRecords.isNotEmpty ||
        EphemeralSessionManager.instance.hasActiveSession;
    if (_isEphemeral) {
      _ephemeralRelatedResources = _findRelatedInMemory();
    }
  }

  List<IFhirResource> _findRelatedInMemory() {
    final records = widget.ephemeralRecords.isNotEmpty
        ? widget.ephemeralRecords
        : EphemeralSessionManager.instance.currentSession?.records;
    if (records == null || records.isEmpty) return [];
    return FhirResourceRelationshipService.findRelatedInMemory(
      resource: widget.resource,
      allRecords: records,
    );
  }

  List<RecordInfoLine> _getAdditionalInfo(BuildContext context) {
    final resource = widget.resource;
    if (resource is Observation) {
      try {
        final region = context.read<UserBloc>().state.regionPreset;
        return resource.additionalInfoForRegion(region);
      } catch (_) {}
    }
    return resource.additionalInfo;
  }

  void _onViewDocument(IFhirResource resource) {
    if (_isEphemeral) {
      _pdfPreviewService.previewInApp(context, resource);
    } else {
      _pdfPreviewService.previewPdfFromResource(context, resource);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEphemeral) {
      return _buildScaffold(context, _ephemeralRelatedResources);
    }

    return BlocProvider(
      create: (context) =>
          getIt<RecordsBloc>()..add(RecordDetailLoaded(widget.resource)),
      child: BlocBuilder<RecordsBloc, RecordsState>(
        builder: (context, state) {
          return _buildScaffold(context, state.relatedResources);
        },
      ),
    );
  }

  Widget _buildScaffold(
      BuildContext context, List<IFhirResource> relatedResources) {
    IFhirResource? encounter = relatedResources.firstWhere(
      (resource) => resource.fhirType == FhirType.Encounter,
      orElse: () => const GeneralResource(),
    );

    final isEphemeral = widget.ephemeralRecords.isNotEmpty;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Record Details',
        actions: isEphemeral
            ? null
            : [
                IconButton(
                  icon: Assets.icons.trashCan.svg(
                    colorFilter: ColorFilter.mode(
                      context.colorScheme.error,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () => _showDeleteDialog(context),
                ),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.normal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context),
            const SizedBox(height: 20),
            if (widget.resource.fhirType != FhirType.Encounter &&
                encounter.fhirType == FhirType.Encounter)
              _buildEncounterDetails(context, encounter as Encounter),
            if (relatedResources.isNotEmpty)
              _buildRelatedResourcesSection(context, relatedResources),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: context.theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.small,
              vertical: Insets.extraSmall,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.onSurface.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.resource.fhirType.icon.svg(
                  width: 15,
                  color: context.colorScheme.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.resource.fhirType.display,
                  style: AppTextStyle.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.resource.displayTitle,
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          if (widget.resource.fhirType == FhirType.DocumentReference ||
              widget.resource.fhirType == FhirType.Media)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppButton(
                label: 'View Document',
                onPressed: () => _onViewDocument(widget.resource),
                icon: const Icon(Icons.visibility_outlined),
                variant: AppButtonVariant.outlined,
                fullWidth: false,
                height: 36,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ..._getAdditionalInfo(context).map((infoLine) {
            if (infoLine.isSection) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  infoLine.info,
                  style: AppTextStyle.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              );
            }

            return Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: infoLine.icon.svg(
                        width: 16,
                        color: context.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        infoLine.info,
                        style: AppTextStyle.labelLarge.copyWith(
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                    )
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEncounterDetails(BuildContext context, Encounter encounter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Encounter details", style: AppTextStyle.buttonSmall),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => context.router.push(RecordDetailsRoute(
            resource: encounter,
            ephemeralRecords: widget.ephemeralRecords,
          )),
          child: _buildRelatedResourceInfo(context, encounter),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: context.theme.dividerColor),
        ),
      ],
    );
  }

  Widget _buildRelatedResourcesSection(
      BuildContext context, List<IFhirResource> resources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Related resources", style: AppTextStyle.buttonSmall),
        const SizedBox(height: 16),
        ...resources.map((resource) => InkWell(
              onTap: () => context.router.push(RecordDetailsRoute(
                resource: resource,
                ephemeralRecords: widget.ephemeralRecords,
              )),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resource.displayTitle,
                      style: AppTextStyle.labelLarge),
                  if (resource.fhirType == FhirType.Media ||
                      resource.fhirType == FhirType.DocumentReference)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppButton(
                        label: 'View Document',
                        onPressed: () => _onViewDocument(resource),
                        icon: const Icon(Icons.visibility_outlined),
                        variant: AppButtonVariant.outlined,
                        fullWidth: false,
                        height: 36,
                        fontSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  _buildRelatedResourceInfo(context, resource),
                  const SizedBox(height: 16),
                ],
              ),
            ))
      ],
    );
  }

  Widget _buildRelatedResourceInfo(
      BuildContext context, IFhirResource resource) {
    final infoLines = resource.additionalInfo
        .where((line) => !line.isSection)
        .take(2)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: infoLines
          .map(
            (infoLine) => Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    infoLine.icon.svg(
                      width: 16,
                      color: context.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        infoLine.info,
                        style: AppTextStyle.labelLarge.copyWith(
                          color: context.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  void _showDeleteDialog(BuildContext context) async {
    final relatedResources = await _appRecordsBloc.recordsRepository
        .getRelatedResourcesForDeletion(widget.resource.id);

    if (!context.mounted) return;

    if (relatedResources.isEmpty) {
      _showDeleteConfirmation(
        context: context,
        onConfirm: () => _deleteResource(context, selectedRelatedIds: []),
      );
      return;
    }

    _showDeleteSelectionDialog(context, relatedResources);
  }

  void _showDeleteSelectionDialog(
    BuildContext context,
    List<IFhirResource> relatedResources,
  ) {
    final selectedIds = <String>{};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final textColor = context.primaryTextColor;
            final borderColor = context.borderColor;

            return Dialog(
              backgroundColor: context.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 1),
              ),
              insetPadding: const EdgeInsets.all(Insets.normal),
              child: Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.deletePage,
                      style: AppTextStyle.bodyMedium.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Insets.normal),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _showDeleteConfirmation(
                          context: context,
                          onConfirm: () =>
                              _deleteResource(context, selectedRelatedIds: []),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colorScheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: Insets.smallNormal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '${widget.resource.fhirType.name} ${context.l10n.deletePage.toLowerCase()}',
                      ),
                    ),
                    if (relatedResources.isNotEmpty) ...[
                      const SizedBox(height: Insets.normal),
                      Text(
                        'Related resources',
                        style: AppTextStyle.labelLarge.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Insets.small),
                      ...relatedResources.map((resource) {
                        final isSelected = selectedIds.contains(resource.id);
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: Insets.extraSmall),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedIds.remove(resource.id);
                                } else {
                                  selectedIds.add(resource.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Insets.smallNormal,
                                vertical: Insets.small,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? context.colorScheme.error
                                          .withValues(alpha: 0.5)
                                      : borderColor,
                                ),
                                color: isSelected
                                    ? context.colorScheme.error
                                        .withValues(alpha: 0.05)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            selectedIds.add(resource.id);
                                          } else {
                                            selectedIds.remove(resource.id);
                                          }
                                        });
                                      },
                                      activeColor: context.colorScheme.error,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: Insets.small),
                                  resource.fhirType.icon.svg(
                                    width: 16,
                                    color: context.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: Insets.small),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          resource.displayTitle,
                                          style:
                                              AppTextStyle.labelLarge.copyWith(
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          resource.fhirType.display,
                                          style:
                                              AppTextStyle.labelSmall.copyWith(
                                            color: context
                                                .colorScheme.onSurface
                                                .withValues(alpha: 0.5),
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
                      }),
                    ],
                    if (selectedIds.isNotEmpty) ...[
                      const SizedBox(height: Insets.small),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _showDeleteConfirmation(
                            context: context,
                            itemCount: 1 + selectedIds.length,
                            onConfirm: () => _deleteResource(
                              context,
                              selectedRelatedIds: selectedIds.toList(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colorScheme.error,
                          side: BorderSide(
                            color: context.colorScheme.error
                                .withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: Insets.smallNormal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${context.l10n.deletePage} + ${selectedIds.length} related',
                        ),
                      ),
                    ],
                    const SizedBox(height: Insets.small),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(context.l10n.cancel),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation({
    required BuildContext context,
    required VoidCallback onConfirm,
    int itemCount = 1,
  }) {
    final message = itemCount > 1
        ? context.l10n.deleteRecordsConfirm(itemCount)
        : context.l10n.deleteRecordConfirm;

    AppSimpleDialog.showDestructiveConfirmation(
      context: context,
      title: context.l10n.deletePage,
      message: message,
      warningText: context.l10n.actionCannotBeUndone,
      confirmText: context.l10n.deletePage,
      cancelText: context.l10n.cancel,
      onConfirm: onConfirm,
    );
  }

  void _deleteResource(
    BuildContext context, {
    List<String> selectedRelatedIds = const [],
  }) {
    _appRecordsBloc.add(
      RecordsResourceDeleted(
        resourceId: widget.resource.id,
        selectedRelatedIds: selectedRelatedIds,
      ),
    );
    context.router.maybePop();
  }
}
