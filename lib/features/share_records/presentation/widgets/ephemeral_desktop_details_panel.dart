import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/services/pdf_preview_service.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/fhir_resource_relationship_service.dart';
import 'package:health_wallet/features/records/presentation/bloc/attachment_browse_bloc.dart';

class EphemeralDesktopDetailsPanel extends StatefulWidget {
  final AttachmentBrowseBloc? attachmentBrowseBloc;

  const EphemeralDesktopDetailsPanel({super.key, required this.attachmentBrowseBloc});

  @override
  State<EphemeralDesktopDetailsPanel> createState() =>
      _EphemeralDesktopDetailsPanelState();
}

class _EphemeralDesktopDetailsPanelState
    extends State<EphemeralDesktopDetailsPanel> {
  static const double _kPanelMinWidth = 280.0;
  static const double _kPanelMaxWidth = 800.0;
  static const double _kDefaultWidth = 400.0;

  double _panelWidth = _kDefaultWidth;
  bool _isOpen = true;

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colorScheme.onSurface;
    final borderColor = onSurface.withValues(alpha: 0.24);

    if (widget.attachmentBrowseBloc == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<AttachmentBrowseBloc, AttachmentBrowseState>(
      bloc: widget.attachmentBrowseBloc,
      buildWhen: (prev, curr) =>
          prev.selectedDetail != curr.selectedDetail ||
          prev.status != curr.status,
      builder: (context, state) {
        final detail = state.selectedDetail;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: _isOpen ? _panelWidth : 18,
              height: double.infinity,
              child: _isOpen
                  ? Container(
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        border: Border(left: BorderSide(color: borderColor)),
                      ),
                      child: detail != null
                          ? _PanelContent(
                              detail: detail,
                              sourceRecords: state.sourceRecords,
                              panelWidth: _panelWidth,
                            )
                          : Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: (_panelWidth * 0.1).clamp(16.0, 32.0),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.article_outlined,
                                      size: 40,
                                      color: onSurface.withValues(alpha: 0.25),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      context.l10n.selectRecordToViewDetails,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyle.bodyMedium.copyWith(
                                        color: onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_isOpen)
              Positioned(
                left: -4,
                top: 0,
                bottom: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      setState(() {
                        _panelWidth = (_panelWidth - d.delta.dx)
                            .clamp(_kPanelMinWidth, _kPanelMaxWidth);
                      });
                    },
                    child: Container(
                      width: 8,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: -18,
              top: 72,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    _panelWidth = (_panelWidth - d.delta.dx)
                        .clamp(_kPanelMinWidth, _kPanelMaxWidth);
                  });
                },
                onHorizontalDragEnd: (_) {},
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? const Color(0xFF060606)
                        : const Color(0xFFF2F2F2),
                    border: Border.all(
                      color: context.isDarkMode
                          ? borderColor
                          : const Color(0xFFF2F2F2),
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Opacity(
                    opacity: 0.6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: const Offset(3, 0),
                          child: Icon(Icons.chevron_right, size: 16, color: onSurface),
                        ),
                        Transform.translate(
                          offset: const Offset(-3, 0),
                          child: Icon(Icons.chevron_left, size: 16, color: onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PanelContent extends StatefulWidget {
  final AttachmentBrowseDetail detail;
  final List<IFhirResource> sourceRecords;
  final double panelWidth;

  const _PanelContent({
    required this.detail,
    required this.sourceRecords,
    required this.panelWidth,
  });

  @override
  State<_PanelContent> createState() => _PanelContentState();
}

class _PanelContentState extends State<_PanelContent> {
  final ScrollController _scrollController = ScrollController();
  final _pdfService = getIt<PdfPreviewService>();
  late List<IFhirResource> _relatedResources;

  @override
  void initState() {
    super.initState();
    _relatedResources = _computeRelated();
  }

  @override
  void didUpdateWidget(_PanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.record.id != widget.detail.record.id ||
        oldWidget.sourceRecords != widget.sourceRecords) {
      _relatedResources = _computeRelated();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
    }
  }

  List<IFhirResource> _computeRelated() {
    return FhirResourceRelationshipService.findRelatedInMemory(
      resource: widget.detail.record,
      allRecords: widget.sourceRecords,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hPad = (widget.panelWidth * 0.06).clamp(12.0, 24.0);
    final record = widget.detail.record;
    final encounter = _relatedResources.firstWhere(
      (r) => r.fhirType == FhirType.Encounter,
      orElse: () => const GeneralResource(),
    );
    final hasEncounter = encounter.fhirType == FhirType.Encounter;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context, record),
          const SizedBox(height: 20),
          if (record.fhirType != FhirType.Encounter && hasEncounter)
            _buildEncounterSection(context, encounter as Encounter),
          if (_relatedResources.isNotEmpty)
            _buildRelatedSection(context, _relatedResources),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, IFhirResource record) {
    final borderColor = context.colorScheme.onSurface.withValues(alpha: 0.24);
    final onSurface = context.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
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
              color: onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                record.fhirType.icon.svg(
                  width: 15,
                  colorFilter: ColorFilter.mode(onSurface, BlendMode.srcIn),
                ),
                const SizedBox(width: 4),
                Text(record.fhirType.display, style: AppTextStyle.labelSmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            record.displayTitle,
            style: AppTextStyle.bodyMedium.copyWith(color: onSurface),
          ),
          if (record.fhirType == FhirType.DocumentReference ||
              record.fhirType == FhirType.Media)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppButton(
                label: context.l10n.viewDocument,
                onPressed: () => _pdfService.previewInApp(context, record),
                icon: const Icon(Icons.visibility_outlined),
                variant: AppButtonVariant.outlined,
                fullWidth: false,
                height: 36,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ...record.additionalInfo.map((info) {
            if (info.isSection) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  info.info,
                  style: AppTextStyle.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
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
                      child: info.icon.svg(
                        width: 16,
                        colorFilter: ColorFilter.mode(
                          onSurface.withValues(alpha: 0.7),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.info,
                        style: AppTextStyle.labelLarge.copyWith(color: onSurface),
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

  Widget _buildEncounterSection(BuildContext context, Encounter encounter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.encounterDetails, style: AppTextStyle.buttonSmall),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => context.router.push(RecordDetailsRoute(
            resource: encounter,
            ephemeralRecords: widget.sourceRecords,
          )),
          child: _buildResourceInfo(context, encounter),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Divider(color: context.theme.dividerColor),
        ),
      ],
    );
  }

  Widget _buildRelatedSection(BuildContext context, List<IFhirResource> resources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.relatedResources, style: AppTextStyle.buttonSmall),
        const SizedBox(height: 16),
        ...resources.map((resource) => InkWell(
              onTap: () => context.router.push(RecordDetailsRoute(
                resource: resource,
                ephemeralRecords: widget.sourceRecords,
              )),
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
                        onPressed: () => _pdfService.previewInApp(context, resource),
                        icon: const Icon(Icons.visibility_outlined),
                        variant: AppButtonVariant.outlined,
                        fullWidth: false,
                        height: 36,
                        fontSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  _buildResourceInfo(context, resource),
                  const SizedBox(height: 16),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildResourceInfo(BuildContext context, IFhirResource resource) {
    final dimColor = context.colorScheme.onSurface.withValues(alpha: 0.6);
    final lines = resource.additionalInfo.where((l) => !l.isSection).take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((info) => Column(
            children: [
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  info.icon.svg(
                    width: 16,
                    colorFilter: ColorFilter.mode(dimColor, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      info.info,
                      style: AppTextStyle.labelLarge.copyWith(color: dimColor),
                    ),
                  ),
                ],
              ),
            ],
          )).toList(),
    );
  }
}
