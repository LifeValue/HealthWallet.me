import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/domain/entities/patient_vitals.dart';
import 'package:health_wallet/features/home/presentation/widgets/reorderable_grid.dart';
import 'package:health_wallet/gen/assets.gen.dart';

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
    if (screenWidth >= 600) return 4;
    return 2;
  }

  double _getCrossAxisSpacing(double screenWidth) {
    return screenWidth < _breakpoint ? 8 : 12;
  }

  double _getChildAspectRatio(double screenWidth, bool isPortrait) {
    if (screenWidth >= 900) return isPortrait ? 3.0 : 3.6;
    if (screenWidth >= 600) return isPortrait ? 2.3 : 3.0;
    return screenWidth < _breakpoint ? 1.88 : 1.85;
  }

  static const double _cardBorderWidth = 1;

  double _iconSize(double screenWidth) => screenWidth < _breakpoint ? 14 : 16;

  double _cardPadding(double screenWidth) =>
      screenWidth >= 600 ? Insets.small : Insets.normal;

  TextStyle _titleStyle(BuildContext context, double screenWidth) =>
      AppTextStyle.bodySmall.copyWith(
        fontSize: screenWidth < _breakpoint ? 12 : 14,
        color: context.colorScheme.onSurface,
      );

  TextStyle _valueStyle(BuildContext context, double screenWidth) =>
      AppTextStyle.titleLarge.copyWith(
        fontSize: screenWidth < _breakpoint ? 20 : 24,
        color: context.colorScheme.onSurface,
      );

  TextStyle _unitStyle(BuildContext context, double screenWidth) =>
      AppTextStyle.bodySmall.copyWith(
        fontSize: screenWidth < _breakpoint ? 11 : 12,
        color: context.colorScheme.onSurface.withValues(alpha: 0.6),
      );

  /// What a card's content needs: the title row, the gap and the value row,
  /// inside the padding and the border.
  double _minCardHeight(BuildContext context, double screenWidth) {
    final titleRow = math.max(
      _iconSize(screenWidth),
      measureLineHeight(context, _titleStyle(context, screenWidth)),
    );
    final valueRow = math.max(
      measureLineHeight(context, _valueStyle(context, screenWidth)),
      measureLineHeight(context, _unitStyle(context, screenWidth)),
    );
    return titleRow +
        Insets.smallNormal +
        valueRow +
        2 * (_cardPadding(screenWidth) + _cardBorderWidth);
  }

  @override
  Widget build(BuildContext context) {
    final vitalsToShow = vitalsExpanded ? allAvailableVitals : vitals;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

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
              final oldMasterIndex = allAvailableVitals.indexWhere(
                (v) => v.title == vitalToMove.title,
              );
              final newMasterIndex = allAvailableVitals.indexWhere(
                (v) => v.title == vitals[newIndex].title,
              );

              if (oldMasterIndex != -1 && newMasterIndex != -1) {
                onReorder?.call(oldMasterIndex, newMasterIndex);
              }
            }
          },
          crossAxisCount: _getCrossAxisCount(screenWidth),
          crossAxisSpacing: _getCrossAxisSpacing(screenWidth),
          mainAxisSpacing: _getCrossAxisSpacing(screenWidth),
          childAspectRatio: _getChildAspectRatio(screenWidth, isPortrait),
          minItemHeight: _minCardHeight(context, screenWidth),
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
                    vitalsExpanded
                        ? context.l10n.showLess
                        : context.l10n.showAll,
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
    BuildContext context,
    PatientVital vital,
    double screenWidth, {
    Key? key,
  }) {
    final String title = vital.title;
    final String value = vital.value;
    final String unit = vital.unit;
    final String? status = vital.status;

    final bool isSmall = screenWidth < _breakpoint;

    final double iconSize = _iconSize(screenWidth);

    final double cardPadding = _cardPadding(screenWidth);

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
              ? AppColors.successDark.withValues(alpha: 0.08)
              : AppColors.success.withValues(alpha: 0.08);
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
              ? AppColors.warningDark.withValues(alpha: 0.08)
              : AppColors.warning.withValues(alpha: 0.08);
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
              ? AppColors.errorDark.withValues(alpha: 0.08)
              : AppColors.error.withValues(alpha: 0.08);
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
              ? AppColors.errorDark.withValues(alpha: 0.12)
              : AppColors.error.withValues(alpha: 0.12);
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
              ? AppColors.warningDark.withValues(alpha: 0.08)
              : AppColors.warning.withValues(alpha: 0.08);
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

    final TextStyle titleStyle = _titleStyle(context, screenWidth);
    final TextStyle valueStyle = _valueStyle(context, screenWidth);
    final TextStyle unitStyle = _unitStyle(context, screenWidth);

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.theme.dividerColor,
          width: _cardBorderWidth,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                        localizedVitalTitle(title, context.l10n),
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
              // Scaled down like the title, so a long value and its unit
              // ("135/85 mmHg") fit a narrow card at a large text size.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, maxLines: 1, style: valueStyle),
                    if (unit.isNotEmpty && !value.contains(unit)) ...[
                      const SizedBox(width: 4),
                      Text(
                        localizedUnit(unit, context.l10n),
                        maxLines: 1,
                        style: unitStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
