import 'package:flutter/material.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class OnboardingScreenData {
  final String title;
  final String subtitle;
  final String description;
  final String? content;
  final String? bottom;
  final SvgGenImage image;
  final bool showBiometricToggle;
  final Widget? customWidget;

  const OnboardingScreenData({
    required this.title,
    required this.subtitle,
    required this.description,
    this.content,
    this.bottom,
    required this.image,
    this.showBiometricToggle = false,
    this.customWidget,
  });
}
