import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/domain/entities/medical_specialty.dart';
import 'package:health_wallet/features/home/domain/entities/specialty_card.dart';
import 'package:health_wallet/features/home/presentation/widgets/reorderable_grid.dart';
import 'package:health_wallet/features/home/presentation/widgets/shaking_card.dart';

class SpecialtiesSection extends StatelessWidget {
  final List<SpecialtyCard> specialtyCards;
  final bool editMode;
  final VoidCallback? onLongPressCard;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(MedicalSpecialty specialty)? onTapCard;
  final GlobalKey? firstCardKey;

  const SpecialtiesSection({
    super.key,
    required this.specialtyCards,
    this.editMode = false,
    this.onLongPressCard,
    this.onReorder,
    this.onTapCard,
    this.firstCardKey,
  });

  static const double _breakpoint = 380;

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth >= 600) return 4;
    return 2;
  }

  double _getCrossAxisSpacing(double screenWidth) {
    return screenWidth < _breakpoint ? 8 : 12;
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth >= 900) return 4.2;
    if (screenWidth >= 600) return 3.2;
    return screenWidth < _breakpoint ? 2.07 : 2.1;
  }

  static const double _cardBorderWidth = 1;

  double _iconSize(double screenWidth) => screenWidth < _breakpoint ? 22 : 26;

  double _verticalPadding(double screenWidth) =>
      screenWidth >= 600 ? Insets.small : Insets.normal;

  TextStyle _nameStyle(BuildContext context, double screenWidth) =>
      AppTextStyle.bodySmall.copyWith(
        fontSize: screenWidth < _breakpoint ? 10 : 14,
        color: context.colorScheme.onSurface.withValues(alpha: 0.6),
      );

  TextStyle _countStyle(BuildContext context, double screenWidth) =>
      AppTextStyle.bodyMedium.copyWith(
        fontSize: screenWidth < _breakpoint ? 14 : 16,
        color: context.colorScheme.onSurface,
      );

  /// What a card's content needs inside the padding and the border: on a
  /// tablet the name and the count share a row, on a phone they stack.
  double _minCardHeight(BuildContext context, double screenWidth) {
    final name = measureLineHeight(context, _nameStyle(context, screenWidth));
    final count = measureLineHeight(context, _countStyle(context, screenWidth));
    final text = screenWidth >= 600
        ? math.max(name, count)
        : name + Insets.small + count;
    return math.max(_iconSize(screenWidth), text) +
        2 * (_verticalPadding(screenWidth) + _cardBorderWidth);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return ReorderableGrid<SpecialtyCard>(
      items: specialtyCards,
      enabled: editMode,
      onReorder: onReorder ?? (a, b) {},
      crossAxisCount: _getCrossAxisCount(screenWidth),
      crossAxisSpacing: _getCrossAxisSpacing(screenWidth),
      mainAxisSpacing: _getCrossAxisSpacing(screenWidth),
      childAspectRatio: _getChildAspectRatio(screenWidth),
      minItemHeight: _minCardHeight(context, screenWidth),
      itemBuilder: (context, card, index) {
        final isFirstCard = index == 0 && !editMode;
        final cardContent = _buildSpecialtyCard(
          context,
          card,
          screenWidth,
          key: isFirstCard ? firstCardKey : null,
        );

        return editMode
            ? ShakingCard(
                isShaking: true,
                child: cardContent,
              )
            : ShakingCard(
                isShaking: false,
                child: GestureDetector(
                  onTap: () => onTapCard?.call(card.specialty),
                  onLongPress: onLongPressCard,
                  child: cardContent,
                ),
              );
      },
    );
  }

  Widget _buildSpecialtyCard(
    BuildContext context,
    SpecialtyCard card,
    double screenWidth, {
    Key? key,
  }) {
    final bool isTabletLayout = screenWidth >= 600;
    final double iconSize = _iconSize(screenWidth);

    final TextStyle nameStyle = _nameStyle(context, screenWidth);
    final TextStyle countStyle = _countStyle(context, screenWidth);

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.theme.dividerColor,
          width: _cardBorderWidth,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Insets.normal,
          vertical: _verticalPadding(screenWidth),
        ),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: card.specialty.icon.svg(
                  colorFilter: ColorFilter.mode(
                    context.colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: Insets.small),
              Expanded(
                child: isTabletLayout
                    ? Text(
                        card.specialty.localizedName(context.l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.specialty.localizedName(context.l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: nameStyle,
                          ),
                          const SizedBox(height: Insets.small),
                          Text(
                            '${card.count}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: countStyle,
                          ),
                        ],
                      ),
              ),
              if (isTabletLayout) ...[
                const SizedBox(width: Insets.small),
                Text(
                  '${card.count}',
                  maxLines: 1,
                  style: countStyle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
