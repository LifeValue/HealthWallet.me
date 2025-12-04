import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class CountryFlagsWidget extends StatelessWidget {
  const CountryFlagsWidget({super.key});

  static const double _flagWidth = 32;
  static const double _overlapOffset = 26;
  static const int _flagCount = 6;

  double get _totalWidth {
    return (_flagCount * _flagWidth) -
        ((_flagCount - 1) * (_flagWidth - _overlapOffset));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.isDarkMode;
    final borderColor = isDarkMode ? Colors.black : Colors.white;

    Widget buildFlag(SvgGenImage flagAsset) {
      return SizedBox(
        width: _flagWidth,
        height: _flagWidth,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: flagAsset.svg(
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    Widget buildPlusIcon() {
      return SizedBox(
        width: _flagWidth,
        height: _flagWidth,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: Assets.onboarding.plus.svg(
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    final flags = [
      Assets.onboarding.america,
      Assets.onboarding.romania,
      Assets.onboarding.newZeeland,
      Assets.onboarding.netherlands,
      Assets.onboarding.scotland,
    ];

    return SizedBox(
      width: _totalWidth,
      height: _flagWidth,
      child: Stack(
        children: [
          ...flags.asMap().entries.map((entry) {
            final index = entry.key;
            final flagAsset = entry.value;
            return Positioned(
              left: index * _overlapOffset,
              child: buildFlag(flagAsset),
            );
          }),
          Positioned(
            left: flags.length * _overlapOffset,
            child: buildPlusIcon(),
          ),
        ],
      ),
    );
  }
}
