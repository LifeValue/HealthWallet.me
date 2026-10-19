import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/features/home/domain/entities/overview_card.dart';
import 'package:health_wallet/features/home/presentation/widgets/reorderable_grid.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/home/presentation/widgets/shaking_card.dart';

class MedicalRecordsSection extends StatelessWidget {
  final List<OverviewCard> overviewCards;
  final bool editMode;
  final VoidCallback? onLongPressCard;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(OverviewCard card)? onTapCard;
  final GlobalKey? firstCardKey;
  final FocusNode? firstCardFocusNode;

  const MedicalRecordsSection({
    super.key,
    required this.overviewCards,
    this.editMode = false,
    this.onLongPressCard,
    this.onReorder,
    this.onTapCard,
    this.firstCardKey,
    this.firstCardFocusNode,
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return ReorderableGrid<OverviewCard>(
      items: overviewCards,
      enabled: editMode,
      onReorder: onReorder ?? (a, b) {},
      crossAxisCount: _getCrossAxisCount(screenWidth),
      crossAxisSpacing: _getCrossAxisSpacing(screenWidth),
      mainAxisSpacing: _getCrossAxisSpacing(screenWidth),
      childAspectRatio: _getChildAspectRatio(screenWidth),
      itemBuilder: (context, card, index) {
        final isFirstCard = index == 0 && !editMode;
        final cardContent = _buildOverviewCard(
          context,
          card,
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
            ? ShakingCard(
                isShaking: true,
                child: cardWidget,
              )
            : ShakingCard(
                isShaking: false,
                child: GestureDetector(
                  onTap: () => onTapCard?.call(card),
                  onLongPress: onLongPressCard,
                  child: cardWidget,
                ),
              );
      },
    );
  }

  Widget _buildOverviewCard(
      BuildContext context, OverviewCard card, double screenWidth,
      {Key? key}) {
    final bool isSmall = screenWidth < _breakpoint;
    final bool isTabletLayout = screenWidth >= 600;
    final double iconSize = isSmall ? 22 : 26;

    final TextStyle categoryStyle = AppTextStyle.bodySmall.copyWith(
      fontSize: isSmall ? 10 : 14,
      color: context.colorScheme.onSurface.withOpacity(0.6),
    );

    final TextStyle countStyle = AppTextStyle.bodyMedium.copyWith(
      fontSize: isSmall ? 14 : 16,
      color: context.colorScheme.onSurface,
    );

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.theme.dividerColor, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Insets.normal,
          vertical: isTabletLayout ? Insets.small : Insets.normal,
        ),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: card.category.icon.svg(
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
                        card.category.display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: categoryStyle,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.category.display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: categoryStyle,
                          ),
                          const SizedBox(height: Insets.small),
                          Text(
                            card.count,
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
                  card.count,
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
