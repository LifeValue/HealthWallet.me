import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/services/specialty_classifier.dart';
import 'package:health_wallet/features/home/presentation/bloc/home_bloc.dart';
import 'package:health_wallet/features/home/presentation/widgets/specialty_picker.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/records/domain/services/fhir_resource_relationship_service.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/records/presentation/widgets/delete_record_dialog.dart';
import 'package:health_wallet/features/records/presentation/widgets/vision_prescription_table.dart';
import 'package:health_wallet/features/share_records/core/ephemeral_session_manager.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
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
  RecordsBloc? _appRecordsBloc;
  List<IFhirResource> _ephemeralRelatedResources = [];
  late MedicalSpecialty? _currentSpecialty;

  @override
  void initState() {
    super.initState();
    final parsed = MedicalSpecialty.values
        .where((s) => s.name == widget.resource.specialtyOverride)
        .firstOrNull;
    _currentSpecialty =
        parsed ??
        getIt<SpecialtyClassifier>().classify(widget.resource).firstOrNull;
    _isEphemeral =
        widget.ephemeralRecords.isNotEmpty ||
        EphemeralSessionManager.instance.hasActiveSession;
    if (!_isEphemeral) {
      _appRecordsBloc = context.read<RecordsBloc>();
    }
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

  List<RecordInfoLine> _getAdditionalInfo(BuildContext context) =>
      widget.resource.additionalInfoIn(
        context.read<UserBloc>().state.regionPreset,
        context.l10n,
      );

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
    BuildContext context,
    List<IFhirResource> relatedResources,
  ) {
    final IFhirResource encounter = relatedResources.firstWhere(
      (resource) => resource.fhirType == FhirType.Encounter,
      orElse: () => const GeneralResource(),
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.recordDetails,
        actions: _isEphemeral
            ? null
            : [
                IconButton(
                  icon:
                      (_currentSpecialty?.icon ??
                              Assets.specialities.generalCare)
                          .svg(
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              context.colorScheme.primary,
                              BlendMode.srcIn,
                            ),
                          ),
                  onPressed: () => _showSpecialtyPicker(context),
                ),
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
              color: context.colorScheme.onSurface.withValues(alpha: 0.1),
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
                  widget.resource.fhirType.localizedName(context.l10n),
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
          if (widget.resource case final VisionPrescription prescription)
            VisionPrescriptionTable(prescription: prescription),
          if (widget.resource.fhirType == FhirType.DocumentReference ||
              widget.resource.fhirType == FhirType.Media)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppButton(
                label: context.l10n.viewDocument,
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
                        color: context.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
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
                    ),
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
        Text(context.l10n.encounterDetails, style: AppTextStyle.buttonSmall),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => context.router.push(
            RecordDetailsRoute(
              resource: encounter,
              ephemeralRecords: widget.ephemeralRecords,
            ),
          ),
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
    BuildContext context,
    List<IFhirResource> resources,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.relatedResources, style: AppTextStyle.buttonSmall),
        const SizedBox(height: 16),
        ...resources.map(
          (resource) => InkWell(
            onTap: () => context.router.push(
              RecordDetailsRoute(
                resource: resource,
                ephemeralRecords: widget.ephemeralRecords,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resource.displayTitle, style: AppTextStyle.labelLarge),
                if (resource.fhirType == FhirType.Media ||
                    resource.fhirType == FhirType.DocumentReference)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppButton(
                      label: context.l10n.viewDocument,
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
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedResourceInfo(
    BuildContext context,
    IFhirResource resource,
  ) {
    final infoLines = resource
        .additionalInfoIn(
          context.read<UserBloc>().state.regionPreset,
          context.l10n,
        )
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
                      color: context.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        infoLine.info,
                        style: AppTextStyle.labelLarge.copyWith(
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  void _showSpecialtyPicker(BuildContext outerContext) async {
    final currentSpecialty = _currentSpecialty;

    final selected = await showModalBottomSheet<MedicalSpecialty?>(
      context: outerContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SpecialtyPicker(
        currentSpecialty: currentSpecialty,
        onSelected: (specialty) async {
          if (specialty == currentSpecialty) {
            Navigator.of(sheetContext).pop();
            return;
          }

          final isRemove = specialty == null && currentSpecialty != null;

          final confirmed = await AppSimpleDialog.showConfirmation(
            context: sheetContext,
            title: outerContext.l10n.changeSpecialty,
            message: isRemove
                ? outerContext.l10n.removeSpecialtyConfirm
                : outerContext.l10n.changeSpecialtyConfirm,
            subtitleWidget: !isRemove && specialty != null
                ? Row(
                    children: [
                      specialty.icon.svg(
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          Theme.of(sheetContext).colorScheme.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        specialty.localizedName(outerContext.l10n),
                        style: AppTextStyle.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(sheetContext).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  )
                : null,
            confirmText: outerContext.l10n.confirm,
            cancelText: outerContext.l10n.cancel,
            onConfirm: () {},
            onCancel: () {},
          );

          if (confirmed == true && sheetContext.mounted) {
            Navigator.of(sheetContext).pop(specialty);
          }
        },
      ),
    );

    if (selected == null && currentSpecialty == null) return;
    if (selected == currentSpecialty) return;

    final repo =
        _appRecordsBloc?.recordsRepository ?? getIt<RecordsRepository>();
    await repo.setSpecialtyOverride(widget.resource.id, selected?.name);

    if (mounted && outerContext.mounted) {
      setState(() {
        _currentSpecialty = selected;
      });
      outerContext.read<HomeBloc>().add(const HomeRefreshPreservingOrder());
      outerContext.read<RecordsBloc>().add(RecordsRefreshRequested());
    }
  }

  void _showDeleteDialog(BuildContext context) async {
    final relatedResources = await _appRecordsBloc!.recordsRepository
        .getRelatedResourcesForDeletion(widget.resource.id);

    if (!context.mounted) return;

    if (relatedResources.isEmpty) {
      _showDeleteConfirmation(
        context: context,
        onConfirm: () => _deleteResource(context, selectedRelatedIds: []),
      );
      return;
    }

    await _showDeleteSelectionDialog(context, relatedResources);
  }

  Future<void> _showDeleteSelectionDialog(
    BuildContext context,
    List<IFhirResource> relatedResources,
  ) async {
    final selectedIds = await DeleteRecordDialog.show(
      context,
      recordTitle: widget.resource.displayTitle,
      relatedResources: relatedResources,
    );
    if (selectedIds == null || !context.mounted) return;

    _showDeleteConfirmation(
      context: context,
      itemCount: 1 + selectedIds.length,
      onConfirm: () =>
          _deleteResource(context, selectedRelatedIds: selectedIds),
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
    _appRecordsBloc!.add(
      RecordsResourceDeleted(
        resourceId: widget.resource.id,
        selectedRelatedIds: selectedRelatedIds,
      ),
    );
    context.router.maybePop();
  }
}
