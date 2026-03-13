import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/fhir_reference_utils.dart';
import 'package:health_wallet/core/widgets/custom_app_bar.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/observation/observation.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/features/user/presentation/bloc/user_bloc.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/share_records/core/ephemeral_session_manager.dart';

@RoutePage()
class RecordDetailsPage extends StatefulWidget {
  final IFhirResource resource;

  const RecordDetailsPage({
    super.key,
    required this.resource,
  });

  @override
  State<RecordDetailsPage> createState() => _RecordDetailsPageState();
}

class _RecordDetailsPageState extends State<RecordDetailsPage> {
  final PdfPreviewService _pdfPreviewService = getIt<PdfPreviewService>();
  late final bool _isEphemeral;
  List<IFhirResource> _ephemeralRelatedResources = [];

  @override
  void initState() {
    super.initState();
    _isEphemeral = EphemeralSessionManager.instance.hasActiveSession;
    if (_isEphemeral) {
      _ephemeralRelatedResources = _findRelatedInMemory();
    }
  }

  List<IFhirResource> _findRelatedInMemory() {
    final session = EphemeralSessionManager.instance.currentSession;
    if (session == null) return [];
    final allRecords = session.records;
    final resource = widget.resource;
    final related = <IFhirResource>[];

    if (resource.fhirType == FhirType.Encounter) {
      for (final r in allRecords) {
        if (r.id == resource.id) continue;
        if (_resourceReferencesEncounter(r, resource.resourceId)) {
          related.add(r);
        }
      }
    } else {
      final encounterId = _extractEncounterIdFromResource(resource);
      if (encounterId != null) {
        final encounter = allRecords
            .where((r) =>
                r.fhirType == FhirType.Encounter &&
                r.resourceId == encounterId)
            .firstOrNull;
        if (encounter != null) related.add(encounter);
      }

      for (final ref in resource.resourceReferences) {
        final refId = FhirReferenceUtils.extractReferenceId(ref);
        if (refId == null) continue;
        final match = allRecords.where((r) {
          if (r.id == resource.id) return false;
          return r.resourceId == refId;
        }).firstOrNull;
        if (match != null && !related.contains(match)) {
          related.add(match);
        }
      }
    }

    return related;
  }

  bool _resourceReferencesEncounter(IFhirResource r, String encounterId) {
    if (r.encounterId.isNotEmpty && r.encounterId == encounterId) {
      return true;
    }

    final encRef = r.rawResource['encounter']?['reference'] as String?;
    if (encRef != null) {
      final extractedId = FhirReferenceUtils.extractReferenceId(encRef);
      if (extractedId == encounterId) return true;
    }

    final contextEnc = r.rawResource['context']?['encounter'] as List?;
    if (contextEnc != null) {
      return contextEnc.any((e) {
        final ref = e['reference'] as String?;
        final extractedId = FhirReferenceUtils.extractReferenceId(ref);
        return extractedId == encounterId;
      });
    }

    return false;
  }

  String? _extractEncounterIdFromResource(IFhirResource resource) {
    if (resource.encounterId.isNotEmpty) return resource.encounterId;

    final encRef = resource.rawResource['encounter']?['reference'] as String?;
    if (encRef != null) {
      return FhirReferenceUtils.extractReferenceId(encRef);
    }

    final contextEnc = resource.rawResource['context']?['encounter'] as List?;
    if (contextEnc != null && contextEnc.isNotEmpty) {
      final ref = contextEnc.first['reference'] as String?;
      return FhirReferenceUtils.extractReferenceId(ref);
    }

    return null;
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

    return Scaffold(
      appBar: const CustomAppBar(title: 'Record Details'),
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
          onTap: () =>
              context.router.push(RecordDetailsRoute(resource: encounter)),
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
              onTap: () =>
                  context.router.push(RecordDetailsRoute(resource: resource)),
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
}
