import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/presentation/models/record_info_line.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class RecentRecordsSection extends StatelessWidget {
  final List<IFhirResource> recentRecords;
  final VoidCallback? onViewAll;
  final void Function(dynamic record)? onTapRecord;

  const RecentRecordsSection({
    super.key,
    required this.recentRecords,
    this.onViewAll,
    this.onTapRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...recentRecords
            .map((record) => _buildRecentRecordCard(context, record)),
      ],
    );
  }

  Widget _buildRecentRecordCard(BuildContext context, IFhirResource record) {
    final tag = record.fhirType.display;
    RecordInfoLine? infoLine = record.additionalInfo.firstOrNull;

    // Get icon based on resource type
    Widget icon;
    switch (record.fhirType) {
      case FhirType.Medication:
      case FhirType.MedicationRequest:
      case FhirType.MedicationStatement:
        icon = Assets.icons.medication.svg(
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case FhirType.Immunization:
        icon = Assets.icons.shield.svg(
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case FhirType.CareTeam:
        icon = Assets.icons.eventsTeam.svg(
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      default:
        icon = Assets.icons.documentFile.svg(
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
    }

    return GestureDetector(
      onTap: () => onTapRecord?.call(record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.theme.dividerColor,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.normal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                context.colorScheme.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: icon,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tag,
                                style: AppTextStyle.labelSmall.copyWith(
                                  color: context.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (record.statusDisplay.isNotEmpty)
                    Text(
                      record.statusDisplay,
                      style: AppTextStyle.labelMedium.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                record.displayTitle,
                style: AppTextStyle.bodyMedium.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (infoLine != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        infoLine.icon.svg(
                          width: 16,
                          height: 16,
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
                              color: context.colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Assets.icons.calendar.svg(
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(
                          context.colorScheme.onSurface.withValues(alpha: 0.6),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormatUtils.humanReadable(record.date),
                        style: AppTextStyle.labelLarge.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _extractClinician(List<String> additionalInfo) {
  // Prefer specific performer/participant info if present
  final performer = additionalInfo.firstWhere(
    (line) => line.startsWith('Performer: '),
    orElse: () => '',
  );
  if (performer.isNotEmpty) {
    return performer.replaceFirst('Performer: ', '').trim();
  }

  final participant = additionalInfo.firstWhere(
    (line) => line.startsWith('Participant: '),
    orElse: () => '',
  );
  if (participant.isNotEmpty) {
    return participant.replaceFirst('Participant: ', '').trim();
  }

  final performers = additionalInfo.firstWhere(
    (line) => line.startsWith('Performers: '),
    orElse: () => '',
  );
  if (performers.isNotEmpty) {
    return performers.replaceFirst('Performers: ', '').trim();
  }

  // Fall back to service provider if that is meaningful
  final serviceProvider = additionalInfo.firstWhere(
    (line) => line.startsWith('Service Provider: '),
    orElse: () => '',
  );
  if (serviceProvider.isNotEmpty) {
    return serviceProvider.replaceFirst('Service Provider: ', '').trim();
  }

  return null;
}
