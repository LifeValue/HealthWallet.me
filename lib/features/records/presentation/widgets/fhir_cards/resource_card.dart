import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/services/fhir_resource_relationship_service.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/record_attachments_widget.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_notes/record_notes_widget.dart';
import 'package:health_wallet/features/records/presentation/widgets/resource_info_content.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class ResourceCard extends StatefulWidget {
  final IFhirResource resource;
  final bool readOnly;
  final List<IFhirResource> ephemeralRecords;

  const ResourceCard({
    super.key,
    required this.resource,
    this.readOnly = false,
    this.ephemeralRecords = const [],
  });

  @override
  State<ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<ResourceCard> {
  bool _isExpanded = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<IFhirResource>? _ephemeralRelated;

  void _closeRelatedIfOpen() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
      _hideRelated();
    }
  }

  @override
  void dispose() {
    if (_isExpanded) {
      _hideRelated();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainResourceInfo(),
          const SizedBox(height: Insets.small),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildMainResourceInfo() {
    return ResourceInfoContent(
      resource: widget.resource,
      onTap: widget.readOnly && widget.ephemeralRecords.isNotEmpty
          ? () => context.router.push(RecordDetailsRoute(
                resource: widget.resource,
                ephemeralRecords: widget.ephemeralRecords,
              ))
          : null,
    );
  }

  bool get _hasRelated {
    if (widget.resource.fhirType == FhirType.Encounter) return true;
    if (widget.resource.resourceReferences.isNotEmpty) return true;
    return false;
  }

  void _toggleRelated() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      if (widget.readOnly && widget.ephemeralRecords.isNotEmpty) {
        _ephemeralRelated = _findRelatedInMemory();
      } else {
        context.read<RecordsBloc>().add(RecordDetailLoaded(widget.resource));
      }
      _showRelated();
    } else {
      _hideRelated();
    }
  }

  List<IFhirResource> _findRelatedInMemory() {
    return FhirResourceRelationshipService.findRelatedInMemory(
      resource: widget.resource,
      allRecords: widget.ephemeralRecords,
    );
  }

  void _hideRelated() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showRelated() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeRelatedIfOpen,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: size.width + 32,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(-16, size.height + 8),
              child: Material(
                child: widget.readOnly
                    ? _buildEphemeralRelatedSection(context)
                    : _buildRelatedResourcesSection(context),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildButtons() {
    if (widget.readOnly) {
      return _buildReadOnlyButtons();
    }

    return BlocBuilder<RecordsBloc, RecordsState>(
      builder: (context, state) {
        final isLoadingRelated =
            state.recordDetailStatus == RecordDetailStatus.loading();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasRelated)
              InkWell(
                onTap: _toggleRelated,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      if (isLoadingRelated)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          _isExpanded ? 'Hide Related' : 'View Related',
                          style: AppTextStyle.bodySmall,
                        ),
                      if (!isLoadingRelated) ...[
                        const SizedBox(width: Insets.extraSmall),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.chevron_right,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              const SizedBox(),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    _closeRelatedIfOpen();
                    showRecordActionDialog(
                        RecordNotesWidget(resource: widget.resource));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Assets.icons.licenseDraftNotes.svg(
                      width: 24,
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.normal),
                InkWell(
                  onTap: () {
                    _closeRelatedIfOpen();
                    showRecordActionDialog(
                        RecordAttachmentsWidget(resource: widget.resource));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Assets.icons.attachment.svg(
                      width: 24,
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildReadOnlyButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_hasRelated && widget.ephemeralRecords.isNotEmpty)
          InkWell(
            onTap: _toggleRelated,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Text(
                    _isExpanded ? 'Hide Related' : 'View Related',
                    style: AppTextStyle.bodySmall,
                  ),
                  const SizedBox(width: Insets.extraSmall),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.chevron_right,
                    size: 16,
                  ),
                ],
              ),
            ),
          )
        else
          const SizedBox(),
        Row(
          children: [
            InkWell(
              onTap: () {
                _closeRelatedIfOpen();
                showRecordActionDialog(
                  RecordNotesWidget(
                    resource: widget.resource,
                    readOnly: true,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Assets.icons.licenseDraftNotes.svg(
                  width: 24,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Insets.normal),
            InkWell(
              onTap: () {
                _closeRelatedIfOpen();
                showRecordActionDialog(
                  RecordAttachmentsWidget(
                    resource: widget.resource,
                    readOnly: true,
                    ephemeralRecords: widget.ephemeralRecords,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Assets.icons.attachment.svg(
                  width: 24,
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEphemeralRelatedSection(BuildContext context) {
    final related = _ephemeralRelated ?? [];

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 2.5),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        width: MediaQuery.sizeOf(context).width,
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          border: Border.all(
            color: context.theme.dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              color: context.colorScheme.onSurface.withOpacity(0.3),
              blurRadius: 5,
            ),
          ],
        ),
        child: related.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Assets.icons.information.svg(
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface.withOpacity(0.5),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: Insets.small),
                    Text(
                      'No related resources found',
                      style: AppTextStyle.labelLarge.copyWith(
                        color: context.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: related
                      .map(
                        (resource) => InkWell(
                          onTap: () {
                            _toggleRelated();
                            context.router.push(RecordDetailsRoute(
                              resource: resource,
                              ephemeralRecords: widget.ephemeralRecords,
                            ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "${resource.fhirType.display}: ${resource.title}",
                              style: AppTextStyle.bodySmall.copyWith(
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
      ),
    );
  }

  Widget _buildRelatedResourcesSection(BuildContext context) {
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 2.5),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        width: MediaQuery.sizeOf(context).width,
        decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border.all(
              color: context.theme.dividerColor,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 1),
                color: context.colorScheme.onSurface.withOpacity(0.3),
                blurRadius: 5,
              ),
            ]),
        child: BlocBuilder<RecordsBloc, RecordsState>(
          builder: (context, state) {
            if (state.recordDetailStatus == RecordDetailStatus.loading()) {
              return Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(height: Insets.small),
                      Text(
                        'Loading related resources...',
                        style: AppTextStyle.labelLarge.copyWith(
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state.relatedResources.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Assets.icons.information.svg(
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(
                        context.colorScheme.onSurface.withOpacity(0.5),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: Insets.small),
                    Text(
                      'No related resources found for this encounter',
                      style: AppTextStyle.labelLarge.copyWith(
                        color: context.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: state.relatedResources
                    .map(
                      (resource) => InkWell(
                        onTap: () {
                          _toggleRelated();
                          context.router
                              .push(RecordDetailsRoute(resource: resource));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            "${resource.fhirType.display}: ${resource.title}",
                            style: AppTextStyle.bodySmall.copyWith(
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  void showRecordActionDialog(Widget child) => showDialog(
        context: context,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ),
      );
}
