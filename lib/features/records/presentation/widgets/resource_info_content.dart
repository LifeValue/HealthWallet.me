import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/navigation/app_router.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/widgets/media_fullscreen_viewer.dart';

class ResourceInfoContent extends StatelessWidget {
  final IFhirResource resource;
  final VoidCallback? onTap;
  final int maxInfoLines;

  const ResourceInfoContent({
    super.key,
    required this.resource,
    this.onTap,
    this.maxInfoLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => _defaultNavigation(context),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.displayTitle,
            style: AppTextStyle.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...resource.additionalInfo
              .where((infoLine) => !infoLine.isSection)
              .take(maxInfoLines)
              .map((infoLine) => Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      infoLine.icon.svg(
                        width: 16,
                        colorFilter: ColorFilter.mode(
                          context.colorScheme.onSurface.withValues(alpha: 0.6),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          infoLine.info,
                          style: AppTextStyle.labelLarge.copyWith(
                            color:
                                context.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    ],
                  )),
        ],
      ),
    );
  }

  void _defaultNavigation(BuildContext context) {
    if (resource.fhirType == FhirType.Media) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MediaFullscreenViewer(
            media: resource as Media,
          ),
        ),
      );
    } else {
      context.router.push(RecordDetailsRoute(resource: resource));
    }
  }
}
