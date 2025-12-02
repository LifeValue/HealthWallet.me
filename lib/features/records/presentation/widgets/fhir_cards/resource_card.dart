import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/scan/presentation/pages/preview/image_preview_page.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/bloc/records_bloc.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
// Removed unused AppColors import; using theme-based colors from context
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/presentation/widgets/media_fullscreen_viewer.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_attachments/record_attachments_widget.dart';
import 'package:health_wallet/features/records/presentation/widgets/record_notes/record_notes_widget.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:path_provider/path_provider.dart';

class ResourceCard extends StatefulWidget {
  final IFhirResource resource;

  const ResourceCard({super.key, required this.resource});

  @override
  State<ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<ResourceCard> {
  bool _isExpanded = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

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
          // Main encounter info (always visible)
          _buildMainResourceInfo(),

          const SizedBox(height: Insets.small),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildMainResourceInfo() {
    return InkWell(
      onTap: () {
        // Handle Media resources differently - open fullscreen viewer
        if (widget.resource.fhirType == FhirType.Media) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaFullscreenViewer(
                media: widget.resource as Media,
              ),
            ),
          );
        } else {
          // Default navigation for other resource types
          context.router.push(RecordDetailsRoute(resource: widget.resource));
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encounter type and status
          Text(
            widget.resource.displayTitle,
            style: AppTextStyle.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          ...widget.resource.additionalInfo.take(2).map((infoLine) => Row(
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
              ))
        ],
      ),
    );
  }

  void _toggleRelated() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _showRelated();
      context.read<RecordsBloc>().add(RecordDetailLoaded(widget.resource));
    } else {
      _hideRelated();
    }
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
      builder: (context) => Positioned(
        width: size.width + 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(-16, size.height + 8),
          child: Material(
            child: _buildRelatedResourcesSection(context),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildButtons() {
    return BlocBuilder<RecordsBloc, RecordsState>(
      builder: (context, state) {
        final isLoadingRelated =
            state.recordDetailStatus == RecordDetailStatus.loading();

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Right side: Text and loading indicator (with InkWell only here)
            if (widget.resource.fhirType == FhirType.Encounter ||
                widget.resource.resourceReferences.isNotEmpty)
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
                // const SizedBox(width: Insets.normal),
                // InkWell(
                //   onTap: () {
                //     _closeRelatedIfOpen();
                //     // TODO: Implement share functionality
                //   },
                //   borderRadius: BorderRadius.circular(4),
                //   child: Padding(
                //     padding: const EdgeInsets.all(6),
                //     child: Assets.icons.share.svg(
                //       width: 24,
                //       colorFilter: ColorFilter.mode(
                //         context.colorScheme.onSurface,
                //         BlendMode.srcIn,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ],
        );
      },
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
                    Icon(
                      Icons.info_outline,
                      size: 32,
                      color: context.colorScheme.onSurface.withOpacity(0.5),
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
