import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/home/presentation/widgets/reorderable_grid.dart';
import 'package:health_wallet/gen/assets.gen.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';

class VitalsSection extends StatelessWidget {
  final List<PatientVital> vitals;
  final List<PatientVital> allAvailableVitals;
  final bool editMode;
  final bool vitalsExpanded;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback? onLongPressCard;
  final VoidCallback? onExpandToggle;
  final GlobalKey? firstCardKey;
  final FocusNode? firstCardFocusNode;
  final Map<String, bool>? selectedVitals;

  const VitalsSection({
    super.key,
    required this.vitals,
    required this.allAvailableVitals,
    this.editMode = false,
    this.vitalsExpanded = false,
    this.onReorder,
    this.onLongPressCard,
    this.onExpandToggle,
    this.firstCardKey,
    this.firstCardFocusNode,
    this.selectedVitals,
  });

  static const double _breakpoint = 380;

  int _getCrossAxisCount(double screenWidth) {
    return 2;
  }

  double _getCrossAxisSpacing(double screenWidth) {
    return screenWidth < _breakpoint ? 8 : 12;
  }

  double _getChildAspectRatio(double screenWidth) {
    return screenWidth < _breakpoint ? 1.88 : 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final vitalsToShow = vitalsExpanded ? allAvailableVitals : vitals;
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReorderableGrid<PatientVital>(
          items: vitalsToShow,
          enabled: editMode,
          onReorder: (oldIndex, newIndex) {
            if (vitalsExpanded) {
              onReorder?.call(oldIndex, newIndex);
            } else {
              final vitalToMove = vitals[oldIndex];
              final oldMasterIndex = allAvailableVitals
                  .indexWhere((v) => v.title == vitalToMove.title);
              final newMasterIndex = allAvailableVitals
                  .indexWhere((v) => v.title == vitals[newIndex].title);

              if (oldMasterIndex != -1 && newMasterIndex != -1) {
                onReorder?.call(oldMasterIndex, newMasterIndex);
              }
            }
          },
          crossAxisCount: _getCrossAxisCount(screenWidth),
          crossAxisSpacing: _getCrossAxisSpacing(screenWidth),
          mainAxisSpacing: _getCrossAxisSpacing(screenWidth),
          childAspectRatio: _getChildAspectRatio(screenWidth),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemBuilder: (context, vital, index) {
            final isFirstCard = index == 0 && !editMode;
            final cardContent = _buildVitalSignCard(
              context,
              vital,
              screenWidth,
              key: isFirstCard ? firstCardKey : null,
            );

            Widget cardWidget;
            if (isFirstCard && firstCardFocusNode != null) {
              cardWidget = Focus(
                focusNode: firstCardFocusNode!,
                child: cardContent,
              );
            } else {
              cardWidget = cardContent;
            }

            return editMode
                ? cardWidget
                : GestureDetector(
                    onLongPress: onLongPressCard,
                    child: cardWidget,
                  );
          },
        ),
        if (allAvailableVitals.isNotEmpty &&
            (selectedVitals == null ||
                selectedVitals!.entries.where((e) => e.value).length <
                    allAvailableVitals.length))
          Padding(
            padding: const EdgeInsets.only(top: Insets.small),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: onExpandToggle,
                  icon: Icon(
                    vitalsExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  label: Text(
                    vitalsExpanded ? 'Show Less' : 'Show All',
                    style: AppTextStyle.bodySmall.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.small,
                      vertical: Insets.extraSmall,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVitalSignCard(
      BuildContext context, PatientVital vital, double screenWidth,
      {Key? key}) {
    final String title = vital.title;
    final String value = vital.value;
    final String unit = vital.unit;
    final String? status = vital.status;

    final bool isSmall = screenWidth < _breakpoint;

    final double iconSize = isSmall ? 14 : 16;

    final double cardPadding = isSmall ? Insets.normal : Insets.normal;

    final double iconTitleSpacing = isSmall ? 6 : Insets.smaller;

    Widget icon;
    switch (title) {
      case 'Heart Rate':
        icon = Assets.icons.heartFavorite.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'Blood Pressure':
        icon = Assets.icons.drop.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'Temperature':
        icon = Assets.icons.temperature.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'Blood Oxygen':
        icon = Assets.icons.activity.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'Blood Glucose':
        icon = Assets.icons.bloodGlucose.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'Respiratory Rate':
        icon = Assets.icons.alarm.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'Weight':
        icon = Assets.icons.weight.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'Height':
        icon = Assets.icons.rulerHeight.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      case 'BMI':
        icon = Assets.icons.bmi.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            context.colorScheme.onSurface,
            BlendMode.srcIn,
          ),
        );
        break;
      default:
        icon = const SizedBox.shrink();
    }

    Color cardColor = context.colorScheme.surface;
    Widget? statusIcon;
    Color? statusIconColor;

    if (status != null && status.isNotEmpty) {
      switch (status) {
        case 'Optimal':
        case 'Normal':
          cardColor = context.isDarkMode
              ? AppColors.successDark.withOpacity(0.08)
              : AppColors.success.withOpacity(0.08);
          statusIconColor = AppColors.success;
          statusIcon = Assets.icons.checkmarkCircleOutline.svg(
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(statusIconColor, BlendMode.srcIn),
          );
          break;
        case 'Elevated':
        case 'Abnormal':
          cardColor = context.isDarkMode
              ? AppColors.warningDark.withOpacity(0.08)
              : AppColors.warning.withOpacity(0.08);
          statusIconColor = AppColors.warning;
          statusIcon = Assets.icons.warning.svg(
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(statusIconColor, BlendMode.srcIn),
          );
          break;
        case 'High':
        case 'Low':
          cardColor = context.isDarkMode
              ? AppColors.errorDark.withOpacity(0.08)
              : AppColors.error.withOpacity(0.08);
          statusIconColor = AppColors.error;
          statusIcon = Assets.icons.warning.svg(
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(statusIconColor, BlendMode.srcIn),
          );
          break;
        case 'Critically Abnormal':
        case 'Critically High':
        case 'Critically Low':
          cardColor = context.isDarkMode
              ? AppColors.errorDark.withOpacity(0.12)
              : AppColors.error.withOpacity(0.12);
          statusIconColor = AppColors.error;
          statusIcon = Assets.icons.warning.svg(
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(statusIconColor, BlendMode.srcIn),
          );
          break;
        case 'Uncertain':
        case 'Intermediate':
          cardColor = context.isDarkMode
              ? AppColors.warningDark.withOpacity(0.08)
              : AppColors.warning.withOpacity(0.08);
          statusIconColor = AppColors.warning;
          statusIcon = Assets.icons.warning.svg(
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(statusIconColor, BlendMode.srcIn),
          );
          break;
        default:
          cardColor = context.colorScheme.surface;
          statusIcon = null;
      }
    }

    final TextStyle titleStyle = isSmall
        ? AppTextStyle.bodySmall.copyWith(
            fontSize: 12,
            color: context.colorScheme.onSurface,
          )
        : AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurface,
          );

    final TextStyle valueStyle = isSmall
        ? AppTextStyle.titleLarge.copyWith(
            fontSize: 20,
            color: context.colorScheme.onSurface,
          )
        : AppTextStyle.titleSmall.copyWith(
            color: context.colorScheme.onSurface,
          );

    final TextStyle unitStyle = isSmall
        ? AppTextStyle.bodySmall.copyWith(
            fontSize: 11,
            color: context.colorScheme.onSurface.withOpacity(0.6),
          )
        : AppTextStyle.bodySmall.copyWith(
            color: context.colorScheme.onSurface.withOpacity(0.6),
          );

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.theme.dividerColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(height: iconSize, width: iconSize, child: icon),
                SizedBox(width: iconTitleSpacing),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                ),
                if (statusIcon != null) ...[
                  const SizedBox(width: 4),
                  statusIcon,
                ],
              ],
            ),
            const SizedBox(height: Insets.smallNormal),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: unitStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
