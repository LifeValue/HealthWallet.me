import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/di/injection.dart';

@RoutePage()
class RecordDetailsPage extends StatelessWidget {
  final IFhirResource resource;
  final PdfPreviewService _pdfPreviewService = getIt<PdfPreviewService>();

  RecordDetailsPage({
    super.key,
    required this.resource,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          getIt<RecordsBloc>()..add(RecordDetailLoaded(resource)),
      child: BlocBuilder<RecordsBloc, RecordsState>(
        builder: (context, state) {
          IFhirResource? encounter = state.relatedResources.firstWhere(
            (resource) => resource.fhirType == FhirType.Encounter,
            orElse: () => const GeneralResource(),
          );

          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Record Details',
                style: AppTextStyle.titleMedium,
              ),
              centerTitle: false,
              backgroundColor: context.colorScheme.surface,
              leading: IconButton(
                onPressed: () => context.router.maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              elevation: 0,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.normal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(context),
                  const SizedBox(height: 20),
                  if (resource.fhirType != FhirType.Encounter &&
                      encounter.fhirType == FhirType.Encounter)
                    _buildEncounterDetails(context, encounter as Encounter),
                  if (state.relatedResources.isNotEmpty)
                    _buildRelatedResourcesSection(
                        context, state.relatedResources),
                ],
              ),
            ),
          );
        },
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
                resource.fhirType.icon.svg(
                  width: 15,
                  color: context.colorScheme.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  resource.fhirType.display,
                  style: AppTextStyle.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            resource.displayTitle,
            style: AppTextStyle.bodyMedium.copyWith(
              color: context.colorScheme.onSurface,
            ),
          ),
          if (resource.fhirType == FhirType.DocumentReference ||
              resource.fhirType == FhirType.Media)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppButton(
                label: 'View Document',
                onPressed: () => _pdfPreviewService.previewPdfFromResource(
                    context, resource),
                icon: const Icon(Icons.visibility_outlined),
                variant: AppButtonVariant.outlined,
                fullWidth: false,
                height: 36,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ...resource.additionalInfo.map((infoLine) {
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
                        onPressed: () => _pdfPreviewService
                            .previewPdfFromResource(context, resource),
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
