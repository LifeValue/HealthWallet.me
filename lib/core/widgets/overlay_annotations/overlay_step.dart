import 'package:flutter/material.dart';

/// Data class representing a single step in a step-by-step overlay sequence.
class OverlayStep {
  /// GlobalKey of the widget to highlight for this step.
  final GlobalKey targetKey;

  /// Message to display in the tooltip.
  final String message;

  /// Optional subtitle to display below the message.
  final String? subtitle;

  const OverlayStep({
    required this.targetKey,
    required this.message,
    this.subtitle,
  });
}
